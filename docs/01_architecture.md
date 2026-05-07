# 01 Architecture

## Top-level design intent
The project is structured as a streaming video pipeline around a raw framebuffer.

Chosen architecture:

```text
OV7670 Camera
   │
   ├── SCCB configuration
   ├── pixel capture in camera clock domain
   └── framebuffer write port
            │
            ▼
      BRAM framebuffer (raw RGB444)
            │
            └── framebuffer read port in VGA domain
                    │
                    ├── 320x240 -> 640x480 scaling
                    ├── filter select
                    └── VGA RGB + sync output
```

## Why this architecture
This architecture was chosen because:
- the assignment requires real-time filter switching
- storing raw frames allows multiple display modes from one captured frame
- the filters chosen for baseline are all per-pixel and fit naturally on the readout path
- it keeps the camera path focused on correct capture, not processing

## Module hierarchy

### Top level
#### `rtl/top/top_basys3_ov7670_vga.v`
Responsibilities:
- instantiate all major blocks
- connect board pins
- wire debug LEDs and switches
- own reset distribution

## Clocking and reset
### `rtl/clocking/reset_sync.v`
Responsibilities:
- synchronize reset into each clock domain
- avoid using one raw reset signal everywhere

### `ip/clk_wiz_video/`
Responsibilities:
- deferred option for deriving true video clocks if the simple baseline clocking is not sufficient

Completed baseline:
- VGA timing remains in `clk_100` and advances with a 25 MHz `pixel_ce`
- camera `XCLK` is generated in the top level with a simple divide-by-4 from `clk_100`
- live OV7670 video is captured into the framebuffer and displayed through the VGA readout path

## VGA side
### `rtl/vga/vga_timing_640x480.v`
Responsibilities:
- generate standard VGA timing
- expose pixel coordinates and active region

Key outputs:
- `hsync`
- `vsync`
- `active_video`
- `x`
- `y`

### `rtl/vga/vga_reader_320x240.v`
Responsibilities:
- convert 640x480 display coordinates into 320x240 framebuffer coordinates
- generate framebuffer read address
- align read-data latency with sync/active-video timing

Core mapping rule:
- `src_x = x >> 1`
- `src_y = y >> 1`

### `rtl/vga/test_pattern.v`
Responsibilities:
- provide a known-good visible pattern during early bring-up
- allow VGA debugging before memory or camera integration

## Framebuffer
### `rtl/memory/framebuffer_bram.v`
Responsibilities:
- implement or wrap true dual-port BRAM
- support independent write and read clocks
- store raw RGB444 pixels

Write side:
- camera domain

Read side:
- VGA domain

Depth target:
- 76,800 words

Width target:
- 12 bits per pixel

## Filters
### `rtl/filters/video_filter_basic.v`
Responsibilities:
- perform one of four display modes:
  - raw
  - grayscale
  - negative
  - threshold
- remain purely on the readout path

Inputs:
- `rgb444_in`
- `mode`
- `threshold`

Output:
- `rgb444_out`

### `rtl/filters/edge_sobel.v`
Deferred.
Only added after the baseline is already stable.

## Camera control side
### `rtl/camera/ov7670_sccb_master.v`
Responsibilities:
- low-level SCCB transactions
- start / address / data / ack / stop behavior

### `rtl/camera/ov7670_reg_rom.v`
Responsibilities:
- hold the initialization table
- keep camera register programming data outside the init FSM

### `rtl/camera/ov7670_init.v`
Responsibilities:
- sequence camera startup
- issue SCCB writes from the ROM table
- expose `done` and `error`

## Camera capture side
### `rtl/camera/ov7670_capture_rgb565.v`
Responsibilities:
- sample camera bytes in the camera pixel-clock domain
- assemble one RGB565 pixel from two bytes
- convert RGB565 to RGB444
- generate `wr_en`, `wr_addr[16:0]`, and `wr_data[11:0]` for the framebuffer write port
- expose `frame_done` and `frame_active` status for later integration/debug logic
- reset the write pointer at the active-high `VSYNC` frame boundary
- suppress writes during `VSYNC` and after the final framebuffer address until the next frame

Verification:
- TASK-006 simulation passed for byte assembly, RGB444 conversion, frame/line guard behavior, and address-cap handling.

## Utility
### `rtl/util/debounce.v`
Optional.
Used only for buttons if threshold or reset control needs button input.

## Dataflow summary by stage

### Stage A: display-only bring-up
- `clk_wiz`
- `vga_timing_640x480`
- `test_pattern`
- top-level VGA pins

### Stage B: framebuffer display path
- `framebuffer_bram`
- `vga_reader_320x240`
- optional static BRAM contents or synthetic generator

### Stage C: filter integration
- `video_filter_basic`
- switch-controlled mode select

### Stage D: camera config
- `ov7670_sccb_master`
- `ov7670_reg_rom`
- `ov7670_init`

### Stage E: camera capture
- `ov7670_capture_rgb565`
- camera write path into BRAM

### Stage F: full integration
- live camera -> BRAM -> filter -> VGA
- hardware validation passed on 2026-05-07 for raw and baseline filtered display modes

## Debug philosophy
Bring-up must be staged.

Required strategy:
1. Prove VGA without camera.
2. Prove BRAM read path without camera.
3. Prove filters without camera.
4. Prove SCCB init separately.
5. Prove camera capture.
6. Integrate the whole path.

This is mandatory because the hardest bugs in this project usually come from integrating too many uncertain modules at once.
