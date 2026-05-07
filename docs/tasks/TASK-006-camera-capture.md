# TASK-006 — Camera Capture Path

## Status
Complete / simulation passed.

Date completed: 2026-04-22

Implemented behavior:
- `ov7670_capture_rgb565.v` captures OV7670 RGB565 bytes in the `pclk` domain only.
- RGB565 is assembled MSB byte first and converted to RGB444 by truncation.
- `wr_en`, `wr_addr`, and `wr_data` are emitted as a clean framebuffer write-side interface.
- `wr_addr` holds when no write occurs and accepted writes are addressed linearly from zero.
- `VSYNC` is treated as an active-high frame-boundary signal for the baseline simulation model.
- `frame_done` is a one-`pclk` pulse on a `VSYNC` frame-boundary event that terminates a frame with at least one completed pixel.
- `frame_active` asserts after the first valid byte activity of a frame and clears on `VSYNC`.
- `wr_en` is forced low on cycles sampled with `VSYNC=1`.
- Incomplete byte pairs are cleared at line/frame boundaries and never produce writes.
- Address overflow is handled by suppressing writes after the final framebuffer address until the next frame boundary.

Verification:
- `tb_ov7670_capture.sv` passed with Icarus Verilog using `-g2012`.
- Simulation covered short valid line capture, line gaps, frame-boundary reset, incomplete byte-pair suppression, explicit `frame_active` behavior, `wr_en=0` during `VSYNC`, `wr_addr` hold behavior, and address-cap suppression.
- VCD output is generated at `sim/run/tb_ov7670_capture.vcd`.
- Hardware validation passed on 2026-05-07 as part of the completed baseline; live OV7670 pixels are captured into the framebuffer and displayed through the VGA read path.

Scope note:
- This standalone task did not originally wire camera capture into the top level or framebuffer instance. That integration is now complete in TASK-007.

Next task:
- `TASK-007-top-integration.md`

## Purpose
Implement the OV7670 pixel-capture path that converts the camera's parallel RGB565 stream into framebuffer-compatible RGB444 write transactions.

This task is the first **data-plane** camera milestone. It does **not** configure the camera registers directly, does **not** generate VGA timing, and does **not** add filters. Its purpose is to prove that the FPGA can correctly observe `PCLK`, `HREF`, `VSYNC`, and `D[7:0]`, assemble camera bytes into pixels, convert RGB565 to RGB444, and generate clean framebuffer write-side signals.

This module will later become the write-side producer for the existing framebuffer interface used by the VGA display path.

---

# 1. Goal

Create a synthesizable camera-capture module that:

1. Samples OV7670 output bytes in the camera pixel domain
2. Detects valid frame/line regions from `VSYNC` and `HREF`
3. Combines two consecutive 8-bit transfers into one RGB565 pixel
4. Converts RGB565 to RGB444
5. Emits framebuffer write-side signals:
   - `wr_en`
   - `wr_addr`
   - `wr_data`

The output of this task is **not** “live video on the monitor.”  
The output of this task is:

> a correct and reusable OV7670-to-framebuffer write-side capture block.

---

# 2. Why this task exists

The OV7670 outputs an 8-bit parallel video stream with synchronization signals including `PCLK`, `HREF`, and `VSYNC`, and the camera module exposes `D0-D7`, `VSYNC`, `HREF`, `PCLK`, `XCLK`, `RESET`, and `PWDN` on its header. The datasheet and common lab references also treat RGB565 as a standard OV7670 output format and QVGA as a common scaled mode for bring-up. citeturn200834search0turn200834search1turn200834search16

This task isolates the camera **data-plane** problem so it can be debugged independently from:
- SCCB transport
- camera register sequencing
- framebuffer read path
- VGA timing
- filters
- live top-level integration

That separation is critical. Do not debug camera pixel capture and top-level live display simultaneously.

---

# 3. Scope

## In scope
- pixel capture in the camera `PCLK` domain
- `VSYNC` / `HREF` handling
- two-byte RGB565 assembly
- RGB565 to RGB444 conversion
- linear framebuffer write addressing
- frame reset behavior
- simulation testbench with a synthetic camera stream

## Out of scope
- SCCB transaction engine
- OV7670 register initialization FSM
- top-level camera wiring
- clock wizard / `XCLK` generation
- framebuffer read path
- VGA timing
- filters
- true cross-domain integration into the final full system
- color tuning, mirror/flip correction, AWB, gamma, exposure tuning

This task is intentionally narrow.

---

# 4. Deliverables

Required files:

```text
rtl/camera/ov7670_capture_rgb565.v
sim/tb/tb_ov7670_capture.sv
docs/tasks/TASK-006-camera-capture.md
```

No helper RTL files were added for the completed baseline.

---

# 5. External interface

## Module name
`ov7670_capture_rgb565`

## Required top-level interface

### Inputs
- `pclk`
- `rst`
- `vsync`
- `href`
- `cam_d[7:0]`

### Outputs
- `wr_en`
- `wr_addr[16:0]`
- `wr_data[11:0]`
- `frame_done`
- `frame_active`

### Non-interface notes
- `capture_error` was not implemented for TASK-006.
- No debug-only outputs are exposed as stable ports.
- Internal signals such as `byte_phase` may still be inspected hierarchically in simulation if needed.

---

# 6. Behavioral contract

## Reset
When `rst=1`:
- `wr_en = 0`
- `wr_addr = 0`
- `wr_data = 0`
- internal byte assembly state resets
- internal frame tracking state resets
- `frame_done = 0`
- `frame_active = 0`

## Frame boundary handling
Use `VSYNC` as the frame boundary indicator.

Implemented baseline policy:
- `VSYNC` is treated as active-high.
- a rising `VSYNC` frame-boundary event resets the write pointer and byte assembly state
- `wr_en` is forced low on every `pclk` cycle sampled with `VSYNC=1`
- the next captured frame begins filling from address `0`

The exact polarity can be adapted later if needed for the selected register configuration, but TASK-006 simulation uses this active-high baseline.

## Line validity
Use `HREF` as “valid pixel bytes on this line.”

Implemented policy:
- only assemble/write pixel data while `href=1`
- when `href=0`, do not consume bytes into pixels
- leaving a line should reset any incomplete half-pixel state

## Pixel assembly
In RGB565 mode, one output pixel is formed from two consecutive 8-bit transfers. The OV7670 documentation provides RGB565 timing/byte formatting for this packed 8-bit bus mode. citeturn200834search0turn200834search1

Implemented policy:
- `byte_phase = 0`: latch first byte
- `byte_phase = 1`: latch second byte, combine into full RGB565 pixel
- only after the second byte is captured:
  - compute RGB444
  - assert `wr_en` for one `pclk` cycle
  - present valid `wr_addr`
  - present valid `wr_data`
  - increment `wr_addr`

## Write contract
- `wr_en` pulses for exactly one `pclk` cycle per completed pixel
- `wr_addr` and `wr_data` must be valid during that pulse
- `wr_en` is `0` while `VSYNC=1`
- `wr_addr` holds its current value when no write occurs
- no write occurs for incomplete pixels
- no write occurs outside valid line regions

## Frame completion
Implemented policy:
- `frame_done` is a one-`pclk` pulse on the `VSYNC` frame-boundary event that terminates a non-empty frame
- `frame_active` becomes high after the first valid byte activity of a frame
- `frame_active` clears on `VSYNC`

---

# 7. Data format contract

## Input format
Assume OV7670 is already configured for:
- RGB565 output
- QVGA / 320x240 style output

That assumption is consistent with the conservative initialization plan used in TASK-005 and with the OV7670’s documented support for RGB565 and scaled output modes. citeturn200834search1turn200834search0

## Output format
Framebuffer write data must be RGB444:
- `wr_data[11:8]` = red
- `wr_data[7:4]`  = green
- `wr_data[3:0]`  = blue

## Conversion rule
Use simple truncation for the first baseline:

```text
R4 = RGB565[15:12]
G4 = RGB565[10:7]
B4 = RGB565[4:1]
```

This is intentionally simple and deterministic.

Do not implement rounding or color correction in this task.

---

# 8. Addressing model

## Baseline addressing
Use a simple linear write address:
- first pixel of frame -> address 0
- increment by 1 for each completed pixel
- final valid pixel of a 320x240 frame -> address 76799

## Address width
17 bits is sufficient because:
- 320 x 240 = 76,800 pixels
- 76,799 fits in 17 bits

## Safety rule
Do not allow address wraparound during a single frame.

Implemented policy:
- once address reaches `76799`, suppress additional writes until the next frame boundary
- hold the final accepted `wr_addr` while writes are suppressed

---

# 9. Internal state strategy

The completed baseline keeps the stable interface narrow and uses only internal state for byte assembly, frame tracking, and address progression.

Implemented internal state includes:
- `byte_phase` for first-byte / second-byte tracking
- `first_byte` for RGB565 assembly
- an internal write pointer used to drive stable `wr_addr` pulses
- frame status flags for `frame_done`, `frame_active`, non-empty-frame detection, and address-cap suppression

No `x_count` or `y_count` debug outputs are part of the TASK-006 stable interface.

---

# 10. Expected timing assumptions

The OV7670 documentation notes that `VSYNC`, `HREF`, and `PCLK` are the main capture-timing signals, and common guidance is to sample the output stream using the camera pixel clock, commonly on the rising edge unless polarity is reconfigured through camera registers. citeturn200834search1turn200834search16

For this task:
- keep all capture logic in the `pclk` domain
- use one clock edge consistently for all input sampling
- do not mix `clk_100` or VGA timing into this module

This task should remain a pure camera-domain producer.

---

# 11. Coding requirements

## Required style
- synthesizable Verilog/SystemVerilog only
- one clean sequential capture process or a small number of clearly separated processes
- no inferred latches
- no mixed clock domains
- no embedded framebuffer memory in this module
- no top-level-specific wiring assumptions

## Naming suggestions
Use names like:
- `byte_phase`
- `first_byte`
- `rgb565_word`
- `rgb444_pixel`
- `wr_addr`
- `wr_en`
- `frame_active`
- `frame_done`

Avoid vague names like:
- `tmp`
- `data2`
- `kk`
- `flag3`

---

# 12. Testbench requirements

## Testbench name
`tb_ov7670_capture.sv`

## Goal
Verify that the capture module correctly interprets a synthetic OV7670-style RGB565 stream and emits the right framebuffer write transactions.

## Testbench strategy
Do **not** instantiate the real SCCB master or full top-level design.

Instead:
- drive `pclk`
- drive `vsync`
- drive `href`
- drive `cam_d`
- generate known short camera lines/frames
- compare observed writes against expected address/data sequences

## Required checks

### Case 1 — one short valid line
Drive:
- one valid line with a few RGB565 pixels
- `href=1` only during the valid byte region

Verify:
- one `wr_en` pulse per completed pixel
- correct `wr_addr` sequence starting at 0
- correct RGB565 assembly
- correct RGB444 truncation

### Case 2 — line gap handling
Drive:
- valid line
- `href=0` gap
- second valid line

Verify:
- no writes during the gap
- partial byte state does not leak across line boundaries

### Case 3 — frame boundary reset
Drive:
- partial or full frame data
- frame boundary with `vsync`

Verify:
- address resets correctly at the next frame
- byte assembly state resets
- `frame_done` behavior is sensible and one-shot

### Case 4 — incomplete last byte pair
Drive:
- a line ending after only one byte of a would-be pixel

Verify:
- no write occurs for the incomplete pixel
- byte assembly state clears safely at line/frame end

### Case 5 — address cap behavior
Drive more valid pixels than expected for a minimal synthetic frame sequence.

Verify:
- address does not wrap
- additional writes are suppressed or clamped according to the chosen policy

## Waveform requirements
Generate:
```verilog
initial begin
    $dumpfile("sim/run/tb_ov7670_capture.vcd");
    $dumpvars(0, tb_ov7670_capture);
end
```

Useful signals to inspect:
- `pclk`
- `vsync`
- `href`
- `cam_d`
- `wr_en`
- `wr_addr`
- `wr_data`
- DUT-internal `byte_phase` if hierarchical waveform inspection is useful

---

# 13. Hardware acceptance for this task

Hardware testing is optional for the standalone TASK-006 module before full top-level integration is available.

If you choose to test partially later, likely evidence would be:
- framebuffer visibly changing under camera-driven writes
- activity LEDs for frame/capture events

Do not block standalone TASK-006 completion on hardware when TASK-007 is reserved for full integration.

Primary acceptance here is:
- correct RTL
- correct simulation
- clean interface for later integration

---

# 14. Integration expectations for later tasks

This module will later connect to:
- OV7670 initialization from TASK-005
- framebuffer write side
- top-level debug/status logic

That means:
- its write-side interface must remain stable
- it must not assume ownership of framebuffer memory internals
- it must not perform read-side display logic
- it must remain isolated to camera capture responsibilities

Do not embed SCCB logic or live-VGA logic here.

---

# 15. Non-goals and anti-patterns

Do **not** do any of the following in this task:

- do not configure camera registers here
- do not add VGA timing here
- do not add filter logic here
- do not add line buffers here
- do not add image processing here
- do not try to support multiple camera output formats in the first baseline
- do not over-optimize byte assembly
- do not mix camera `pclk` logic with `clk_100` logic
- do not make this module aware of monitor timing

This task should be a boring write-side capture block.

---

# 16. Exit criteria

TASK-006 is complete only when all of the following are true:

1. `ov7670_capture_rgb565.v` exists and is synthesizable
2. the module captures two 8-bit camera transfers into one RGB565 pixel
3. RGB565 is converted to RGB444 correctly
4. one valid framebuffer write pulse is generated per completed pixel
5. write addresses increment correctly from 0 and do not wrap unexpectedly
6. `VSYNC` and `HREF` handling resets/guards capture state correctly
7. incomplete pixel pairs do not produce writes
8. `tb_ov7670_capture.sv` exists
9. simulation passes for:
   - short valid line
   - line gap
   - frame boundary reset
   - incomplete pair suppression
   - address cap behavior
10. generated waveforms are understandable and useful for debug

---

# 17. Suggested implementation notes for Codex

If this task is implemented by Codex, follow these rules:

- keep the entire module in the `pclk` domain
- keep the byte-assembly path explicit and readable
- prefer a simple `byte_phase` flip-flop over clever shift logic
- keep the write contract one pulse per completed pixel
- explicitly clear partial-byte state on line/frame end
- keep address progression predictable and bounded
- do not add unrelated top-level refactors while implementing this task

---

# 18. What success looks like

At the end of this task, the project should have this proven building block:

```text
OV7670 D[7:0], PCLK, HREF, VSYNC
    -> byte assembly (RGB565)
    -> RGB565 to RGB444 conversion
    -> wr_en / wr_addr / wr_data
    -> framebuffer write-side interface
```

That is enough to move to TASK-007 full integration.

Nothing more is required here.
