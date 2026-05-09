# 00 Requirements

## Project summary
Build a real-time video capture and processing system on a Basys 3 FPGA using an OV7670 camera and VGA output.

The system must:
- configure the OV7670 over SCCB
- capture pixel data from the camera parallel interface
- store image data in Basys 3 internal BRAM
- display video through VGA
- support real-time switching between raw video and three image filters

## Assignment-driven baseline requirements

### Functional baseline
- Camera interface must configure OV7670 over SCCB.
- Camera capture must correctly use `PCLK`, `VSYNC`, and `HREF`.
- Captured image data must be stored in on-chip BRAM.
- VGA output must generate correct `HSYNC` and `VSYNC`.
- Baseline source resolution is `320x200` or `320x240`.
- The project baseline for this repo is fixed to `320x240`.

### Filters
Three distinct hardware filters are required for full functional score.

Selected baseline filters for this repo:
- grayscale
- negative / inversion
- threshold / binary

Required display modes:
- raw video
- grayscale
- negative
- threshold

### VGA display rule
The monitor still receives standard `640x480 @ 60 Hz` VGA timing.
A lower-resolution image is displayed by pixel doubling.

For this repo, that means:
- horizontal doubling: one source pixel is shown for two VGA pixel clocks
- vertical doubling: one source row is shown for two VGA lines

### Deliverables implied by the assignment
- modular RTL
- valid constraints file
- module-level testbenches
- simulation evidence before synthesis
- system block diagram
- final report
- AI usage disclosure

## Fixed repository decisions
These decisions are intentionally frozen for the first working baseline.

### Resolution and timing
- source image resolution: `320x240`
- VGA timing: `640x480 @ 60 Hz`
- display scaling: integer `2x` in both axes

### Pixel format
- camera capture target: `RGB565`
- stored framebuffer format: `RGB565`
- display output format: `RGB444` to Basys 3 VGA pins

### Buffering
- first milestone uses a **single framebuffer**
- raw frame is stored in BRAM
- filters are applied **after** framebuffer readout

### Feature scope
In scope for baseline:
- VGA bring-up
- framebuffer read path
- 3 basic filters
- SCCB master
- OV7670 init sequence
- OV7670 capture path
- full integration

Out of scope until baseline is stable:
- double buffering
- Sobel edge detection
- true full-frame 640x480 storage
- neural network extra credit
- bilinear/bicubic extra credit

## Success criteria for the first complete baseline
A baseline build is considered successful only when all of the following are true:
1. VGA monitor locks and shows a stable 640x480 output.
2. Framebuffer-backed 320x240 image is displayed through 2x scaling.
3. Raw / grayscale / negative / threshold modes are selectable in real time.
4. OV7670 initializes over SCCB.
5. Camera pixels are captured into BRAM.
6. Live camera image is visible on the monitor.
7. Major modules have testbenches.

## Current baseline status
The first complete baseline is met as of 2026-05-07.

Validated baseline behavior:
- Basys 3 hardware locks a monitor to standard `640x480 @ 60 Hz` VGA timing.
- Live OV7670 video is captured into the single RGB565 framebuffer and displayed as `320x240` content with exact 2x scaling.
- `sw[1:0]` selects raw, grayscale, negative, and threshold display modes in real time.
- `btnU` / `btnD` adjust the threshold value, and `sw[5]` remains available as a VGA-only debug pattern override.
- Module-level simulations remain the verification evidence for VGA timing, VGA reader/addressing, filters, SCCB master, OV7670 init, and camera capture.

## Risks that should be assumed from the start
- camera register configuration may be the hardest bring-up step
- clock-domain bugs can make the image intermittently wrong
- BRAM read latency must be matched with VGA control-signal delay
- single buffering may cause tearing, which is acceptable for the first baseline
- camera byte ordering and color-channel order may need adjustment after first light
