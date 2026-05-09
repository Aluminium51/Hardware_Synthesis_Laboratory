# 07 AI Usage Log

## Purpose
The course requires explicit disclosure of AI use in the final submission.
This file is a running log so the final report can cite AI usage accurately instead of guessing later.

## How to use this file
Whenever AI is used in a meaningful way, add a dated note.
Do not log trivial autocomplete-like behavior unless it materially affected implementation.

Good things to log:
- generated or revised RTL
- generated or revised testbenches
- debugging help
- architecture planning help
- documentation/report drafting help
- explanation of FPGA/video concepts that affected design decisions

## Suggested format
Use entries like this:

```text
[YYYY-MM-DD]
Tool: ChatGPT Codex / ChatGPT / other
Used for:
Files affected:
Human review performed:
Notes:
```

## Current entries

### [2026-04-12]
Tool: ChatGPT
Used for:
- project architecture planning
- repository structure planning
- AGENTS.md drafting
- README drafting
- documentation drafting for requirements, architecture, clock domains, memory plan, and roadmap
Files affected:
- `AGENTS.md`
- `README.md`
- `docs/00_requirements.md`
- `docs/01_architecture.md`
- `docs/02_clock_domains.md`
- `docs/03_memory_plan.md`
- `docs/05_roadmap.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reviewed and selected baseline design decisions
Notes:
- all generated material should still be checked against actual board behavior and Vivado results

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned TASK-001 VGA bring-up
- drafted VGA timing, reset synchronization, test pattern, top-level wiring, constraints, and timing testbench
- refined clocking approach to use `clk_100` with a 25 MHz pixel enable instead of a project-wide fabric-divided clock
- helped document TASK-001 completion after hardware confirmation
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/vga/vga_timing_640x480.v`
- `rtl/vga/test_pattern.v`
- `rtl/clocking/reset_sync.v`
- `constr/basys3_ov7670_vga.xdc`
- `sim/tb/tb_vga_timing.sv`
- `docs/tasks/TASK-001-vga-bringup.md`
- `docs/05_roadmap.md`
- `docs/02_clock_domains.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner confirmed stable vertical color bars on Basys 3 VGA hardware
- simulation output was checked before recording the task as complete
Notes:
- camera, SCCB, framebuffer, and filters remained out of scope for TASK-001
- next active milestone is TASK-002 framebuffer read path

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned TASK-002 framebuffer read-path implementation
- drafted the framebuffer wrapper, VGA read-address generator, top-level BRAM-backed display hookup, and reader testbench
- helped document TASK-002 completion after simulation and hardware confirmation
Files affected:
- `rtl/memory/framebuffer_bram.v`
- `rtl/vga/vga_reader_320x240.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `sim/tb/tb_vga_reader_320x240.sv`
- `docs/tasks/TASK-002-framebuffer-read-path.md`
- `docs/05_roadmap.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner confirmed the BRAM-backed structured pattern displayed correctly on Basys 3 VGA hardware
- simulation output was checked before recording the task as complete
Notes:
- camera capture, SCCB, filters, and XDC changes remained out of scope for TASK-002
- next active milestone is TASK-003 basic filters

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned and implemented TASK-003 basic filters
- drafted the combinational RGB444 raw, grayscale, negative, and threshold filter block
- wired switch-controlled mode and threshold selection into the VGA readout path
- enabled Basys 3 switch constraints for filter control
- drafted and ran the self-checking filter testbench
- updated project docs to record TASK-003 completion
Files affected:
- `rtl/filters/video_filter_basic.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `constr/basys3_ov7670_vga.xdc`
- `sim/tb/tb_video_filter_basic.sv`
- `docs/tasks/TASK-003-basic-filters.md`
- `docs/05_roadmap.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- filter simulation output was checked before recording the task as complete
- top-level Icarus Verilog elaboration was checked
Notes:
- hardware live-filter validation was later recorded as passed on 2026-05-07 as part of the completed baseline
- edge detection, line buffers, filtered-frame storage, and camera-path changes remained out of scope for TASK-003

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned and implemented TASK-004 SCCB master
- drafted the write-only SCCB transaction FSM and self-checking testbench
- removed the obsolete empty SCCB testbench placeholder
- verified ACK success and ACK failure behavior with Icarus Verilog
Files affected:
- `rtl/camera/ov7670_sccb_master.v`
- `sim/tb/tb_ov7670_sccb_master.sv`
- `docs/tasks/TASK-004-sccb-master.md`
- `docs/05_roadmap.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- simulation output was checked before recording the task as complete
Notes:
- camera register ROM, full camera initialization, pixel capture, framebuffer writes, and top-level wiring remained out of scope for TASK-004

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned and implemented TASK-005 OV7670 initialization
- drafted the register ROM, init FSM, and fake-SCCB self-checking testbench
- verified successful register sequencing and injected SCCB failure handling with Icarus Verilog
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `rtl/camera/ov7670_init.v`
- `sim/tb/tb_ov7670_init.sv`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- simulation output was checked before recording the task as complete
Notes:
- pixel capture, framebuffer writes, live VGA display integration, and top-level LED wiring remained out of scope for TASK-005

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned and implemented TASK-006 OV7670 RGB565 camera capture
- drafted the pclk-domain byte assembly, RGB444 conversion, framebuffer write-side control, and self-checking capture testbench
- cleaned TASK-006 and project docs so the implemented stable interface is recorded accurately
Files affected:
- `rtl/camera/ov7670_capture_rgb565.v`
- `sim/tb/tb_ov7670_capture.sv`
- `docs/tasks/TASK-006-camera-capture.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- simulation output was checked before recording the task as complete
Notes:
- full top-level live camera integration, hardware capture validation, and color/orientation tuning remain out of scope for TASK-006

### [2026-04-22]
Tool: ChatGPT Codex
Used for:
- planned and implemented TASK-007 raw top-level OV7670-to-VGA integration
- replaced the synthetic framebuffer writer with the camera capture write path
- wired OV7670 SCCB init, SCCB top-level tri-state, camera XCLK, camera reset/power controls, CDC status synchronization, debug LEDs, and camera pin constraints
- re-ran top-level elaboration and focused module simulations
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/util/sync_2ff.v`
- `constr/basys3_ov7670_vga.xdc`
- `docs/01_architecture.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/05_roadmap.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- Icarus Verilog top-level elaboration was checked
- existing module simulations were rerun and checked
Notes:
- Vivado synthesis, bitstream generation, and hardware validation were not completed in this environment
- TASK-007 should not be marked complete until raw live video is confirmed on hardware

### [2026-05-05]
Tool: ChatGPT Codex
Used for:
- analyzed corrupted OV7670-to-VGA hardware output against a known-good reference design
- replaced the minimal OV7670 init ROM with the fuller known-good register table while keeping internal color bars enabled for debug
- slowed SCCB timing, forced raw display-only debug output, added `cam_pclk` route override, and updated the init testbench for the extended ROM
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `rtl/camera/ov7670_init.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `constr/basys3_ov7670_vga.xdc`
- `sim/tb/tb_ov7670_init.sv`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/05_roadmap.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- reference RTL and current repo RTL were compared before changing the register table and top-level bring-up behavior
- simulations were rerun after the edits
Notes:
- this change intentionally targets a stable debug pattern first; live video remains a later validation step

### [2026-05-06]
Tool: ChatGPT Codex
Used for:
- implemented a switchable VGA-only test-pattern mode for adapter-path debug
- remapped top-level switch usage so `sw[5]` selects the VGA test pattern and `sw[4:2]` provide a coarse threshold control in camera mode
- restored filter output on the normal camera display path while keeping the debug-pattern override separate
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `README.md`
- `docs/tasks/TASK-003-basic-filters.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- top-level switch mapping and display mux behavior were reviewed against the existing VGA timing, test-pattern, and filter modules
- targeted simulation and elaboration checks were rerun after the change
Notes:
- the new mode is intended specifically to isolate the VGA-to-HDMI adapter path from camera-side issues

### [2026-05-06]
Tool: ChatGPT Codex
Used for:
- replaced the coarse switch-based threshold with a stored 4-bit threshold adjusted by `btnU` / `btnD`
- added top-level button synchronization/debouncing/one-shot press handling and updated the board constraints/docs
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `constr/basys3_ov7670_vga.xdc`
- `README.md`
- `docs/tasks/TASK-003-basic-filters.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- top-level button integration and threshold-clamp behavior were reviewed against the existing filter and reset flow
- targeted compile/simulation checks were rerun after the change
Notes:
- `sw[4:2]` are now unused/reserved and threshold resets to mid-scale on `btnC`

### [2026-05-07]
Tool: ChatGPT Codex
Used for:
- updated documentation to record that the baseline system is complete on hardware
- aligned README, roadmap, requirements, architecture notes, and task status files with the completed live OV7670-to-VGA baseline
- recorded live raw video, live filtered video, threshold button control, and VGA-only debug-pattern behavior
Files affected:
- `README.md`
- `docs/00_requirements.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-003-basic-filters.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-006-camera-capture.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that all baseline requirements are met on hardware
- documentation changes were reviewed against the existing baseline architecture decisions
Notes:
- no RTL, constraints, architecture decisions, or filter scope were changed by this documentation-only update

### [2026-05-07]
Tool: ChatGPT Codex
Used for:
- planned and implemented live-camera image robustness refinements
- changed the internal video path from RGB444 framebuffer storage to RGB565 framebuffer storage
- added bounded 320x240 camera capture, profile-selectable OV7670 initialization, low-noise and lower-speed diagnostic profiles, and RGB565 filter precision
- updated focused testbenches and documentation for the refined baseline
Files affected:
- `rtl/camera/ov7670_capture_rgb565.v`
- `rtl/camera/ov7670_init.v`
- `rtl/camera/ov7670_reg_rom.v`
- `rtl/filters/video_filter_basic.v`
- `rtl/memory/framebuffer_bram.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/vga/vga_reader_320x240.v`
- `sim/tb/tb_ov7670_capture.sv`
- `sim/tb/tb_ov7670_init.sv`
- `sim/tb/tb_vga_reader_320x240.sv`
- `sim/tb/tb_video_filter_basic.sv`
- `docs/`
Human review performed:
- repository owner reported that color bars are clean but live camera output is noisy
- implementation keeps the baseline single-framebuffer architecture and adds a lower-speed mode only as a diagnostic profile
Notes:
- hardware should be retested in profile order: color bars, live auto, live low-noise, then lower-speed diagnostic only if needed

### [2026-05-08]
Tool: ChatGPT Codex
Used for:
- implemented the reset-sampled color-bar profile and left-edge stripe debug plan
- changed the OV7670 color-bar profile to write the COM17 color-bar enable bit
- configured the integrated capture path to skip the first 8 source pixels per line
- tightened focused testbenches for 8-pixel left-skip row alignment and color-bar profile data
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_capture.sv`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-006-camera-capture.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that `sw[4:3]=11` still showed live video and that a left-edge color stripe remained after swapping camera and board
- repository owner requested reset-sampled profile behavior and a cautious 8-pixel crop while watching for tilted/distorted output
Notes:
- hardware should be retested by holding `sw[4:3]=11`, pressing/releasing `btnC`, then confirming camera color bars before returning to live profiles
- if the crop introduces tilt, revert only the skip amount and debug camera windowing separately
- local simulation could not be rerun in this shell because `iverilog`, `vvp`, Vivado, and common fallback Verilog tools were not on PATH

## 2026-05-08 — Restore full-width camera capture after crop debug
Tool: ChatGPT Codex
Used for:
- identified that the integrated `SKIP_LEFT_PIXELS=8` setting could leave the final 8 framebuffer columns unwritten when the camera outputs only 320 valid pixels per line
- restored the top-level capture instance to `SKIP_LEFT_PIXELS=0`
- updated documentation to treat left crop as a debug-only experiment, not the baseline
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-006-camera-capture.md`
- `docs/tasks/TASK-007-top-integration.md`
- `README.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the crop reduced the left color-bar issue but introduced a right-side black band on multiple boards/cameras
Notes:
- existing focused Icarus simulations were rerun locally after setting `TMP`/`TEMP` to `sim/run`
- the left-edge stripe remains a separate follow-up debug target for camera windowing, byte phase, or register-profile behavior

## 2026-05-08 — Camera line-length diagnostics for left stripe
Tool: ChatGPT Codex
Used for:
- added debug-only line-length flags to `ov7670_capture_rgb565`
- mapped `sw[2]` to a temporary LED diagnostic view without changing displayed pixels
- extended the capture testbench for short, exact-width, width+1, and width+8 line cases
Files affected:
- `rtl/camera/ov7670_capture_rgb565.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `sim/tb/tb_ov7670_capture.sv`
- `README.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-003-basic-filters.md`
- `docs/tasks/TASK-006-camera-capture.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner confirmed `sw[5]` debug pattern is clean while live camera mode still shows the left color stripe
Notes:
- with `sw[2]=1`, LEDs report line seen, line >=320, line >=321, and line >=328
- compare live and color-bar profiles before choosing a permanent capture offset or OV7670 windowing fix

## 2026-05-08 — OV7670 horizontal window shift for left stripe
Tool: ChatGPT Codex
Used for:
- interpreted `sw[2]` diagnostics showing exactly 320 completed pixels per line
- shifted OV7670 horizontal window right by 8 source pixels using `HSTART=8'h14` and `HSTOP=8'h02`
- added an explicit init testbench check for the horizontal window entries
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported `sw[2]` diagnostics as LED0 on, LED1 on, LED2 off, LED3 off
Notes:
- this avoids FPGA-side crop because the line-length diagnostic indicates there are no spare post-320 pixels
- if the stripe remains, the next window adjustment should be another 8-pixel ROM shift rather than capture crop

## 2026-05-08 — Increase OV7670 horizontal window shift
Tool: ChatGPT Codex
Used for:
- increased the OV7670 horizontal window shift from 8 to 16 source pixels after hardware showed the stripe was smaller and no right-side blanking appeared
- updated the explicit init testbench expectations for `HSTART=8'h15` and `HSTOP=8'h03`
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the 8-pixel camera-window shift reduced the left stripe and did not reintroduce the right-side black band
Notes:
- FPGA capture remains full-width with `SKIP_LEFT_PIXELS=0`
- if a stripe remains after this change, repeat the same +8 source-pixel ROM shift cautiously

## 2026-05-08 — Add one-pixel OV7670 window trim
Tool: ChatGPT Codex
Used for:
- changed OV7670 `HREF` low-bit packing from `8'hB6` to `8'hBF` to add a one-source-pixel window shift after the 16-pixel adjustment nearly removed the stripe
- kept `HSTART=8'h15` and `HSTOP=8'h03`
- updated the explicit init testbench expectations for the 17-pixel total shift
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the stripe was almost gone after the 16-pixel window shift
Notes:
- FPGA capture remains full-width with `SKIP_LEFT_PIXELS=0`
- this is a one-pixel camera-window trim, not an FPGA crop

## 2026-05-08 — Add one-pixel OV7670 vertical window trim
Tool: ChatGPT Codex
Used for:
- changed OV7670 `VREF` low-bit packing from `8'h0A` to `8'h09` to shift the camera window up by one source pixel
- kept `VSTART=8'h02` and `VSTOP=8'h7A`
- updated the explicit init testbench expectations for the horizontal and vertical window entries
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported a one-line bright artifact near the top edge and requested a small upward shift
Notes:
- FPGA capture remains full-height with `SKIP_TOP_LINES=0`
- this is a one-pixel camera-window trim, not an FPGA crop

## 2026-05-08 - Move OV7670 vertical window with high-bit registers
Tool: ChatGPT Codex
Used for:
- replaced the ineffective `VREF` low-bit vertical trim with a visible high-bit window step
- changed OV7670 `VSTART` from `8'h02` to `8'h03` and `VSTOP` from `8'h7A` to `8'h7B`
- restored `VREF=8'h0A` to the known-good base value
- updated the explicit init testbench expectations and bring-up notes
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that sweeping the `VREF` value between `8'h0F` and `8'h06` caused no visible vertical movement and the bright top-edge line persisted
Notes:
- FPGA capture remains full-height with `SKIP_TOP_LINES=0`
- this is a camera-window adjustment, not an FPGA-side top crop

## 2026-05-08 - Add one more source-pixel horizontal window shift
Tool: ChatGPT Codex
Used for:
- shifted the OV7670 horizontal window one more source pixel after hardware showed the remaining stripe was at the edge
- changed `HREF` from `8'hBF` to `8'h80` to wrap the horizontal low-bit packing
- changed `HSTART` from `8'h15` to `8'h16` and `HSTOP` from `8'h03` to `8'h04`
- updated the explicit init testbench expectations and bring-up notes for the 18-pixel total horizontal shift
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the horizontal artifact is right at the edge and should disappear with one more tiny shift
Notes:
- FPGA capture remains full-width with `SKIP_LEFT_PIXELS=0`
- this is a camera-window adjustment, not an FPGA-side crop

## 2026-05-08 - Add another one-source-pixel horizontal window shift
Tool: ChatGPT Codex
Used for:
- shifted the OV7670 horizontal window one more source pixel after the edge artifact remained
- changed `HREF` from `8'h80` to `8'h89` while keeping `HSTART=8'h16` and `HSTOP=8'h04`
- updated the explicit init testbench expectations and bring-up notes for the 19-pixel total horizontal shift
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the horizontal artifact was still visible after the 18-pixel shift and requested a little more shift
Notes:
- FPGA capture remains full-width with `SKIP_LEFT_PIXELS=0`
- this is a camera-window adjustment, not an FPGA-side crop

## 2026-05-08 - Increase vertical window skip for persistent bright line
Tool: ChatGPT Codex
Used for:
- shifted the OV7670 vertical window one more visible high-bit step after the bright horizontal line remained with the lens covered
- changed `VSTART` from `8'h03` to `8'h04` and `VSTOP` from `8'h7B` to `8'h7C`
- kept `VREF=8'h0A`, because prior `VREF` sweeps did not visibly move the image
- updated the explicit init testbench expectations and bring-up notes for the two-step vertical window shift
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the bright horizontal line remains even when the camera lid is fully closed, making scene content an unlikely cause
Notes:
- FPGA capture remains full-height with `SKIP_TOP_LINES=0`
- this is a camera-window adjustment, not an FPGA-side top crop

## 2026-05-08 - Annotate OV7670 register ROM for tuning
Tool: ChatGPT Codex
Used for:
- added inline comments to every OV7670 register ROM entry
- marked known control registers for windowing, gain, auto-exposure, white balance, matrix, saturation, denoise, clock, and color-bar tuning
- marked uncertain hardware-tested reference-table values as reserved/reference tuning so future edits can be made cautiously
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported remaining image noise and color inaccuracy and asked for the ROM table to be commented for manual fine tuning
Notes:
- no register values or behavior were changed by this annotation update
- tune one register or profile field at a time and press `btnC` after programming so the camera reloads the SCCB table

## 2026-05-08 - Add averaged-QVGA OV7670 scaling diagnostic profile
Tool: ChatGPT Codex
Used for:
- added profile-dependent OV7670 scaling/DCW register values for `sw[4:3]=10`
- kept stable live and color-bar profiles on the previous scaling register values
- updated init testbench checks for profile-specific `COM3`, `COM14`, `SCALING_XSC`, `SCALING_YSC`, `SCALING_DCWCTR`, `SCALING_PCLK_DIV`, and `SCALING_PCLK_DELAY`
- documented the averaged-QVGA diagnostic workflow
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that changing only `SCALING_DCWCTR` from `8'h11` to `8'h22` distorted the image into the upper half of the display
- repository owner requested an averaged downsampling experiment to reduce live-camera noise
Notes:
- this original experiment was first isolated to `sw[4:3]=10`; a later update moved it to `sw[6]=1, sw[4:3]=00` for fair A/B testing
- if geometry distorts, compare `sw[6]=0, sw[4:3]=00` and `sw[6]=1, sw[4:3]=00` before changing capture logic

## 2026-05-08 - Move averaged-QVGA experiment to separate A/B profile
Tool: ChatGPT Codex
Used for:
- widened the camera profile path from 2 bits to 3 bits
- mapped reset-sampled `{sw[6], sw[4:3]}` into the OV7670 ROM profile selector
- restored `sw[4:3]=10` as the low-speed diagnostic profile with stable scaler geometry
- moved the averaged-QVGA DCW/scaler settings to `sw[6]=1, sw[4:3]=00` so it uses live-auto exposure, gain, and clock tuning
- updated focused init testbench checks and switch documentation
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/camera/ov7670_init.v`
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner requested an honest A/B test because the previous `sw[4:3]=10` averaged experiment also used lower frame rate and slower shutter behavior
Notes:
- compare `sw[6]=0, sw[4:3]=00` against `sw[6]=1, sw[4:3]=00`, pressing `btnC` after switch changes
- `sw[4:3]=10` remains available as the lower-speed diagnostic

## 2026-05-09 - Add full-VGA FPGA-side 2x2 averaging experiment
Tool: ChatGPT Codex
Used for:
- added a separate reset-sampled `sw[7]=1, sw[6]=0, sw[4:3]=00` full-VGA camera profile
- added `ov7670_capture_rgb565_2x2_avg`, which uses one previous-line buffer to average 2x2 RGB565 source blocks into the existing 320x240 framebuffer
- wired top-level framebuffer writes through a capture-path mux so the stable QVGA capture remains available unchanged
- added focused simulation coverage for the new averaging capture path and updated OV7670 init profile checks
Files affected:
- `rtl/camera/ov7670_capture_rgb565_2x2_avg.v`
- `rtl/camera/ov7670_init.v`
- `rtl/camera/ov7670_reg_rom.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `constr/basys3_ov7670_vga.xdc`
- `sim/tb/tb_ov7670_capture_2x2_avg.sv`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that the OV7670 internal averaging/scaler profile showed almost no visible noise improvement and asked whether full-resolution camera output could be averaged on the board
Notes:
- the experiment does not allocate a full 640x480 framebuffer; it uses only a 640-pixel previous-line buffer before writing the existing framebuffer
- press `btnC` after changing `sw[7]`, `sw[6]`, or `sw[4:3]` so the SCCB ROM profile reloads

## 2026-05-09 - Apply tuned window to full-VGA averaging profile
Tool: ChatGPT Codex
Used for:
- updated the `sw[7]` full-VGA FPGA-side averaging profile to use the same tuned horizontal and vertical OV7670 window shifts as the stable live profile
- updated the OV7670 init testbench expectations and bring-up documentation
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that `sw[7]` improved noise strongly but brought back the left blue bar and top bright line
Notes:
- this keeps COM7 full-VGA output and FPGA 2x2 averaging unchanged; only the camera read window changes
- hardware should retest `sw[7]=1`, `sw[6]=0`, `sw[4:3]=00`, then press `btnC`

## 2026-05-09 - Clamp sw7 right-edge averaging artifact
Tool: ChatGPT Codex
Used for:
- added optional right-edge destination-column clamping to the full-resolution FPGA-side 2x2 averaging capture module
- configured the top-level `sw[7]` averaging instance to clamp the final 10 destination columns to the nearest valid averaged pixel
- extended the averaging capture testbench to verify both unclamped and clamped output behavior
Files affected:
- `rtl/camera/ov7670_capture_rgb565_2x2_avg.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `sim/tb/tb_ov7670_capture_2x2_avg.sv`
- `README.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported that the tuned `sw[7]` profile removed the top bright line but introduced a weird averaged bar on the right edge
Notes:
- default, `sw6`, and stable capture modes are unaffected because the clamp parameter defaults to zero and is only enabled on the top-level `sw7` averaging instance
- hardware should retest `sw[7]=1`, `sw[6]=0`, `sw[4:3]=00`, then press `btnC`

## 2026-05-09 - Replace sw7 clamp with horizontal window A/B variants
Tool: ChatGPT Codex
Used for:
- changed the full-VGA averaging capture selection so all reset-sampled `sw[7]=1` profiles use the FPGA-side 2x2 averaging path
- added full-VGA horizontal window variants on `sw[4:3]` for 19, 16, 8, and 0 source-pixel shifts while keeping the tuned vertical window
- disabled the top-level right-edge clamp so hardware can compare real camera-window outputs instead of a repeated edge strip
- updated OV7670 init tests and bring-up documentation
Files affected:
- `rtl/top/top_basys3_ov7670_vga.v`
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/01_architecture.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported the clamp changed the right-edge artifact into a visible blended/repeated strip
Notes:
- test `sw[7]=1`, `sw[6]=0`, and each `sw[4:3]` value, pressing `btnC` after each change
- choose the variant that best balances the left blue bar against the right-edge artifact

## 2026-05-09 - Promote sw7 8-pixel full-VGA window
Tool: ChatGPT Codex
Used for:
- updated the `sw[7]=1, sw[4:3]=00` full-VGA averaging profile to use the hardware-selected 8-source-pixel horizontal window
- kept `sw[4:3]=10` as a duplicate known-good 8-pixel comparison profile
- updated init test expectations and bring-up documentation
Files affected:
- `rtl/camera/ov7670_reg_rom.v`
- `sim/tb/tb_ov7670_init.sv`
- `README.md`
- `docs/05_roadmap.md`
- `docs/tasks/TASK-005-ov7670-init.md`
- `docs/tasks/TASK-007-top-integration.md`
Human review performed:
- repository owner reported `00` still showed the right bar, `01` reduced it by half, `10` removed it, and `11` also removed the right bar but started showing the left blue bar
Notes:
- `sw[7]=1, sw[4:3]=00` is now the practical default for full-VGA FPGA-side averaging
- press `btnC` after changing switch positions so the OV7670 reloads the selected SCCB profile

## 2026-05-09 - OV7670 noise register research report
Tool: ChatGPT Codex
Used for:
- researched public OV7670 register tables and register-description sources for noise and color tuning
- compared likely noise-related registers against the current project ROM values
- wrote a documentation-only tuning report for future hardware A/B profiles
Files affected:
- `docs/ov7670_noise_register_research.md`
- `docs/07_ai_usage_log.md`
Human review performed:
- repository owner reported full-VGA FPGA averaging works and requested research before the next register-tuning implementation
Notes:
- no RTL was changed by this report
- recommended next tests focus on `COM16`, `COM9`, and `SATCTR` before changing matrix/AWB registers

## Future logging examples

### Example for RTL generation
```text
[2026-04-15]
Tool: ChatGPT Codex
Used for:
- drafted `vga_timing_640x480.v`
- drafted `tb_vga_timing.sv`
Files affected:
- `rtl/vga/vga_timing_640x480.v`
- `sim/tb/tb_vga_timing.sv`
Human review performed:
- reviewed sync counter logic and edited reset behavior
Notes:
- final code manually adjusted before synthesis
```

### Example for bug fixing
```text
[2026-04-20]
Tool: ChatGPT
Used for:
- debugged RGB565 byte-order issue in camera capture path
Files affected:
- `rtl/camera/ov7670_capture_rgb565.v`
Human review performed:
- compared waveforms and tested on hardware
Notes:
- root cause was byte-order mismatch between assumed and actual camera output
```
