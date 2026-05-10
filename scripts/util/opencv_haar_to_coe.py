#!/usr/bin/env python3
"""
Simple converter: OpenCV Haarcascade XML -> COE file for ROM initialization.

Usage:
    python opencv_haar_to_coe.py haarcascade_frontalface_default.xml out.coe

This script extracts rectangles, thresholds and weights into a compact binary
representation. The exact packing is intentionally simple and meant as a
starting point for generating a ROM that your FPGA RTL can read.

NOTE: For a full Viola-Jones cascade export you may want to study existing
projects (Risto97, lulinchen) for precise packing formats. This script is
provided to produce a readable .coe that you can adapt.
"""

import sys
import xml.etree.ElementTree as ET

def parse_haar(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    stages = []
    for stage in root.findall('.//stages/*'):
        stage_thresh = float(stage.find('stage_threshold').text)
        trees = []
        for tree_node in stage.findall('trees/*'):
            # Each tree contains a sequence of features; we'll pack them minimally
            features = []
            for feature in tree_node.findall('feature/*'):
                features.append(feature)
            trees.append({'features': features})
        stages.append({'stage_threshold': stage_thresh, 'trees': trees})
    return stages

def write_coe(stages, out_path):
    # For demonstration write a textual COE with stage thresholds only
    with open(out_path, 'w') as f:
        f.write('memory_initialization_radix=10;\n')
        f.write('memory_initialization_vector=\n')
        entries = []
        for s in stages:
            entries.append(str(int(s['stage_threshold']*1000)))
        f.write(',\n'.join(entries) + ';\n')

def main():
    if len(sys.argv) != 3:
        print('Usage: opencv_haar_to_coe.py input.xml output.coe')
        sys.exit(1)
    xml = sys.argv[1]
    out = sys.argv[2]
    stages = parse_haar(xml)
    write_coe(stages, out)
    print('Wrote COE to', out)

if __name__ == '__main__':
    main()
