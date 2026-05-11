# TASK-009 - Full-Resolution Line-Buffer Stream

## Status
In progress / stream-only top implemented.

## Goal
Build a separate 640x480 streaming path that uses line buffers instead of a
full framebuffer. The intent is one-line-latency pass-through for the OV7670
while staying within Basys 3 BRAM limits.

## Current approach
- keep the existing framebuffer baseline intact
- use `top_basys3_ov7670_vga_stream` as the stream-only synthesis target
- capture RGB565 pixels in `cam_pclk`
- store completed scanlines in a small ring of BRAM line buffers
- read committed lines in the VGA domain
- keep the XCLK fixed at the 50 MHz baseline with a fabric divide-by-2 in the stream build
- start VGA scanout only after a two-line prefill so startup does not roll
- keep monitor-facing VGA timing free-running and standard
- keep line FIFO read/write pointers continuous across camera frame boundaries
- use synchronized camera frame starts as a resync cue at the next VGA vertical blank
- tag each committed line with camera line/frame-start metadata so the reader can detect camera frame wrap
- correct fast drift by dropping queued lines during VGA vertical blank when possible
- correct slow drift by scheduling the repeat at the top of active video instead of wherever the queue first becomes low
- use `sw[4:3]` for live diagnostics and keep `sw[7:6]` ignored by the fixed 50 MHz XCLK generator

## Implemented modules
- `rtl/top/top_basys3_ov7670_vga_stream.v`
- `rtl/camera/ov7670_capture_rgb565_linefifo.v`
- `rtl/memory/line_buffer_bank.v`
- `rtl/vga/vga_reader_linefifo.v`

## Verification
- module smoke test passes for the line-ring path, including reader output after prefill, no underflow during the bounded read, and no write-pointer reset at camera VSYNC
- stream-only top-level elaboration passes without the framebuffer or 2x2 averaging path
- baseline top-level elaboration still passes after the shared reader update
- the stream-only top uses standard VGA timing so `sw[5]=1` remains a hard monitor-lock check
- use `vivado -mode batch -source scripts/vivado/build_stream_clean.tcl` to force a fresh stream build from current repo RTL

## Notes
- this is a separate experiment from the baseline 320x240 framebuffer system
- build the stream-only top for hardware when BRAM utilization is the issue
- line ownership and read timing remain the main hardware validation risks
- with `sw[2]=1`, LED2 now includes overflow/drop corrections and LED3 includes underflow/repeat corrections
- with `sw[2]=1`, `sw[4:3]` selects diagnostic pages:
  - `00`: activity, primed, queue low, queue high
  - `01`: overflow, underflow, drop, repeat sticky events
  - `10`: camera frame seen, near target, too fast, too slow
  - `11`: frame resync, seam active, vblank drop, vblank repeat
- if rolling remains, use page `11` first to decide whether the reader is resyncing at frame boundaries or still crossing a visible seam in active video
- stream XCLK is now fixed in hardware with no MMCM or BUFGMUX rate-probe tree; the OV7670 register profile stays at the full-VGA stream baseline
- if implementation still reports `u_bufg_49p95074`, `clk49p95074`, or `u_mmcm_49p95074`, Vivado is using stale copied/cached RTL rather than the current fixed-divider source
- compression and chroma subsampling remain out of scope for this task
