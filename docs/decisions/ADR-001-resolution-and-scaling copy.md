# ADR-001 Resolution and Scaling

## Decision
Use a 320x240 source image stored in BRAM and display it on a monitor using standard 640x480 VGA timing with 2x integer scaling.

## Status
Accepted.

## Rationale
- fits the assignment baseline cleanly
- fits BRAM budget better than true 640x480 full-frame storage
- keeps the display side simple and deterministic
- matches the technical note that lower resolution should still use standard VGA timing
