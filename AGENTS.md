# AGENTS.md

## Project identity
This repository implements a real-time video capture and processing system on a Basys 3 FPGA using an OV7670 camera and VGA output.

The baseline target is:
- Capture video from OV7670
- Configure camera over SCCB
- Store raw frames in on-chip BRAM
- Display on VGA using standard 640x480 timing
- Show a 320x240 source image by 2x horizontal and 2x vertical pixel doubling
- Support real-time mode switching between raw video and three filters

This repository is intended to be worked on with ChatGPT Codex.

---

## Primary engineering goals
1. Get VGA output working first.
2. Get framebuffer readout and scaling working second.
3. Get basic filters working third.
4. Only then implement SCCB camera init and live camera capture.
5. Integrate carefully across clock domains.
6. Prefer a stable baseline over aggressive features.

---

## Fixed baseline decisions
These are current project decisions and should not be changed unless the relevant design document is updated first.

- Base image resolution is **320x240**.
- Display timing is **standard 640x480 @ 60Hz VGA**.
- Lower-resolution display is achieved by **2x pixel doubling**, not by nonstandard VGA timing.
- Camera output should be configured for **QVGA-like operation** and captured as **RGB565** if practical.
- Framebuffer storage format is **RGB444 (12-bit)**.
- Framebuffer stores **raw video**, not filtered video.
- Filters are applied on the **VGA readout path**.
- Start with a **single framebuffer**.
- Required baseline filters are:
  - grayscale
  - negative / inversion
  - threshold / binary
- Edge detection is optional and only after the baseline path is stable.

---

## Scope control rules
- Do not jump ahead to extra credit unless the baseline is already working on hardware.
- Do not replace the base architecture with a more complicated one unless explicitly requested in a task file.
- Do not introduce line buffers, double buffering, or external-memory-style redesigns during baseline implementation unless the task explicitly asks for it.
- Do not add edge detection to the first working baseline.
- Do not refactor large parts of the code unless there is a clear defect or the task requires it.

---

## Workflow rules
- Work in **small vertical slices**.
- Make changes that are tightly scoped to the current task.
- Prefer finishing one working stage before opening the next one.
- Read the relevant file in `docs/tasks/` before editing code.
- When a code change affects architecture, update the matching document in `docs/`.
- When a code change affects verification, update the corresponding testbench or test notes.
- Do not silently change module interfaces across many files at once.

Preferred implementation order:
1. VGA timing + test pattern
2. VGA read path for 320x240 -> 640x480 scaling
3. Basic filter block
4. Framebuffer integration
5. SCCB master
6. OV7670 init FSM + register ROM
7. Camera capture path
8. Top-level integration
9. Hardware debug cleanup
10. Final polish, report support files, and AI usage notes

---

## Repository map
- `docs/` holds requirements, architecture, roadmap, ADRs, and task briefs.
- `rtl/` holds synthesizable Verilog/SystemVerilog source files.
- `sim/` holds testbenches, vectors, and simulation scripts.
- `constr/` holds `.xdc` constraints.
- `ip/` holds Vivado IP outputs or wrappers.
- `scripts/` holds build, sim, and utility scripts.
- `examples/` holds small reference examples that define preferred coding patterns.

---

## Design rules for RTL
- Use synthesizable Verilog/SystemVerilog only.
- Keep **one major module per file** where practical.
- Separate sequential and combinational logic clearly.
- Avoid inferred latches.
- Use explicit reset behavior.
- Name signals by role and clock domain where helpful.
- Use parameters for widths, dimensions, and constants when this improves clarity.
- Keep module interfaces simple and explicit.
- Add a short header comment to each module describing:
  - purpose
  - clock domain
  - major inputs/outputs
  - important assumptions

### Naming guidance
Prefer names like:
- `clk_100`
- `clk_vga`
- `cam_pclk`
- `cam_xclk`
- `rst_vga`
- `wr_addr`
- `rd_addr`
- `rgb444_in`
- `rgb444_out`
- `active_video`

Avoid vague names like:
- `temp`
- `data2`
- `flag1`
- `state2`

---

## Clock-domain rules
This project has multiple clock domains. Treat them carefully.

Expected domains:
- system/config domain
- VGA pixel domain
- camera pixel domain

Rules:
- Camera capture logic belongs only in the **camera PCLK domain**.
- VGA timing and framebuffer readout belong only in the **VGA clock domain**.
- SCCB configuration logic belongs only in the **system/config clock domain**.
- Cross-domain status/control must use proper synchronization.
- Do not directly move multi-bit buses across domains without an intentional boundary.
- The framebuffer is the main boundary between camera write and VGA read paths.

---

## Memory architecture rules
- Baseline framebuffer is a **single raw frame buffer**.
- Use dual-port BRAM architecture or a wrapper around appropriate BRAM/IP.
- Write side is driven by camera capture logic.
- Read side is driven by VGA timing/readout logic.
- Keep framebuffer addressing simple during baseline.
- Prefer linear framebuffer addressing for storage.
- Delay control signals as needed to match BRAM read latency.

---

## Video-path rules
- Standard VGA timing must remain correct even when displaying 320x240 content.
- Pixel doubling logic must be explicit and easy to verify.
- Filters must operate on the readout path.
- Raw-video mode must remain available at all times.
- Filter switching should be driven by stable, simple control logic such as slide switches.

---

## Camera-path rules
- Camera configuration should be table-driven where practical.
- SCCB writes should be implemented with a dedicated low-level controller and a separate init FSM.
- Camera init sequencing should be explicit:
  - power/reset stabilization
  - register write sequence
  - done/error indication
- Camera pixel capture should clearly document:
  - expected byte ordering
  - RGB565 assembly
  - RGB444 conversion
  - frame boundary handling
- If hardware image orientation or color ordering is wrong, fix that after first light, not before.

---

## Verification rules
This repository must support module-level verification.

For every major module, there should be either:
- a dedicated testbench, or
- a clear reason documented for why one does not exist yet

At minimum, maintain or add testbenches for:
- VGA timing
- framebuffer read addressing / scaling
- basic filters
- SCCB master
- camera init FSM
- camera capture path

Rules:
- Do not claim a module is complete unless it has been simulated or otherwise explicitly validated.
- When fixing a bug, prefer adding or tightening a test so the bug stays fixed.
- Keep simulation artifacts organized under `sim/`.

---

## Hardware bring-up rules
Bring-up should be staged and observable.

Use debug outputs where useful:
- LEDs for clock lock, camera init done, camera init error, and heartbeat
- simple visible test patterns before live camera integration

Hardware order:
1. VGA test pattern
2. BRAM-backed image readout
3. Filter switching on static/test image
4. Camera SCCB init
5. Camera capture into framebuffer
6. Live display
7. Cleanup and stability work

Do not attempt full-system bring-up as the first hardware test.

---

## Documentation rules
When changing architecture or implementation assumptions, update the relevant docs.

Consult first:
- `docs/00_requirements.md`
- `docs/01_architecture.md`
- `docs/02_clock_domains.md`
- `docs/03_memory_plan.md`
- `docs/05_roadmap.md`
- `docs/tasks/`

Update when needed:
- task file status
- architecture notes
- design decision records
- AI usage log if generated content materially contributed to implementation

---

## Coding style preferences
- Be concise, explicit, and boring.
- Prefer readability over cleverness.
- Prefer simple arithmetic and addressing forms when they synthesize cleanly.
- Use comments to explain intent, not to narrate obvious syntax.
- Avoid giant monolithic always blocks.
- Prefer small focused modules over one huge top-level datapath file.

---

## What not to do
- Do not invent unsupported resolutions for the baseline.
- Do not replace 640x480 sync with nonstandard timings for 320x240 display.
- Do not store filtered frames instead of raw frames for the baseline.
- Do not optimize for extra credit before the baseline works.
- Do not add neural-network or advanced upscaling code during baseline development.
- Do not delete or weaken tests to make progress look better.
- Do not make broad speculative changes across unrelated files.

---

## Definition of done for a task
A task is done only when all of the following are true:
1. The requested files are updated.
2. The implementation matches the relevant task brief.
3. The relevant simulation/testbench is added or updated.
4. The expected behavior is documented clearly enough for hardware bring-up.
5. Any changed architectural assumption is reflected in `docs/`.

---

## Current baseline milestone
The current target is to reach a stable baseline system with:
- 320x240 raw framebuffer
- 640x480 VGA output using 2x scaling
- raw / grayscale / negative / threshold display modes
- single framebuffer
- OV7670 live capture
- modular RTL and module-level testbenches

Extra credit is out of scope until this baseline is working.
