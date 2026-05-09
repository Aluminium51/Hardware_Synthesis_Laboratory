# ADR-005 - RGB565 Framebuffer Refinement

## Status
Accepted

## Date
2026-05-07

## Context
The completed baseline originally stored captured camera pixels as RGB444 because the Basys 3 VGA output exposes 4 bits per color channel.

After hardware bring-up, the OV7670 internal color bars were clean, but live camera output was noisy. This indicates that the VGA path, framebuffer readout, and byte capture are mostly functional, while live-image quality benefits from better sensor tuning and preserving more color precision through the readout path.

## Decision
Store the single 320x240 framebuffer as RGB565.

The camera capture path writes full RGB565 pixels into BRAM. VGA readout filters operate on RGB565 pixels. RGB565 is converted to RGB444 only at the final VGA pin output stage.

## Consequences
- The framebuffer size increases from 921,600 bits to 1,228,800 bits.
- The design still uses one framebuffer and still targets 320x240 source content displayed through 2x scaling at standard 640x480 VGA timing.
- The Basys 3 VGA electrical output remains RGB444.
- Filters preserve more precision internally before final VGA conversion.
- RGB565 storage is now the documented refined baseline format.
