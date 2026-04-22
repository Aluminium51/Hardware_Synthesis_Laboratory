# Basys3 + OV7670 + VGA Real-Time Video Processing System

A real-time FPGA video pipeline built on the **Basys 3** using an **OV7670 camera module** and **VGA output**.

This project captures live pixel data from the camera, stores a downscaled frame in on-chip BRAM, reads the frame back in VGA timing, applies simple image filters in hardware, and displays the result on a monitor in real time.

---

# 1. Project objective

The goal of this project is to implement a complete real-time image pipeline in hardware:

1. Configure the OV7670 camera over **SCCB**
2. Capture the camera's parallel pixel stream using **PCLK**, **HREF**, and **VSYNC**
3. Store the image in a **framebuffer in BRAM**
4. Generate standard **640x480 VGA timing**
5. Display a **320x240 image** by **2x pixel doubling**
6. Switch between **raw video** and three hardware filters in real time

This matches the course baseline requirements: camera interfacing, BRAM-based frame storage, VGA display, baseline 320x200 or 320x240 resolution, and three real-time hardware image filters.

---

# 2. Baseline design decisions

The current baseline design is intentionally conservative and optimized for getting a stable working system first.

## Fixed baseline choices

- **Source image resolution:** 320x240
- **Display timing:** 640x480 @ 60 Hz VGA
- **Display method:** 2x horizontal and 2x vertical pixel doubling
- **Camera format:** RGB565
- **Stored framebuffer format:** RGB444 (12-bit)
- **Buffer strategy:** single framebuffer
- **Filter location:** filters applied on VGA readout path
- **Required filters:**
  - grayscale
  - negative / inversion
  - threshold / binary

These choices follow the project note that 320x240 is not a standard VGA mode, so the system must still generate standard 640x480 sync and display the lower-resolution image through scaling. The assignment also notes that true 640x480 at 12-bit color exceeds the BRAM capacity of the Basys 3, which is why the baseline uses lower resolution.

---

# 3. Why this architecture

This project is not mainly difficult because of the filters.

The real engineering difficulty is the integration of:

- camera initialization
- camera capture timing
- clock-domain separation
- BRAM read/write organization
- VGA timing correctness
- aligning control signals and pixel data through the pipeline

That is why the architecture is built around a simple rule:

> Store a raw 320x240 frame first, then apply filters during VGA readout.

This is the most practical approach because it allows real-time switching between filter modes without recapturing the frame or storing multiple filtered copies.

---

# 4. System-level architecture

## Top-level dataflow

```text
OV7670 Camera
   │
   ├── SCCB configuration
   │
   ├── Parallel pixel output
   │     signals: D[7:0], PCLK, HREF, VSYNC
   │
   ▼
Camera Capture Logic
   │
   ├── assemble RGB565 pixels
   ├── convert RGB565 -> RGB444
   ├── generate framebuffer write address
   └── write pixel into BRAM
   │
   ▼
Single Framebuffer in BRAM
   │
   ├── Port A: camera write side
   └── Port B: VGA read side
   │
   ▼
VGA Read Path
   │
   ├── generate 640x480 timing
   ├── map 640x480 screen coordinates to 320x240 source coordinates
   ├── read framebuffer pixel
   ├── apply selected filter
   └── drive VGA RGB + HSYNC + VSYNC
   │
   ▼
VGA Monitor
```

## Control path

```text
Basys 3 switches/buttons
   │
   ├── filter mode select
   ├── threshold control
   └── reset/debug control
```

---

# 5. Under the hood: how the project actually works

This section explains the full baseline pipeline in the order pixels move through the system.

## 5.1 Camera configuration path

The OV7670 does not automatically come up in exactly the mode we want. It must be configured through **SCCB**, which is an I2C-like serial control interface.

### What this stage does
- powers and resets the camera correctly
- sends a predefined sequence of register writes
- configures output format and size
- places the sensor into a usable video mode for the FPGA

### Important signals
- `SIO_C` / `SCL`: SCCB clock
- `SIO_D` / `SDA`: SCCB data
- `XCLK`: clock driven into the camera by the FPGA
- `PWDN`: power-down control
- `RESET`: camera reset control

### Internal module split
- `ov7670_sccb_master.v`
  - low-level serial transaction engine
- `ov7670_reg_rom.v`
  - list of camera register/value pairs
- `ov7670_init.v`
  - FSM that walks the register ROM and performs initialization

### Why this matters
If camera initialization is wrong, the rest of the pipeline can fail even if all VGA and BRAM logic is correct.

Typical symptoms of bad camera init:
- no image
- rolling image
- wrong colors
- bad sync alignment
- corrupted capture pattern

## 5.2 Camera pixel capture path

After configuration, the OV7670 outputs pixels using:

- `D[7:0]` — 8-bit data bus
- `PCLK` — pixel clock
- `HREF` — line-valid indicator
- `VSYNC` — frame boundary indicator

### What the FPGA receives
In RGB565 mode, each pixel is sent as **two 8-bit transfers**.

So the capture logic must:
1. wait for `HREF` to indicate valid line data
2. sample one byte on one `PCLK`
3. sample the second byte on the next `PCLK`
4. combine them into one RGB565 pixel
5. reduce RGB565 to RGB444
6. write the result into the framebuffer

### Why RGB565 -> RGB444
The camera commonly outputs RGB565, but the framebuffer is stored as 12-bit RGB444 to save BRAM and match the board's VGA-style 4-bit-per-channel output more naturally.

Example mapping:
- `R[4:1]` -> 4-bit red
- `G[5:2]` -> 4-bit green
- `B[4:1]` -> 4-bit blue

### Write-side addressing
For the baseline, framebuffer write addressing is kept intentionally simple.

The capture module maintains a **linear write pointer**:
- reset address at frame start
- increment by 1 for every completed pixel

This assumes the camera is configured to output data in the order we want for a 320x240 frame.

### Important implementation detail
The capture path is clocked by **camera PCLK**, not the VGA clock and not the 100 MHz system clock.

That means this stage lives entirely in the **camera clock domain**.

## 5.3 Framebuffer design

The framebuffer is the core storage element of the system.

### Baseline framebuffer properties
- resolution: 320x240
- pixels: 76,800
- color depth: 12 bits/pixel
- format: RGB444
- total size: 76,800 × 12 = 921,600 bits

This fits within the Basys 3 BRAM budget, whereas a full 640x480 12-bit framebuffer would not.

### Memory organization
The baseline uses a **single framebuffer** with **dual-port access**:

- **Write port**
  - driven by camera capture logic
  - clocked by `cam_pclk`
- **Read port**
  - driven by VGA display logic
  - clocked by `clk_vga`

### Why single buffer first
Single buffering is the simplest way to get a working system.

Tradeoff:
- simpler implementation
- lower BRAM usage
- possible tearing if camera writes while VGA reads

This is acceptable for the first working baseline. More advanced strategies like double buffering or reduced-depth buffers can be explored later.

## 5.4 VGA timing path

The VGA side of the design does **not** output “320x240 VGA.”

That is not a standard VGA mode for modern monitors.

Instead, the design always generates **standard 640x480 @ 60 Hz VGA timing**, and then displays the 320x240 framebuffer by repeating pixels.

### What the VGA timing module does
- counts horizontal pixel positions
- counts vertical line positions
- generates:
  - `HSYNC`
  - `VSYNC`
  - `active_video`
  - current screen coordinates `x`, `y`

### Why this is separate from pixel generation
Timing generation and pixel data generation are logically different jobs:

- timing defines **when** the monitor expects pixels
- data path defines **which pixel value** to show at that moment

Keeping them separate makes the design easier to verify and debug.

## 5.5 Scaling: how 320x240 becomes 640x480

The baseline display uses exact integer scaling.

### Horizontal doubling
Each source pixel is displayed for **two consecutive VGA pixel clocks**.

### Vertical doubling
Each source row is displayed for **two consecutive VGA scanlines**.

### Coordinate mapping
If the VGA timing generator outputs current screen coordinates `(x, y)` in the 640x480 active area, then the framebuffer source coordinate is:

```text
src_x = x / 2
src_y = y / 2
```

This can be implemented efficiently in hardware as bit shifts:

```text
src_x = x >> 1
src_y = y >> 1
```

### Framebuffer address
For a 320-wide framebuffer:

```text
addr = src_y * 320 + src_x
```

A hardware-friendly form is:

```text
addr = (src_y << 8) + (src_y << 6) + src_x
```

because:

```text
320 = 256 + 64
```

This avoids using a general multiplier in the simple baseline path.

## 5.6 BRAM read latency and pipeline alignment

This is one of the most important under-the-hood details.

BRAM read is not always instantaneous in the same way a software array access looks instantaneous.

So when the VGA reader computes an address:
1. it requests a pixel from BRAM
2. the pixel appears after BRAM read latency
3. the filter then processes that pixel
4. the final RGB is sent to VGA output

Because of this delay, the corresponding control signals must be delayed too:
- `active_video`
- sometimes `HSYNC`
- sometimes `VSYNC`

If this is not done correctly, the visible image can appear shifted, broken, or misaligned even though the framebuffer data itself is correct.

## 5.7 Filter path

The filters are applied **after** reading the raw pixel from the framebuffer.

That means the stored image remains unchanged, and the selected display mode only affects the VGA output path.

### Filter mode selection
The Basys 3 slide switches select the mode:
- `sw[1:0] = 00`: raw
- `sw[1:0] = 01`: grayscale
- `sw[1:0] = 10`: negative
- `sw[1:0] = 11`: threshold

The threshold value is selected with `sw[5:2]`.

### Filter 1: grayscale
Take one RGB pixel and convert it to a luminance-like value.

Simple hardware-friendly example:
- `gray4 = (R + 2*G + B) >> 2`

Then output:
- `R = gray4`
- `G = gray4`
- `B = gray4`

### Filter 2: negative
Invert each channel:
- `R_out = 15 - R`
- `G_out = 15 - G`
- `B_out = 15 - B`

### Filter 3: threshold
First compute grayscale, then compare against a threshold:
- if `gray4 >= threshold` -> white
- else -> black

### Why these filters were chosen
They are:
- visually distinct
- easy to verify
- low-risk
- per-pixel only
- no line buffers required

That makes them ideal for the baseline.

## 5.8 Clock domains

This project is multi-clock by nature.

### Clock domains in the baseline design

#### 1. System clock domain
Usually the Basys 3 onboard 100 MHz clock.

Used for:
- global control
- SCCB timing generation
- reset sequencing
- debug logic

#### 2. Camera pixel clock domain
Driven by the camera's `PCLK`.

Used for:
- sampling camera output bytes
- detecting line/frame boundaries
- generating framebuffer write enable and write address

#### 3. VGA pixel clock domain
Used for:
- VGA timing generation
- framebuffer read address generation
- filter processing
- VGA output signals

### Why this matters
Signals cannot be freely moved between clock domains.

Unsafe clock-domain crossing can cause:
- unstable behavior
- random corruption
- impossible-to-debug hardware failures

### Baseline rule
- camera capture logic stays in camera domain
- VGA output logic stays in VGA domain
- the framebuffer is the main bridge between them
- status/control crossings must be synchronized intentionally

---

# 6. Major RTL modules

This section describes the baseline module plan and what each file is responsible for.

## Top-level integration
### `top_basys3_ov7670_vga.v`
Instantiates all submodules and connects:
- board clock/reset
- switches/LEDs
- camera pins
- VGA pins
- clocking IP
- framebuffer
- filter select logic

## Clocking and reset
### `reset_sync.v`
Creates clean reset signals for each clock domain.

### Clock wizard IP
Generates clocks such as:
- VGA pixel clock
- camera `XCLK`

## VGA path
### `vga_timing_640x480.v`
Generates:
- horizontal counter
- vertical counter
- `HSYNC`
- `VSYNC`
- active display region

### `vga_reader_320x240.v`
Maps 640x480 display coordinates to 320x240 framebuffer addresses and handles read-side alignment.

### `test_pattern.v`
Used in the earliest bring-up stage before the camera path exists.

## Memory
### `framebuffer_bram.v`
Dual-port BRAM wrapper.
- port A for camera writes
- port B for VGA reads

## Filters
### `video_filter_basic.v`
Implements:
- raw pass-through
- grayscale
- negative
- threshold

### `edge_sobel.v`
Future optional extension, not part of the initial baseline.

## Camera path
### `ov7670_sccb_master.v`
Low-level SCCB transaction engine.

### `ov7670_reg_rom.v`
Register/value table for camera init.

### `ov7670_init.v`
FSM that walks the register table and programs the camera.

### `ov7670_capture_rgb565.v`
Captures two bytes per pixel from the OV7670 in the camera `pclk` domain, converts RGB565 to RGB444, and emits framebuffer write-side signals.

Stable TASK-006 interface:
- inputs: `pclk`, `rst`, `vsync`, `href`, `cam_d[7:0]`
- outputs: `wr_en`, `wr_addr[16:0]`, `wr_data[11:0]`, `frame_done`, `frame_active`

TASK-006 is simulation-verified as a module-level capture block. It has not yet been wired into the top-level framebuffer path for live display.

---

# 7. Bring-up strategy

Do not attempt full integration from the start.

This project should be brought up in stages.

## Stage 1 — VGA only
Implement:
- VGA timing
- test pattern

Success condition:
- monitor displays stable output

Status:
- Complete as of 2026-04-22.
- Basys 3 hardware displayed stable vertical color bars.
- `tb_vga_timing.sv` passed timing-counter and sync-window checks.

## Stage 2 — Framebuffer readout
Implement:
- BRAM test image
- 320x240 -> 640x480 scaling

Success condition:
- correct doubled pixels
- correct addressing

Status:
- Complete as of 2026-04-22.
- Basys 3 hardware displayed the framebuffer-backed structured pattern.
- `tb_vga_reader_320x240.sv` passed address mapping, 2x scaling, blanking, and control-alignment checks.

## Stage 3 — Filters
Implement:
- grayscale
- negative
- threshold

Success condition:
- switching modes changes display correctly

Status:
- Complete as of 2026-04-22.
- `tb_video_filter_basic.sv` passed for raw, grayscale, negative, threshold, mode switching, and default raw behavior.
- Top-level Icarus Verilog elaboration passed with switch-controlled filter integration.
- Hardware live-filter validation is still pending full-system bring-up.

## Stage 4 — SCCB and camera init
Implement:
- SCCB master
- init ROM
- init FSM

Success condition:
- SCCB master works in simulation
- OV7670 init ROM/FSM completes in simulation with explicit done/error handling
- hardware LED validation and live camera output are not proven yet

## Stage 5 — Camera capture
Implement:
- RGB565 byte assembly
- RGB444 conversion
- framebuffer writes

Success condition:
- module-level simulation proves byte assembly, write pulses, address progression, frame-boundary handling, and overflow suppression

Status:
- Complete as of 2026-04-22 for the standalone capture block.
- Capture is now wired into the top-level framebuffer write path for TASK-007.
- Vivado build and hardware live-video validation are still pending.

## Stage 6 — Integration cleanup
Fix:
- color order
- mirror/flip issues
- timing alignment
- reset behavior
- switch/control polish

This staged plan follows the assignment hint to get display working first.

---

# 8. Testing and verification

The project rubric explicitly expects module-level testbenches and simulation waveforms for major modules such as VGA sync, SCCB, memory addressing, and filters.

## Planned testbenches
- `tb_vga_timing.sv`
- `tb_vga_reader_320x240.sv`
- `tb_video_filter_basic.sv`
- `tb_ov7670_sccb_master.sv`
- `tb_ov7670_init.sv`
- `tb_ov7670_capture.sv`

## What each testbench should prove

### VGA timing
- correct line length
- correct frame length
- correct sync pulse widths
- correct active region

### VGA reader / address mapping
- coordinate-to-address mapping is correct
- pixel doubling works logically
- final address range is valid

### Filters
- each mode maps known input RGB values to expected outputs

### SCCB master
- start/stop sequence
- byte transmission order
- ack handling

### Camera init
- FSM writes the expected register sequence
- done/error handling behaves correctly

### Camera capture
- two bytes combine into one pixel correctly
- write enable pulses at the right time
- address increments correctly
- frame reset behavior works
- `frame_done` and `frame_active` behave as defined for integration
- writes are suppressed during `VSYNC` and after the address cap

---

# 9. Debug strategy

This design will likely require hardware debugging.

## Recommended debug outputs
Use LEDs for:
- clock lock
- camera init done
- camera init error
- frame heartbeat
- maybe current filter mode

## Common hardware symptoms and likely causes

### No VGA output
- bad pixel clock
- wrong sync timing
- bad constraints
- top-level pin mismatch

### Stable sync but black screen
- active video gating wrong
- BRAM path not connected
- RGB outputs always zero

### Image appears but colors are wrong
- RGB565 byte ordering wrong
- RGB channel mapping wrong
- camera configured for wrong format

### Image appears scrambled
- capture logic sampling wrong edge
- HREF/VSYNC handling wrong
- write addressing wrong

### Image shifted or torn
- BRAM read latency not matched
- single-buffer tearing
- sync/data pipeline misalignment

---

# 10. Repository layout

```text
.
├─ AGENTS.md
├─ README.md
├─ docs/
│  ├─ 00_requirements.md
│  ├─ 01_architecture.md
│  ├─ 02_clock_domains.md
│  ├─ 03_memory_plan.md
│  ├─ 05_roadmap.md
│  ├─ 07_ai_usage_log.md
│  ├─ decisions/
│  └─ tasks/
├─ rtl/
│  ├─ top/
│  ├─ clocking/
│  ├─ vga/
│  ├─ memory/
│  ├─ filters/
│  ├─ camera/
│  └─ util/
├─ sim/
│  ├─ tb/
│  ├─ vectors/
│  ├─ waveforms/
│  └─ run/
├─ constr/
├─ ip/
├─ scripts/
├─ examples/
└─ reports/
```

---

# 11. Vivado workflow

## Step 1
Create project for Basys 3 target device.

## Step 2
Add RTL design sources.

## Step 3
Add simulation sources.

## Step 4
Add constraints:
- board clock
- VGA pins
- OV7670 pins

## Step 5
Add required IP:
- clock wizard
- BRAM IP if used

## Step 6
Test in order:
1. VGA test pattern
2. framebuffer read path
3. filters
4. SCCB camera init
5. camera capture
6. full integration

## Step 7
Run:
- synthesis
- implementation
- timing check
- bitstream generation

## Step 8
Program board and validate stage by stage

---

# 12. AI usage disclosure

The course explicitly requires AI usage to be declared if AI tools were used for code generation, debugging, or drafting the report. This repository should keep a running log in:

- `docs/07_ai_usage_log.md`

That will make final reporting much easier and safer.

---

# 13. Current baseline target checklist

- [x] VGA timing generator works on hardware
- [x] BRAM-backed 320x240 image displays correctly
- [x] 2x scaling to 640x480 works correctly
- [x] grayscale filter works in simulation
- [x] negative filter works in simulation
- [x] threshold filter works in simulation
- [x] SCCB master works in simulation
- [x] OV7670 init sequence works in simulation
- [x] camera capture module works in simulation
- [x] camera capture is integrated into the top-level framebuffer path
- [ ] live raw video displays
- [ ] live filtered video displays
- [x] simulation exists for major modules (VGA timing, VGA reader/address mapping, filters, SCCB master, camera init, and camera capture)
- [ ] final block diagram and report materials are prepared

---

# 14. Key philosophy of this repo

This repository is structured around one principle:

> Bring up the video system one stable layer at a time.

Not:
- all modules at once
- all features at once
- all hardware at once

The first real success is not “camera + filters + BRAM + VGA are all written.”

The first real success is:

> a correct and testable VGA output path that can stand on its own.

Once that works, the project grows from display to memory, then from memory to filters, then from filters to live camera capture.
