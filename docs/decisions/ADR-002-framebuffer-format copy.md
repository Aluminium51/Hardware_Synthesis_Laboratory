# ADR-002 Framebuffer Format

## Decision
Capture camera pixels as RGB565 and store framebuffer data as RGB444.

## Status
Accepted.

## Rationale
- RGB565 is a practical camera-side format
- RGB444 maps well to Basys 3 VGA output width
- 12-bit storage reduces BRAM usage while keeping color recognizable
