# 03 Memory Plan

## Goal
Define the baseline framebuffer architecture for the first working system.

## Chosen baseline memory strategy
- one raw framebuffer only
- on-chip BRAM only
- no external frame memory
- no double buffering in the first baseline
- one write port from camera domain
- one read port from VGA domain

## Why single framebuffer first
Single buffering is the simplest architecture that satisfies the baseline assignment.

Reasons:
- fits the board constraints better than immediate double buffering
- reduces first-pass integration complexity
- allows camera capture and VGA output to be wired early
- keeps the project focused on getting first light

Tradeoff accepted:
- image tearing may occur while camera writes and VGA reads the same frame

This tradeoff is acceptable for the first baseline.

## Resolution choice
Chosen source framebuffer resolution:
- `320 x 240`

Pixel count:
- `320 * 240 = 76,800`

## Pixel storage format
Chosen storage format:
- `RGB444`

Bits per pixel:
- `12`

Total frame storage:
- `76,800 * 12 = 921,600 bits`

This comfortably fits within Basys 3 BRAM capacity for a single framebuffer.

## Camera input format
Chosen capture target format from camera:
- `RGB565`

Reason:
- standard and common OV7670 mode
- straightforward to assemble from two 8-bit transfers
- easy to reduce to RGB444 for storage

## RGB565 to RGB444 conversion
Proposed down-conversion:
- `R4 = R5[4:1]`
- `G4 = G6[5:2]`
- `B4 = B5[4:1]`

This keeps the logic cheap and deterministic.

## Addressing strategy
Use linear addressing for the framebuffer.

Write-side rule:
- increment one address per completed pixel
- reset address to zero at frame start

Read-side rule:
- compute source coordinates from VGA coordinates
- map source `(x, y)` to linear address

Formula:
- `addr = y * 320 + x`

Preferred implementation:
- `320 = 256 + 64`
- so use shift-add when practical

Equivalent expression:
- `addr = (y << 8) + (y << 6) + x`

## Read mapping for display scaling
The monitor timing is standard 640x480.
The source framebuffer is 320x240.

Therefore:
- `src_x = vga_x >> 1`
- `src_y = vga_y >> 1`
- `rd_addr = src_y * 320 + src_x`

This creates exact 2x integer scaling in both dimensions.

## BRAM interface plan
Preferred baseline interface:
- true dual-port BRAM

### Port A: write side
- clock: `cam_pclk`
- enable: `wr_en`
- address: `wr_addr`
- data in: `wr_data[11:0]`

### Port B: read side
- clock: `clk_vga`
- address: `rd_addr`
- data out: `rd_data[11:0]`

## Implementation options
Baseline recommendation:
- use a BRAM wrapper module in RTL
- internally instantiate Vivado Block Memory Generator IP or XPM

Reason:
- keeps the rest of the design independent of the exact memory primitive
- easier to swap implementation later if needed

## Read latency policy
Assume BRAM read is synchronous.
That means the VGA path must be designed to tolerate at least one cycle of memory latency.

Required implication:
- delay `active_video` and sync/control signals to line up with valid pixel data

## Frame ownership policy for baseline
No explicit frame-swap protocol in the first version.

Baseline behavior:
- camera continuously writes sequential pixels into the single framebuffer
- VGA continuously reads according to display timing
- occasional tearing is accepted

## Memory-related future upgrades
Do not implement these until baseline is stable.

Possible future upgrades:
- double buffering with frame swap
- reduced color depth to fit multiple buffers
- line buffering for convolution filters
- direct stream processing without full-frame storage

## Current decision summary
- source resolution: `320x240`
- storage format: `RGB444`
- one framebuffer only
- dual-port BRAM
- linear addressing
- filters applied after BRAM read
