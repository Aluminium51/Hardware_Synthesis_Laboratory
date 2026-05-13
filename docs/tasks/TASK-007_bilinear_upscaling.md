# TASK-007 Bilinear Upscaling

## Status
Not started.

## Goal
Implement real-time bilinear upscaling from 320x240 to 640x480 on the VGA readout path using a time-multiplexed BRAM read in the 100 MHz domain.

## Why this task exists
The baseline system uses nearest-neighbor 2x scaling. Bilinear upscaling should reduce blockiness while preserving the existing 640x480 VGA timing and single-framebuffer architecture.

## Scope
In scope:
- new VGA reader module with bilinear interpolation
- time-multiplexed single-port BRAM reads at 100 MHz
- constant-latency sync and active-video alignment
- runtime bypass for exact baseline behavior
- module-level testbench
- top-level integration switch control

Out of scope:
- changes to framebuffer format
- camera capture changes
- line buffers or multi-framebuffer designs
- nonstandard VGA timings

## Files allowed to change
- `rtl/vga/vga_reader_bilinear.v` (new)
- `sim/tb/tb_vga_reader_bilinear.sv` (new)
- `rtl/top/top_basys3_ov7670_vga.v`
- optional docs if interface or control mapping changes

## Required behavior
- VGA timing remains 640x480 @ 60 Hz.
- Base image remains 320x240; upscaling happens on readout.
- Use `clk_100` and `pixel_ce` to fetch four pixels for each VGA output pixel.
- Pixel fetch order: P00(x,y), P10(x+1,y), P01(x,y+1), P11(x+1,y+1).
- Clamp x+1 to 319 and y+1 to 239 to avoid BRAM overflow.
- Pipeline latency is constant and all sync/active signals are delayed to match.
- Runtime bypass: `enable_bilinear=0` outputs P00 (nearest-neighbor baseline).
- Bilinear math splits RGB565 channels, accumulates with wider registers, divides by shifting, and repacks to RGB565.

## Implementation notes
- Use `src_x = vga_x[9:1]`, `src_y = vga_y[8:1]`.
- Use `vga_x[0]` and `vga_y[0]` to select blending weights.
- Fetch state machine advances only on `clk_100`, gated by the start of a new VGA pixel (aligned to `pixel_ce`).
- Align `hsync`, `vsync`, and `active_video` with the fixed read/compute latency using shift registers.

## Verification
- Add a module-level testbench that:
  - generates `clk_100` and a `pixel_ce` pulse every 4 clocks
  - uses a predictable mock BRAM mapping for `rd_data`
  - checks latency alignment of sync/active with RGB output
  - checks bypass behavior and blended output behavior

## Deliverables
- new bilinear VGA reader RTL module
- module testbench for bilinear reader
- top-level integration with switch-controlled enable

## Done when
1. Testbench passes for bypass and bilinear modes.
2. Sync and active signals are aligned to RGB output with constant latency.
3. Top-level integrates the new module and switch control without breaking filters.

## Common failure modes
- using `pixel_ce` as the state-machine clock instead of gating `clk_100`
- missing or variable latency alignment for sync/active signals
- incorrect edge clamp causing BRAM overflow
- RGB565 overflow due to insufficient accumulator width
