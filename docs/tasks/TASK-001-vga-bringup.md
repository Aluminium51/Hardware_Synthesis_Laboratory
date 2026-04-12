# TASK-001 VGA Bring-Up

## Goal
Produce valid 640x480 @ 60 Hz VGA timing and show a stable visible test pattern on a monitor.

## Why this task exists
The project hint explicitly points to getting a display working first.
This task isolates the display path from memory and camera complexity.

## Scope
In scope:
- VGA pixel clock generation or derivation
- VGA timing generator
- visible test pattern
- top-level VGA pin hookup
- minimum required constraints for board clock and VGA pins
- simulation for VGA timing logic

Out of scope:
- camera logic
- SCCB
- framebuffer
- filters

## Files allowed to change
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/vga/vga_timing_640x480.v`
- `rtl/vga/test_pattern.v`
- `rtl/clocking/reset_sync.v`
- `constr/basys3_ov7670_vga.xdc`
- `sim/tb/tb_vga_timing.sv`
- related script or IP wrapper files if necessary

## Required behavior
- output valid `hsync`
- output valid `vsync`
- maintain stable active-video region
- show a visible pattern in the active region
- blank or drive black outside active region

## Design notes
- use standard 640x480 timing
- do not attempt 320x240 nonstandard sync timing
- keep the timing generator independent from camera and memory logic

## Deliverables
- synthesizable VGA timing module
- simple test-pattern module
- top-level connection to VGA outputs
- simulation testbench for timing counters and sync generation
- brief bring-up notes if hardware-tested

## Done when
1. Simulation confirms timing counters and sync pulse structure.
2. Monitor locks reliably.
3. A stable visible test pattern appears.
4. No camera or framebuffer dependency remains in this stage.

## Suggested testbench checks
- horizontal counter wraps correctly
- vertical counter wraps correctly
- active region dimensions are correct
- sync signals assert in the expected windows

## Common failure modes
- wrong pixel clock
- swapped sync polarity
- off-by-one errors in counters
- pattern generator not blanking outside active area
