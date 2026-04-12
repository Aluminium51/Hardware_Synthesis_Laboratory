# ADR-003 Single Buffer First

## Decision
Start with one framebuffer only.

## Status
Accepted.

## Rationale
- simplest architecture for first light
- avoids frame-swap control complexity
- baseline correctness is more important than removing tearing in the first milestone
