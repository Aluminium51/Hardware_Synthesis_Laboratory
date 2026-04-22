# TASK-007 — Top-Level Integration

## Status
Planned

## Handoff From TASK-006
TASK-006 is implemented and simulation-verified as a standalone camera capture block.

Verified module:
- `rtl/camera/ov7670_capture_rgb565.v`

Stable capture interface:
- inputs: `pclk`, `rst`, `vsync`, `href`, `cam_d[7:0]`
- outputs: `wr_en`, `wr_addr[16:0]`, `wr_data[11:0]`, `frame_done`, `frame_active`

Known TASK-006 policies:
- RGB565 bytes are assembled MSB byte first.
- RGB444 output uses truncation: `{rgb565[15:12], rgb565[10:7], rgb565[4:1]}`.
- `VSYNC` is treated as an active-high frame boundary for the baseline.
- `wr_en` is suppressed during `VSYNC` and after the final framebuffer address until the next frame.

TASK-007 should connect this verified producer to the framebuffer write side and top-level camera pins, alongside the existing OV7670 init path. Live camera display, hardware polarity checks, color/orientation tuning, and cross-domain debug/status synchronization remain planned integration work.
