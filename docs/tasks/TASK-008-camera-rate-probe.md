# TASK-008 - Camera Rate Probe

## Status
Planned / experimental.

## Purpose
Probe whether the OV7670 can run acceptably faster than the baseline 25 MHz camera clock while the existing full-VGA 2x2 averaging path and 320x240 framebuffer stay unchanged.

This task is intentionally narrower than a full full-resolution display redesign. The goal is to learn how much extra noise, instability, or color drift appears when the camera clock is increased, not to claim a guaranteed 60 fps VGA mode.

---

## Scope

In scope:
- keep the current `ov7670_capture_rgb565_2x2_avg` path
- keep the existing 320x240 framebuffer
- keep standard 640x480 VGA output unchanged
- add a reset-sampled fast-XCLK probe selection
- compare camera output quality between baseline XCLK and the faster probe clock

Out of scope:
- full-resolution framebuffer storage
- line-buffer streaming redesign
- compression
- chroma subsampling format changes
- new filters
- camera register fine tuning

---

## Current implementation hook

The top level now uses:
- `sw[7]=1` for the full-VGA averaging experiment
- `sw[6]=1` together with `sw[7]=1` to switch `cam_xclk` from the 25 MHz baseline to a 50 MHz probe clock
- `sw[4:3]` to keep the existing full-VGA noise profiles selectable during the rate probe

That lets the same image path be tested at two camera clock rates without changing the framebuffer architecture.

---

## Test plan

1. Compare `sw[7]=1, sw[6]=0` against `sw[7]=1, sw[6]=1` on the same scene.
2. Keep `sw[4:3]` fixed during the first comparison so clock rate is the only variable.
3. Check for:
   - frame lock loss
   - color drift
   - extra sparkle in dark areas
   - missed lines or obvious tearing
4. Repeat on a darker scene if the faster clock still locks.

---

## Expected outcome

One of these results should be clear:
- the faster clock is stable enough to be worth more testing
- the faster clock is too noisy or unstable, so the project should move to a line-buffered or compressed full-resolution strategy instead

