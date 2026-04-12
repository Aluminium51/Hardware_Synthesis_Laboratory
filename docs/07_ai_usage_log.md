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
