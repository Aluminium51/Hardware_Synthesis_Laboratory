# 05 Roadmap

Current active milestone:
- Milestone 8 - report and demo support

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
Status:
- Complete as of 2026-04-22.
- `video_filter_basic` implements raw, grayscale, negative, and threshold display modes.
- `tb_video_filter_basic.sv` passed for all modes, mode switching, and default raw behavior.
- Icarus Verilog top-level elaboration passed with switch-controlled filter integration.
- Hardware validation passed on 2026-05-07 as part of the completed live baseline; `sw[1:0]` selects raw, grayscale, negative, and threshold modes in real time.

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
- Updated on 2026-05-05 to use the fuller known-good OV7670 register table and keep internal color bars enabled for hardware debug.
- Updated on 2026-05-08 so the color-bar profile uses the COM17 internal color-bar enable bit as the final profile write.
- Hardware validation passed on 2026-05-07 as part of the completed baseline; camera initialization reaches the expected done state without the error indicator.

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
Status:
- Complete as of 2026-04-22.
- Simulation passed for OV7670 RGB565 byte assembly, RGB444 conversion, frame/line handling, incomplete byte suppression, and address-cap behavior.
- Live camera-to-framebuffer integration is implemented in the top level and hardware validation passed on 2026-05-07.

Goal:
- provide a verified camera-domain capture producer for framebuffer writes

Scope:
- camera byte sampling in `cam_pclk` domain
- RGB565 assembly
- RGB444 conversion
- linear framebuffer write address generation
- frame boundary handling using `VSYNC` / `HREF`

Success criteria:
- `tb_ov7670_capture.sv` exists
- simulation shows correct two-byte pixel assembly and write behavior
- stable `wr_en`, `wr_addr`, `wr_data`, `frame_done`, and `frame_active` interface is ready for integration

## Milestone 7 — raw top-level camera integration
Status:
- Complete / hardware passed as of 2026-05-07.
- Integrated as of 2026-04-22.
- Icarus Verilog top-level elaboration passed for the raw camera-to-framebuffer-to-VGA design.
- Module simulations still pass for VGA timing, VGA reader, SCCB master, OV7670 init, and OV7670 capture.
- Updated on 2026-05-05 for debug-pattern bring-up: slower SCCB timing, raw display-only debug path, and `cam_pclk` dedicated-route override.
- Updated on 2026-05-08 to keep `sw[4:3]` reset-sampled, document the reset/reinit workflow, and temporarily test an 8-pixel left crop for the observed left-edge stripe.
- Updated on 2026-05-08 to restore full-width capture after the 8-pixel left crop caused an unwritten right-side black band on 320-pixel camera lines.
- Updated on 2026-05-08 to add `sw[2]` camera line-length LED diagnostics before attempting another stripe fix.
- Updated on 2026-05-08 to shift the OV7670 horizontal window right by 19 source pixels while keeping full-width FPGA capture.
- Updated on 2026-05-08 to shift the OV7670 vertical window up by two visible high-bit window steps while keeping full-height FPGA capture.
- Updated on 2026-05-08 to isolate an averaged-QVGA OV7670 DCW/scaler experiment behind reset-sampled `sw[6]=1, sw[4:3]=00` while preserving stable live, low-speed, and color-bar profiles.
- Updated on 2026-05-09 to add a separate reset-sampled `sw[7]=1, sw[6]=0, sw[4:3]=00` full-VGA camera profile with FPGA-side 2x2 averaging into the existing 320x240 framebuffer.
- Updated on 2026-05-09 to apply the tuned horizontal and vertical camera window shifts to the `sw[7]` full-VGA averaging profile after hardware showed the raw edge artifacts returned in that mode.
- Updated on 2026-05-09 to clamp the last 10 `sw[7]` averaged destination columns to the nearest valid averaged pixel after hardware showed a right-edge averaging artifact from the shifted full-VGA window.
- Updated on 2026-05-09 to replace the top-level `sw[7]` clamp with reset-sampled horizontal window A/B variants on `sw[4:3]`; hardware testing showed the 8-source-pixel shift removed both edge artifacts, so `00` now defaults to that window.
- Updated on 2026-05-09 to repurpose the `sw[7]` full-VGA averaging subprofiles into saturation/noise A/B profiles while keeping the hardware-selected 8-source-pixel horizontal window fixed.
- Vivado synthesis, bitstream generation, and hardware validation passed for the completed baseline.
- Live OV7670 video displays through the framebuffer, and raw / grayscale / negative / threshold modes switch in real time on the VGA readout path.

Goal:
- raw live camera -> BRAM -> VGA pipeline

Scope:
- full top-level wiring
- OV7670 SCCB/init hookup
- camera capture as the only active framebuffer writer
- debug LEDs
- camera/VGA pin constraints

Success criteria:
- raw live video works on hardware
- monitor locks to the VGA signal
- camera init done/error LEDs are meaningful
- frame activity LED responds to captured frames

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
- camera XCLK / frame-rate probe on the existing full-VGA averaging path
- full-resolution line-buffer streaming display
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
