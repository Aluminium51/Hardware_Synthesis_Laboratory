# Haar Cascade ROM + Face Detect Pipeline Notes

## Scope
This document defines:
- the `.coe` word format used to store OpenCV Haar cascade data in BRAM
- the `face_detect.v` ROM/integral-image interfaces
- the sliding-window line-buffer architecture for a 24x24 detector window

This is a baseline single-window evaluator architecture intended for Artix-7 (Basys 3).

## 1. COE Memory Format
Generator script: `scripts/vivado/haarcascade_to_coe.py`

Output format uses 32-bit hex words (`memory_initialization_radix=16`).
Hardware uses a plain-hex `.mem` file (one word per line) derived from the `.coe`
so `$readmemh` can initialize the BRAM-backed ROM (`rtl/memory/haarcascade_rom.v`).

### 1.1 Global header
- `word[0]`: `0x48415231` (`HAR1` magic)
- `word[1]`: fixed-point fractional bits (for example `8` for Q8)
- `word[2]`: number of stages

### 1.2 Stage payload
For each stage:
- `stage_weak_count`
- `stage_threshold_q`

For each weak classifier in this stage:
- `node_threshold_q`
- `left_val_q`
- `right_val_q`
- `rect_count`

For each rectangle in this weak classifier:
- `packed_rect` (`x[31:24], y[23:16], w[15:8], h[7:0]`)
- `rect_weight_q`

All threshold/weight/leaf values are signed fixed-point.

## 2. Fixed-Point Convention
Recommended baseline:
- Q8 (`SCALE_SHIFT=8`) in both generator and RTL

Conversion in Python:
- `q = round(float_value * (1 << SCALE_SHIFT))`

In Verilog multiply path:
- `weighted_q = (rect_sum * rect_weight_q) >>> SCALE_SHIFT`

No floating-point or division operators are used in RTL.

## 3. face_detect.v Interface Contract
Module: `rtl/top/face_detect.v`

### 3.1 Control interface
- `start`: pulse high to evaluate one 24x24 window
- `win_x`, `win_y`: top-left coordinate of the candidate window

### 3.2 ROM interface
- `rom_addr`: 32-bit word address into cascade BRAM
- `rom_ren`: read enable pulse
- `rom_data`: returned data word

The FSM expects a deterministic sequential ROM walk in the exact format above.

### 3.3 Integral image interface
- `ii_addr`: address for integral-image RAM read
- `ii_ren`: read request pulse
- `ii_data`: returned integral-image value
- `ii_valid`: data valid handshake

Integral image storage uses a 1-pixel zero border (size is `(width+1) x (height+1)`),
so rectangle sums use the standard padded integral formulation.

Rectangle sum operation is:
- `Sum = A + D - B - C`

where:
- `A = II(x, y)`
- `B = II(x+w, y)`
- `C = II(x, y+h)`
- `D = II(x+w, y+h)`

`x` and `y` are window-relative rectangle coordinates offset by `win_x` and `win_y`.

### 3.4 Stage decision
For each weak classifier:
- accumulate weighted rectangle responses into `weak_sum_q`
- compare `weak_sum_q` with `node_threshold_q`
- add `left_val_q` or `right_val_q` to `stage_acc_q`

For each stage:
- if `stage_acc_q < stage_threshold_q`, reject window (`face_found=0`)
- otherwise continue to next stage
- if all stages pass, assert `face_found=1` with `done=1`

## 4. Sliding Window Line-Buffer Architecture
Module: `rtl/util/sliding_window_24.v`

### 4.1 Inputs
- `px_in[7:0]`: grayscale pixel stream
- `px_valid`: valid pixel enable
- `line_start`: pulse on first valid pixel of each line
- `frame_start`: pulse on first valid pixel of each frame

### 4.2 Structure
- Cascade of `WINDOW-1` line-delay buffers (`linebuffer_ram`) with depth `IMAGE_WIDTH`
- Per-row shift registers with `WINDOW` columns to hold local horizontal context
- Top row corresponds to oldest delayed line, bottom row to current line

### 4.3 Outputs
- `window_data`: flattened `WINDOW x WINDOW` grayscale block
- `window_x`, `window_y`: top-left coordinates of current valid window
- `window_valid`: asserted when there is enough row and column history

### 4.4 Valid timing condition
Window is valid when all are true:
- all line buffers are full
- row counter is at least `WINDOW-1`
- column counter is at least `WINDOW-1`

## 5. Integration Guidance
1. Convert camera RGB565 to grayscale in camera pixel domain.
2. Feed grayscale stream to `sliding_window_24`.
3. Build/update integral-image RAM in same processing clock domain.
4. On each `window_valid`, pulse `face_detect.start` with `window_x/window_y`.
5. Use a small scheduler if detector latency is longer than one pixel period.
6. Keep existing camera capture and VGA timing logic unchanged.

Hardware enable:
- `sw[14] = 1` enables the face-detect path in the top-level design.
- Keep `sw[14] = 0` for the baseline camera-to-VGA-only behavior.

Implementation note:
- The current RTL adds an `integral_image_ram` scaffold in the camera clock domain so the face-detect path has a concrete storage block to bind to later.
- The top-level detector enable remains off by default until the cascade ROM and final scheduler path are ready.

## 6. Resource Notes for Basys 3
- Cascade ROM should use BRAM (`.coe` init)
- Integral image storage should use BRAM
- Keep arithmetic signed integer and shift-based scaling
- If throughput is low, process every Nth window as a first optimization
