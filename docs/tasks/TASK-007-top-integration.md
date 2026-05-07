# TASK-007 — Top-Level Integration

## Status
Complete / hardware passed.

Date completed: 2026-05-07

Implemented so far:
- `top_basys3_ov7670_vga.v` now connects OV7670 SCCB init, RGB565 capture, framebuffer write port, framebuffer read path, and VGA output.
- The synthetic framebuffer fill path has been removed as an active writer.
- Camera capture is held in reset until `init_done` is synchronized into the `cam_pclk` domain.
- `cam_siod` is implemented as an explicit top-level tri-state with readback to `siod_in`.
- `cam_xclk` is generated from `clk_100` with a divide-by-4 baseline divider.
- OV7670 bring-up now uses the sensor's internal color-bar pattern and raw passthrough display so camera-path debug is isolated from live-scene issues and filter settings.
- `sw[5]` now enables a VGA-only test pattern that bypasses the camera/framebuffer display path while leaving the camera logic running in the background for debug.
- SCCB timing has been slowed to match the known-good reference design more closely.
- Debug LEDs report slow heartbeat, init done, init error, and stretched frame-done activity.
- `constr/basys3_ov7670_vga.xdc` now enables the camera pins, `cam_pclk` clock constraint, dedicated-route override, `cam_siod` pull-up, and asynchronous grouping between `clk_100` and `cam_pclk`.

Verification:
- Icarus Verilog top-level elaboration passed for the integrated RTL.
- Existing module simulations passed for VGA timing, VGA reader, SCCB master, OV7670 init, and OV7670 capture.
- Vivado synthesis, implementation, and bitstream generation completed for the baseline hardware image.
- Basys 3 hardware validation passed with OV7670 and VGA monitor connected.
- The monitor locks to standard `640x480 @ 60 Hz` VGA.
- Live OV7670 video is captured into the single RGB444 framebuffer and displayed as `320x240` content with exact 2x scaling.
- Raw / grayscale / negative / threshold modes are selectable in real time on the VGA readout path.
- Debug LEDs provide meaningful heartbeat, init, error, and frame-activity status.

## Purpose
Integrate the already verified project building blocks into one hardware-testable top-level design:

- VGA timing and display path from TASK-001 and TASK-002
- SCCB master from TASK-004
- OV7670 init ROM + init FSM from TASK-005
- OV7670 RGB565 capture block from TASK-006
- existing framebuffer read path and 320x240 -> 640x480 scaling

This is the milestone where the project stops being a collection of validated submodules and becomes a complete live camera-to-display system.

The original TASK-007 goal was raw live video on VGA. The completed baseline also keeps the required filters on the VGA readout path.

---

# 1. Goal

Replace the synthetic framebuffer fill path with the real camera write path and connect the OV7670 control plane to the board-level camera pins.

At the end of this task, the expected live pipeline is:

```text
OV7670
  -> SCCB init
  -> RGB565 byte stream on PCLK/HREF/VSYNC
  -> ov7670_capture_rgb565
  -> framebuffer_bram write port
  -> vga_reader_320x240
  -> VGA output
```

This task is successful when:
- the camera initializes on hardware
- the framebuffer write port is driven by captured camera pixels
- the existing VGA display path shows a live raw camera image
- basic debug LEDs provide meaningful status during bring-up

This was validated on hardware on 2026-05-07.

---

# 2. Scope

## In scope
- top-level integration of existing verified modules
- board-level OV7670 pin hookup
- board-level VGA + camera coexistence
- camera XCLK generation
- SCCB line hookup at top level
- camera reset / power-down control
- switching framebuffer write source from synthetic fill to camera capture
- minimal status/debug LED plumbing
- top-level build, synthesis, implementation, bitstream, and hardware validation

## Out of scope
- new filter modules beyond the existing raw / grayscale / negative / threshold baseline
- edge detection
- color/orientation tuning beyond minimal sanity fixes
- extra credit modes
- full simulation of the entire live camera system
- advanced buffering strategies
- double buffering
- frame synchronization improvements beyond the current single-frame baseline

This task produced the first complete live camera-to-VGA baseline. Filters are also available on the VGA readout path for the completed system.

---

# 3. Inputs from earlier tasks

## Existing verified display path
Already working:
- `vga_timing_640x480`
- `framebuffer_bram`
- `vga_reader_320x240`
- top-level VGA output and scaling
- hardware-proven monitor lock and display timing

## Existing verified control path
Already working:
- `ov7670_sccb_master`
- `ov7670_reg_rom`
- `ov7670_init`

## Existing verified capture path
Already working:
- `ov7670_capture_rgb565`

TASK-007 must preserve as much of those verified module internals as possible.

---

# 4. Deliverables

Required files expected to change:

```text
rtl/top/top_basys3_ov7670_vga.v
constr/basys3_ov7670_vga.xdc
docs/tasks/TASK-007-top-integration.md
README.md                    # only if checklist/status section is updated
docs/05_roadmap.md           # only if milestone status is updated
docs/07_ai_usage_log.md      # if Codex materially contributes
```

Optional helper if needed:

```text
rtl/util/sync_2ff.v
```

Only add this if a simple status synchronizer is actually needed and improves readability.

Do not rewrite stable lower-level modules unless integration exposes a real bug.

---

# 5. Top-level integration requirements

## 5.1 Top-level ports

The top-level should now include both VGA and camera pins.

### Required board/system ports
- `clk_100`
- `btnC`

### VGA outputs
- `Hsync`
- `Vsync`
- `vgaRed[3:0]`
- `vgaGreen[3:0]`
- `vgaBlue[3:0]`

### Camera control / data ports
- `cam_xclk`
- `cam_pclk`
- `cam_vsync`
- `cam_href`
- `cam_d[7:0]`
- `cam_sioc`
- `cam_siod`
- `cam_pwdn`
- `cam_reset`

### LEDs
Use at least 4 LEDs for debug:
- `led[0]` heartbeat
- `led[1]` init_done
- `led[2]` init_error
- `led[3]` frame activity or frame_done heartbeat

If more LEDs are already convenient in the XDC, they may be used, but do not overcomplicate this task.

---

# 6. Clocking plan

## 6.1 Keep existing VGA timing architecture unchanged
Do not replace the working VGA timing approach.

Continue using:
- `clk_100`
- `pixel_ce` for 25 MHz VGA timing stepping

The display side is already proven. Do not disturb it.

## 6.2 Camera XCLK generation
Generate `cam_xclk` from `clk_100` using a simple local divide-by-4 implementation for baseline hardware bring-up.

Expected target:
- approximately 25 MHz camera XCLK

This is acceptable for the baseline integration milestone.

Do not introduce MMCM / Clock Wizard in this task unless integration completely fails due to clocking and there is clear evidence that the simple approach is the problem.

## 6.3 Camera capture clock domain
The capture block must remain entirely in the camera `cam_pclk` domain.

Do not move camera byte capture into `clk_100`.

That means:
- `ov7670_capture_rgb565` runs from `cam_pclk`
- framebuffer write port uses `cam_pclk`
- existing VGA read path stays in `clk_100 + pixel_ce`

The framebuffer remains the domain boundary.

---

# 7. SCCB and camera control integration

## 7.1 SCCB master hookup
Instantiate:
- `ov7670_sccb_master`
- `ov7670_init`

Connect:
- `ov7670_init` transaction request outputs
- to `ov7670_sccb_master` transaction inputs

`ov7670_init` should drive:
- `sccb_start`
- `sccb_dev_addr`
- `sccb_reg_addr`
- `sccb_reg_data`

`ov7670_sccb_master` should return:
- `sccb_busy`
- `sccb_done`
- `sccb_ack_error`

## 7.2 start_init policy
For simple hardware bring-up in this task:
- top-level may tie `start_init = 1'b1`

That means initialization begins automatically after reset release and internal startup delay.

Do not add a special manual start button unless there is a compelling reason.

## 7.3 SIOC / SIOD top-level behavior
`cam_sioc` is a normal driven output from `ov7670_sccb_master`.

`cam_siod` must be handled at the top level using the SCCB master's explicit drive controls.

Recommended top-level pattern:
- when `siod_oe=1`, drive `cam_siod` with `siod_out`
- when `siod_oe=0`, release `cam_siod` to high impedance
- feed the observed line back into `siod_in`

This preserves the transport contract already established in TASK-004.

## 7.4 Camera reset and power-down
For baseline bring-up:
- drive `cam_pwdn` to normal-operation state
- drive `cam_reset` to released state after top-level reset

Use the polarity assumed by the project’s selected camera module wiring and current documentation baseline.

Do not build a complicated reset sequencer unless needed.

---

# 8. Framebuffer integration

## 8.1 Remove synthetic fill as active write source
The TASK-002 synthetic framebuffer fill path should no longer be the active framebuffer writer in TASK-007.

Replace it with:
- `ov7670_capture_rgb565` outputs driving the framebuffer write port

That means the framebuffer write interface becomes:
- `wr_clk  = cam_pclk`
- `wr_en   = capture_wr_en`
- `wr_addr = capture_wr_addr`
- `wr_data = capture_wr_data`

## 8.2 Keep the existing framebuffer read path unchanged
Do not modify:
- `vga_timing_640x480`
- `vga_reader_320x240`
- scaling math
- VGA sync generation
- BRAM read-side contract

The display side is already validated. Reuse it exactly.

## 8.3 Single-frame baseline behavior
This design still uses a single framebuffer.

Accept that the live image may show:
- tearing
- partially updated frames
- occasional visual artifacts during concurrent write/read

Do not attempt to solve this in TASK-007.

The milestone goal was **live raw video works**, not perfect frame ownership. That goal was met on hardware on 2026-05-07.

---

# 9. Capture path integration requirements

Instantiate `ov7670_capture_rgb565` using:
- `pclk  = cam_pclk`
- `rst   = capture_reset`
- `vsync = cam_vsync`
- `href  = cam_href`
- `cam_d = cam_d[7:0]`

Use its outputs:
- `wr_en`
- `wr_addr`
- `wr_data`
- `frame_done`
- `frame_active`

No changes to the stable capture block interface should be made unless integration reveals a real defect.

---

# 10. Cross-domain status handling

The only cross-domain signals that may be surfaced for debug in top-level are simple status indicators such as:
- `frame_done`
- `frame_active`

These originate in `cam_pclk` domain.

If they are used to drive LEDs in the `clk_100` domain, synchronize them safely.

Recommended approach:
- for level-type status like `frame_active`, use a 2-flop synchronizer if needed
- for pulse-type status like `frame_done`, convert to a toggle or stretch into a visible heartbeat in the destination domain

Do not move data buses across domains directly.

Cross-domain synchronization is only for debug/status here, not for pixel data.

---

# 11. LED/debug policy

Use LEDs only for meaningful first-light debug.

Recommended mapping:
- `led[0]` = slow heartbeat from `clk_100`
- `led[1]` = `init_done`
- `led[2]` = `init_error`
- `led[3]` = frame activity indicator derived from capture status

Behavioral expectations:
- `led[1]` should go high once camera initialization completes
- `led[2]` should stay low on success
- `led[3]` should indicate that frames/pixels are being captured
- `led[0]` should always blink, proving the board is alive

Do not overload LED meanings.

---

# 12. XDC / constraints updates

Update `constr/basys3_ov7670_vga.xdc` to enable the required camera pins while preserving the working VGA constraints.

## Required constraint groups
- board clock
- `btnC`
- VGA pins
- used LEDs
- OV7670 pins:
  - `cam_xclk`
  - `cam_pclk`
  - `cam_vsync`
  - `cam_href`
  - `cam_d[7:0]`
  - `cam_sioc`
  - `cam_siod`
  - `cam_pwdn`
  - `cam_reset`

Do not leave stale synthetic-fill-only assumptions in the top-level/XDC pairing.

The constraints file for TASK-007 should reflect the actual top-level port list.

---

# 13. Integration behavior expectations

## Expected startup sequence
1. board reset releases
2. heartbeat starts
3. camera XCLK is present
4. `ov7670_init` waits startup delay
5. SCCB writes issue
6. if successful:
   - `init_done = 1`
   - camera begins outputting pixel stream
7. capture writes framebuffer
8. VGA read path shows live image

## If successful, hardware should show
- some live image on VGA
- possibly wrong color order
- possibly wrong orientation
- possibly tearing or unstable scene updates at first
- but recognizably camera-driven output

Those visual imperfections are acceptable in TASK-007 as long as the image path is alive.

---

# 14. Test plan

TASK-007 is primarily a **hardware integration milestone**.

## 14.1 Required pre-hardware checks
At minimum:
- Verilog compile/elaboration of the top-level and all integrated modules
- Vivado synthesis
- Vivado implementation
- bitstream generation
- review of warnings for obvious integration mistakes

## 14.2 Optional simulation
A full realistic camera-integration simulation is not required.

If desired, a minimal top-level smoke test may be added later, but it is not part of this task unless clearly needed.

Do not block this task on building a giant integration testbench.

## 14.3 Hardware acceptance
Program the board and test with:
- OV7670 connected
- VGA monitor connected

Success criteria:
- monitor locks to VGA signal
- `init_done` LED indicates successful camera init
- `init_error` stays low
- live camera-driven image appears on screen

Recorded result:
- hardware acceptance passed on 2026-05-07
- live raw video displays through the framebuffer and VGA read path
- live filtered video displays in grayscale, negative, and threshold modes

Allowed imperfections for first success:
- wrong color order
- mirrored or flipped image
- tearing
- non-ideal brightness/contrast

Not allowed:
- no image at all
- no init completion
- no VGA lock
- completely dead capture path

---

# 15. Debug and bring-up order

When hardware testing TASK-007, debug in this order:

## Step 1 — does the existing VGA path still work?
If monitor does not lock:
- fix VGA/top/XDC regression first

## Step 2 — is camera init succeeding?
Check:
- `init_done`
- `init_error`

If init fails:
- debug SCCB and camera control pins before touching capture logic

## Step 3 — is the camera producing frame activity?
Check:
- `frame_active`
- `frame_done`-derived LED behavior

If no frame activity:
- inspect XCLK
- inspect reset/powerdown control
- inspect `vsync/href/pclk` assumptions

## Step 4 — does framebuffer show camera-driven changes?
If init succeeds and frame activity exists but image is wrong:
- inspect byte ordering
- inspect polarity assumptions
- inspect orientation/color issues

This debug order matters. Do not debug all layers at once.

---

# 16. Non-goals and anti-patterns

Do **not** do any of the following in this task:

- do not add new filters beyond the baseline raw / grayscale / negative / threshold modes
- do not add edge detection
- do not refactor the working VGA path
- do not redesign the framebuffer
- do not add double buffering
- do not add MMCM unless truly necessary
- do not “improve” lower-level verified modules without evidence
- do not chase image tuning before raw live video exists

This task completed the raw integration slice and left the required baseline filters active on the VGA readout path.

---

# 17. Exit criteria

TASK-007 is complete only when all of the following are true:

1. Top-level instantiates and connects:
   - `ov7670_sccb_master`
   - `ov7670_init`
   - `ov7670_capture_rgb565`
   - `framebuffer_bram`
   - existing VGA timing and reader blocks
2. Top-level/XDC camera pins are enabled and consistent
3. Build passes through synthesis, implementation, and bitstream generation
4. Hardware shows successful camera initialization
5. Hardware shows a live camera-driven VGA image
6. Debug LEDs provide meaningful status for init and frame activity
7. The project is left in a stable raw-video state ready for filter integration

---

# 18. Suggested implementation notes for Codex

If Codex implements this task, it should follow these rules:

- preserve the verified lower-level module interfaces
- keep the VGA path unchanged
- tie `start_init` high for simple bring-up unless there is a strong reason not to
- keep camera write logic entirely in `cam_pclk`
- use the framebuffer as the only clock-domain boundary
- synchronize only simple status/debug signals across domains
- keep top-level readable and explicit
- do not add speculative features outside the task

---

# 19. What success looks like

At the end of TASK-007, the repository should have a first complete baseline video system:

```text
OV7670
  -> SCCB init
  -> RGB565 capture
  -> RGB444 framebuffer
  -> 320x240 -> 640x480 VGA read path
  -> live raw image on monitor
```

That is the baseline system the rest of the project depends on.

The completed baseline also includes the required readout-path filters:
- raw
- grayscale
- negative
- threshold
