# TASK-008 Reset-Selected 4x Bilinear VGA Mode

## Status
Implemented and simulated.

## Goal
Add an optional reset-selected 1280x960 VGA output mode that scales the existing 320x240 RGB565 framebuffer by 4x without allocating a larger framebuffer.

## Scope
In scope:
- 108 MHz VGA clock generator for 1280x960 @ 60 Hz
- 1280x960 timing generator
- line-buffered 4x nearest-neighbor/bilinear reader
- reset-time `sw[9]` mode selection
- live `sw[8]` bilinear bypass in both 2x and 4x modes
- module-level timing, reader, and top-level mode-select tests

Out of scope:
- larger framebuffer allocation
- 4 framebuffer reads per output pixel
- camera capture format changes
- extra-credit filters or edge detection

## Implemented Behavior
- `sw[9]=0` during reset selects the existing 640x480 2x path.
- `sw[9]=1` during reset selects the new 1280x960 4x path.
- Changing `sw[9]` while running does not immediately change resolution.
- `sw[8]=0` selects nearest-neighbor bypass.
- `sw[8]=1` selects bilinear interpolation.
- The framebuffer remains `320 x 240 x 16-bit RGB565`.

## Verification
Passing simulations:
- `tb_vga_timing_1280x960`
- `tb_vga_reader_bilinear_4x`
- `tb_top_vga_mode_select`

## Hardware Follow-Up
Run synthesis/implementation and check hierarchical utilization for:
- `framebuffer`
- `linebuf`
- `RAMB`
- `ila`
- `debug`

If BRAM exceeds the device budget, reduce ILA/debug BRAM usage before changing the framebuffer.

## Hardware Debug Notes
- `led[3]` now reports `clk108_locked` when 4x mode is latched, so with `sw[9]=1` and reset released it should stay on if the 108 MHz clock is active.
- If `led[3]` does not turn on in 4x mode, check that `rtl/clock/vga_clock_108.v` and `rtl/clock/vga_clock_select.v` are included in the Vivado project and regenerate the bitstream.
- If timing fails, inspect the worst negative slack path first. The 4x reader has a registered line-buffer/interpolation pipeline; remaining violations are more likely clock-domain constraints, source inclusion, or unrelated debug/ILA pressure.
