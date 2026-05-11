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

The working baseline still uses the single framebuffer path. A separate
full-resolution line-buffer streaming experiment now exists beside it for the
later 640x480 pass-through work, but it is not the baseline architecture.

## Module hierarchy

### Top level
#### `rtl/top/top_basys3_ov7670_vga.v`
Responsibilities:
- instantiate all major blocks
- connect board pins
- wire debug LEDs and switches
- own reset distribution

#### `rtl/top/top_basys3_ov7670_vga_stream.v`
Responsibilities:
- provide a stream-only full-resolution experiment build
- exclude the baseline framebuffer and 2x2 averaging path from synthesis
- connect OV7670 full-VGA capture directly to the line-ring VGA reader
- keep VGA timing free-running while the line ring absorbs camera/VGA rate drift

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
- the `sw[7]=1, sw[6]=1` full-VGA experiment adds a 50 MHz camera XCLK probe while keeping the same framebuffer path

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

For later rate experiments, the same full-VGA averaging path can be reused with a faster `cam_xclk` probe selected from the top level without changing the framebuffer size or readout path.

Verification:
- A focused simulation reduces a 4x4 RGB565 source frame into 2x2 averaged framebuffer writes and checks write addresses, averaged pixel values, frame completion, and line diagnostics.

### `rtl/camera/ov7670_capture_rgb565_linefifo.v`
Responsibilities:
- capture a full 640x480 RGB565 camera stream into a small ring of line buffers
- emit line-commit ownership through a compact pointer/token boundary
- keep camera-domain write timing separate from VGA-domain line consumption
- keep line FIFO ownership pointers continuous across camera `VSYNC`; frame boundaries reset camera parsing state, not line-ring ownership
- tag each line-buffer bank with camera line number and first-line-after-`VSYNC` metadata for seam diagnostics
- support the reset-sampled `sw[7]=1, sw[6]=1` full-resolution streaming experiment

Supporting modules:
- `rtl/memory/line_buffer_bank.v`
- `rtl/vga/vga_reader_linefifo.v`

This is the first-step architecture for full-resolution display without a full
framebuffer. It remains experimental until the line ownership, read timing, and
hardware lock behavior are proven on the board.

The stream-only top-level should be used for synthesis when BRAM utilization is
the limiting factor. The combined baseline top still contains both architectures
for elaboration/debug convenience and is not the memory-minimized build.

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

### Stage G: full-resolution streaming experiment
- live camera -> line ring -> VGA
- no full-frame BRAM storage
- one-line-latency pass-through experiment for 640x480 display
- separate from the baseline framebuffer pipeline
- free-running standard VGA timing for monitor lock
- continuous line FIFO pointers across camera frames
- camera frame timing used only for stream re-prime metadata and diagnostics
- camera frame-wrap detection in the VGA reader
- vblank-first line-drop correction for fast drift and top-of-frame repeat correction for slow drift
- reset-sampled `sw[7:6]` timing probes in the stream-only top to compare 50 MHz, 49.5 MHz, 49.0 MHz, and 48.5 MHz camera XCLK behavior

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
