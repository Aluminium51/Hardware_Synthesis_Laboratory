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
      BRAM framebuffer (raw RGB565)
            │
            └── framebuffer read port in VGA domain
                    │
                    ├── 320x240 -> 640x480 2x scaling, or reset-selected 1280x960 4x scaling
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

Optional reset-selected 4x output mode:
- `sw[9]` is sampled only while `btnC` reset is held
- `sw[9]=0` keeps the 640x480 path using the existing 2x bilinear reader
- `sw[9]=1` selects a 108 MHz VGA/read clock, 1280x960 timing, and the 4x bilinear reader
- changing `sw[9]` while running does not switch resolution until reset is pressed again
- `sw[8]` remains a live nearest-neighbor/bilinear control in both modes

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

### `rtl/vga/vga_timing_1280x960.v`
Responsibilities:
- generate standard 1280x960 @ 60 Hz timing from a 108 MHz pixel clock
- expose visible coordinates, active region, positive syncs, and full timing counters
- provide `h_count` and `v_count` so the 4x reader can schedule line-buffer loads during blanking

### `rtl/vga/vga_reader_320x240.v`
Responsibilities:
- convert 640x480 display coordinates into 320x240 framebuffer coordinates
- generate framebuffer read address
- align read-data latency with sync/active-video timing

Core mapping rule:
- `src_x = x >> 1`
- `src_y = y >> 1`

### `rtl/vga/vga_reader_bilinear_4x.v`
Responsibilities:
- convert 1280x960 display coordinates into 320x240 framebuffer coordinates
- generate 4x nearest-neighbor or bilinear RGB565 output on the VGA readout path
- preload and roll two 320-pixel RGB565 line buffers during blanking
- avoid creating any 1280x960 or 640x480 framebuffer

Core mapping rule:
- `src_x = x >> 2`
- `src_y = y >> 2`
- `frac_x = x[1:0]`
- `frac_y = y[1:0]`

### `rtl/vga/test_pattern.v`
Responsibilities:
- provide a known-good visible pattern during early bring-up
- allow VGA debugging before memory or camera integration

## Framebuffer
### `rtl/memory/framebuffer_bram.v`
Responsibilities:
- implement or wrap true dual-port BRAM
- support independent write and read clocks
- store raw RGB565 pixels

Write side:
- camera domain

Read side:
- VGA domain

Depth target:
- 76,800 words

Width target:
- 16 bits per pixel

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
- `rgb565_in`
- `mode`
- `threshold`

Output:
- `rgb565_out`

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
- preserve RGB565 for framebuffer storage
- generate `wr_en`, `wr_addr[16:0]`, and `wr_data[15:0]` for the framebuffer write port
- support a per-line left-pixel skip for controlled debug only; the integrated baseline captures all 320 columns with no left crop
- expose `frame_done` and `frame_active` status for later integration/debug logic
- expose debug-only line-length flags for hardware diagnosis of camera line width and line-start artifacts
- reset the write pointer at the active-high `VSYNC` frame boundary
- suppress writes during `VSYNC` and after the final framebuffer address until the next frame

Verification:
- TASK-006 simulation passed for byte assembly, bounded 320x240 capture, frame/line guard behavior, line-length diagnostics, and address-cap handling.

### `rtl/camera/ov7670_capture_rgb565_2x2_avg.v`
Responsibilities:
- support the reset-sampled `sw[7]=1` full-VGA averaging experiment
- sample a full-VGA RGB565 camera stream in the camera pixel-clock domain
- keep one previous 640-pixel source line in FPGA memory
- average each 2x2 source block into one RGB565 output pixel
- write the averaged result into the existing 320x240 framebuffer interface
- optionally clamp right-edge destination columns to the nearest valid averaged pixel for debug experiments

This keeps the baseline framebuffer architecture unchanged while allowing a fair test of FPGA-side averaging against the OV7670 internal scaler profile.

Verification:
- A focused simulation reduces a 4x4 RGB565 source frame into 2x2 averaged framebuffer writes and checks write addresses, averaged pixel values, frame completion, and line diagnostics.

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
