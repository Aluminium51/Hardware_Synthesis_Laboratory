# TASK-002 Framebuffer Read Path

## Status
Complete / hardware passed.

Date completed: 2026-04-22

Verified behavior:
- Basys 3 VGA monitor displayed the BRAM-backed synthetic 320x240 pattern.
- The image was shown through standard 640x480 VGA timing using exact 2x pixel doubling.
- No obvious one-pixel skew was observed between sync/control and image data.
- Camera capture, SCCB, filters, and XDC changes remained out of scope.

Verification:
- `tb_vga_reader_320x240.sv` passed with Icarus Verilog using `-g2012`.
- Simulation covered representative address mapping, no out-of-range reads, blanking, 2x scaling, and sync/control alignment.
- Hardware behavior was observed and confirmed by the repository owner.

Next task:
- `TASK-003-basic-filters.md`

## Goal
Display a 320x240 framebuffer image on a 640x480 VGA output using exact 2x pixel doubling.

## Why this task exists
This task proves the core display-side memory architecture before camera integration.
It verifies address mapping, BRAM read timing, and control/data alignment.

## Scope
In scope:
- framebuffer wrapper or BRAM integration
- VGA-side read addressing
- 320x240 to 640x480 scaling by coordinate halving
- active-video and sync alignment with memory read latency
- display of a known image or synthetic memory contents

Out of scope:
- camera capture
- SCCB
- live frame writes
- filter logic beyond optional passthrough

## Files allowed to change
- `rtl/memory/framebuffer_bram.v`
- `rtl/vga/vga_reader_320x240.v`
- `rtl/top/top_basys3_ov7670_vga.v`
- `sim/tb/tb_vga_reader_320x240.sv`
- memory initialization helpers or scripts if needed

## Required behavior
- `src_x = vga_x >> 1`
- `src_y = vga_y >> 1`
- `rd_addr = src_y * 320 + src_x`
- one source pixel must occupy a 2x2 region on screen
- BRAM read latency must be matched by control-signal delay

## Deliverables
- framebuffer wrapper module
- VGA read-address generator
- working top-level hookup for BRAM-backed display
- simulation testbench for address mapping
- optional initialized test image or pattern source

## Done when
1. Simulation proves address mapping for representative screen coordinates.
2. A known image or structured pattern appears correctly scaled on hardware or in a controlled test setup.
3. No obvious one-pixel skew exists between sync/control and image data.

## Suggested testbench cases
- `(0, 0)` maps to framebuffer `(0, 0)` and address `0`
- `(1, 0)` maps to framebuffer `(0, 0)` and address `0`
- `(2, 0)` maps to framebuffer `(1, 0)` and address `1`
- `(639, 479)` maps to framebuffer `(319, 239)` and address `76799`

## Common failure modes
- forgetting to halve coordinates
- wrong multiply-by-320 implementation
- not delaying active-video with BRAM latency
- address wrap or width mismatch
