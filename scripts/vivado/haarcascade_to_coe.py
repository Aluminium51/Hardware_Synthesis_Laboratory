#!/usr/bin/env python3
"""
Convert OpenCV Haar cascade XML to Vivado .coe BRAM image.

ROM layout (32-bit words, radix=16):
  [0]  0x48415231               # 'HAR1' magic
  [1]  scale_shift              # fixed-point fractional bits (Q format)
  [2]  stage_count

  Repeated for each stage:
    stage_weak_count
    stage_threshold_q

    Repeated for each weak classifier:
      node_threshold_q
      left_val_q
      right_val_q
      rect_count

      Repeated for each rect:
        packed_rect             # x[31:24], y[23:16], w[15:8], h[7:0]
        rect_weight_q

The OpenCV frontal-face XML stores weak nodes with a feature index in
internalNodes. Rectangles are looked up from cascade/features[feature_index].

Example:
  python scripts/vivado/haarcascade_to_coe.py \
      haarcascade_frontalface_default.xml \
      rtl/memory/haarcascade_frontalface_q8.coe \
      --scale-shift 8
"""

from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Tuple


MAGIC = 0x48415231  # 'HAR1'


def qfix(value: float, scale_shift: int) -> int:
    scale = 1 << scale_shift
    return int(round(value * scale))


def parse_floats(text: str, expected: int | None = None) -> List[float]:
    vals = [float(x) for x in text.strip().split()]
    if expected is not None and len(vals) < expected:
        raise ValueError(f"Expected at least {expected} values, got {len(vals)} in: {text!r}")
    return vals


def parse_ints(text: str, expected: int | None = None) -> List[int]:
    vals = [int(float(x)) for x in text.strip().split()]
    if expected is not None and len(vals) < expected:
        raise ValueError(f"Expected at least {expected} values, got {len(vals)} in: {text!r}")
    return vals


def parse_feature_rects(cascade_node: ET.Element) -> List[List[Tuple[int, int, int, int, float]]]:
    features_node = cascade_node.find("features")
    if features_node is None:
        raise ValueError("XML missing <features> section")

    features: List[List[Tuple[int, int, int, int, float]]] = []
    for feat in features_node.findall("_"):
        rects_node = feat.find("rects")
        if rects_node is None:
            features.append([])
            continue

        rect_list: List[Tuple[int, int, int, int, float]] = []
        for rect in rects_node.findall("_"):
            parts = rect.text.strip().split()
            if len(parts) != 5:
                raise ValueError(f"Unexpected rect format: {rect.text!r}")
            x, y, w, h = (int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
            wt = float(parts[4])
            if not (0 <= x <= 255 and 0 <= y <= 255 and 1 <= w <= 255 and 1 <= h <= 255):
                raise ValueError(f"Rect coordinate out of 8-bit packing range: {(x, y, w, h)}")
            rect_list.append((x, y, w, h, wt))
        features.append(rect_list)

    return features


def parse_cascade(xml_path: Path, scale_shift: int) -> List[int]:
    root = ET.parse(xml_path).getroot()
    cascade = root.find("cascade")
    if cascade is None:
        # fallback for alternate OpenCV wrappers
        cascade = root.find(".//cascade")
    if cascade is None:
        raise ValueError("Could not locate <cascade> in XML")

    stages_node = cascade.find("stages")
    if stages_node is None:
        raise ValueError("XML missing <stages>")

    features = parse_feature_rects(cascade)

    words: List[int] = [MAGIC, scale_shift & 0xFFFFFFFF]

    stages = stages_node.findall("_")
    words.append(len(stages) & 0xFFFFFFFF)

    for stage in stages:
        weak_node = stage.find("weakClassifiers")
        stage_thresh_node = stage.find("stageThreshold")
        if weak_node is None or stage_thresh_node is None:
            raise ValueError("Stage missing weakClassifiers or stageThreshold")

        weak_list = weak_node.findall("_")
        stage_threshold = float(stage_thresh_node.text)

        words.append(len(weak_list) & 0xFFFFFFFF)
        words.append(qfix(stage_threshold, scale_shift) & 0xFFFFFFFF)

        for weak in weak_list:
            internal = weak.find("internalNodes")
            leaf = weak.find("leafValues")
            if internal is None or leaf is None:
                raise ValueError("Weak classifier missing internalNodes or leafValues")

            # Format is: left_idx right_idx feature_idx threshold
            inode = parse_ints(internal.text, expected=4)
            feature_idx = inode[2]
            threshold = float(internal.text.strip().split()[3])

            lvals = parse_floats(leaf.text, expected=2)
            left_val = lvals[0]
            right_val = lvals[1]

            if feature_idx < 0 or feature_idx >= len(features):
                raise ValueError(f"Invalid feature index {feature_idx} (features={len(features)})")

            rects = features[feature_idx]

            words.append(qfix(threshold, scale_shift) & 0xFFFFFFFF)
            words.append(qfix(left_val, scale_shift) & 0xFFFFFFFF)
            words.append(qfix(right_val, scale_shift) & 0xFFFFFFFF)
            words.append(len(rects) & 0xFFFFFFFF)

            for (x, y, w, h, wt) in rects:
                packed = ((x & 0xFF) << 24) | ((y & 0xFF) << 16) | ((w & 0xFF) << 8) | (h & 0xFF)
                words.append(packed & 0xFFFFFFFF)
                words.append(qfix(wt, scale_shift) & 0xFFFFFFFF)

    return words


def write_coe(words: List[int], out_path: Path) -> None:
    with out_path.open("w", encoding="ascii") as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        for i, w in enumerate(words):
            suffix = ",\n" if i < len(words) - 1 else ";\n"
            f.write(f"{w & 0xFFFFFFFF:08X}{suffix}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Convert OpenCV Haar XML to Vivado COE")
    ap.add_argument("xml", type=Path, help="Input OpenCV Haar XML")
    ap.add_argument("coe", type=Path, help="Output .coe file")
    ap.add_argument("--scale-shift", type=int, default=8, help="Q format fractional bits (default: 8)")
    args = ap.parse_args()

    if args.scale_shift < 0 or args.scale_shift > 20:
        raise ValueError("scale-shift must be in range [0, 20]")

    words = parse_cascade(args.xml, args.scale_shift)
    write_coe(words, args.coe)
    print(f"Wrote {args.coe} with {len(words)} 32-bit words (Q{args.scale_shift}).")


if __name__ == "__main__":
    main()
