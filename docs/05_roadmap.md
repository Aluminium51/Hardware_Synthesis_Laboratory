# 05 Roadmap

Current active milestone:
- TASK-003 / Milestone 3 - basic filter block

## Project philosophy
This project must be built in stages.
Do not attempt full camera-to-VGA integration before the display path has already been proven.

## Milestone 0 — repository setup
Status goal:
- docs exist
- task briefs exist
- code tree exists
- AGENTS and README exist

Deliverables:
- root project structure
- baseline docs
- baseline task files

## Milestone 1 — VGA bring-up
Status:
- Complete as of 2026-04-22.
- Simulation passed for VGA timing.
- Hardware monitor locked and displayed stable vertical color bars.

Goal:
- produce a stable VGA output on the monitor

Scope:
- 25 MHz pixel rate derived from `clk_100`
- `vga_timing_640x480`
- simple visible pattern generator
- top-level VGA wiring
- initial constraints for VGA and board clock

Success criteria:
- monitor locks to the signal
- pattern is stable
- `tb_vga_timing.sv` exists and checks timing behavior

Do not include yet:
- camera logic
- framebuffer logic
- filters

Implementation note:
- TASK-001 uses `clk_100` plus a 25 MHz `pixel_ce` for bring-up.
- MMCM / Clock Wizard remains deferred unless later hardware behavior requires a true VGA pixel clock.

## Milestone 2 — framebuffer-backed display path
Status:
- Complete as of 2026-04-22.
- Simulation passed for VGA reader address mapping, 2x scaling, blanking, and control alignment.
- Hardware monitor displayed the framebuffer-backed structured pattern with no obvious pixel skew.

Goal:
- display a known 320x240 image through 2x scaling on a 640x480 VGA output

Scope:
- framebuffer wrapper
- read address generation
- active-video and sync alignment with BRAM read latency
- display of synthetic or initialized framebuffer content

Success criteria:
- image appears correctly scaled
- read mapping behaves as expected
- `tb_vga_reader_320x240.sv` verifies address mapping

## Milestone 3 — basic filter block
Goal:
- add real-time switchable display modes without involving the camera yet

Scope:
- `video_filter_basic`
- raw mode
- grayscale mode
- negative mode
- threshold mode
- switch-controlled mode select

Success criteria:
- filter output changes correctly on hardware or test image
- `tb_video_filter_basic.sv` exists and checks all filter modes

## Milestone 4 — SCCB master
Status:
- Complete as of 2026-04-22.
- Simulation passed for SCCB write transactions, ACK success, and ACK failure with clean STOP termination.

Goal:
- implement the low-level camera configuration transport

Scope:
- SCCB start/stop behavior
- device address and register write sequencing
- ack handling
- busy / done interface

Success criteria:
- `tb_ov7670_sccb_master.sv` verifies one or more register-write transactions

## Milestone 5 — OV7670 init sequence
Status:
- Complete as of 2026-04-22.
- Simulation passed for register ROM sequencing, startup gating, post-soft-reset delay, ACK failure handling, and sticky done/error status.
- Hardware debug LED validation has not been recorded yet and remains optional for this milestone.

Goal:
- configure camera into the chosen baseline mode

Scope:
- register ROM table
- init FSM
- reset and startup delay handling
- debug `done` and `error` outputs

Success criteria:
- init state machine completes in simulation
- hardware debug LEDs indicate init success or a clear failure path
- `tb_ov7670_init.sv` exists

## Milestone 6 — camera capture path
Goal:
- capture live camera pixels into the framebuffer

Scope:
- camera byte sampling in `cam_pclk` domain
- RGB565 assembly
- RGB444 conversion
- linear framebuffer write address generation
- frame boundary handling using `VSYNC` / `HREF`

Success criteria:
- `tb_ov7670_capture.sv` exists
- simulation shows correct two-byte pixel assembly and write behavior
- live image appears, even if orientation or colors need adjustment

## Milestone 7 — full baseline integration
Goal:
- stable live camera -> BRAM -> filter -> VGA pipeline

Scope:
- full top-level wiring
- switch-based mode selection
- debug LEDs
- final baseline integration fixes

Success criteria:
- raw mode works on hardware
- grayscale works on hardware
- negative works on hardware
- threshold works on hardware
- live display is stable enough for demonstration

## Milestone 8 — report and demo support
Goal:
- make the project easy to explain and demonstrate

Scope:
- block diagram
- clock-domain diagram
- memory explanation
- testbench waveforms
- AI usage log cleanup
- hardware demo sequence

Success criteria:
- presentation materials are ready
- team can explain the architecture clearly

## Optional post-baseline milestones
Only after baseline is complete:
- Sobel edge detection
- double buffering
- full-resolution or upscaling experiments
- extra-credit exploration

## Stop rules
Do not move to the next milestone if the current milestone is not visibly or simulation-wise validated.

That means:
- VGA first
- then BRAM display
- then filters
- then camera configuration
- then camera capture
- then integration
