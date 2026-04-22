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
