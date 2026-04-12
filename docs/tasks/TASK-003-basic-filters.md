# TASK-003 Basic Filters

## Goal
Implement the baseline display modes on the VGA readout path:
- raw
- grayscale
- negative
- threshold

## Why this task exists
The assignment requires three distinct real-time hardware filters with a way to switch between them.
This task implements those filters in the simplest architecture: after framebuffer readout.

## Scope
In scope:
- one filter-selection module
- mode select input mapping
- grayscale implementation
- negative implementation
- threshold implementation
- passthrough raw mode
- filter testbench

Out of scope:
- edge detection
- line buffers
- convolution kernels
- camera integration changes

## Files allowed to change
- `rtl/filters/video_filter_basic.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `sim/tb/tb_video_filter_basic.sv`
- optional docs if formulas or mode mapping change

## Required behavior
Mode mapping:
- `00` raw
- `01` grayscale
- `10` negative
- `11` threshold

### Grayscale
Produce a grayscale approximation from RGB444.
A simple weighted approximation is acceptable.

### Negative
For each 4-bit channel:
- `out = 15 - in`

### Threshold
- compute a grayscale or luminance-like value
- compare it against a threshold control
- output full white or full black

## Deliverables
- synthesizable filter module
- stable mode select behavior
- testbench covering at least one case per mode
- top-level control hookup using switches or simple static control for testing

## Done when
1. Simulation shows each mode behaving correctly.
2. Raw mode preserves input unchanged.
3. Negative mode inverts channels correctly.
4. Threshold mode produces only black or white output.
5. Filter switching works without modifying framebuffer contents.

## Common failure modes
- accidentally filtering before storage instead of after readout
- incorrect 4-bit inversion arithmetic
- threshold comparing the wrong value range
- mode select not synchronized or not wired correctly
