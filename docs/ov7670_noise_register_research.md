# OV7670 noise and color register research

Date: 2026-05-09

## Executive summary

The image geometry work should stay fixed for now. For the current best hardware path, use `sw[7]=1`, `sw[6]=0`, `sw[4:3]=00`, which selects full-VGA sensor output plus FPGA-side 2x2 averaging with the hardware-selected 8-source-pixel horizontal window.

The next useful tuning target is not more scaling. It is sensor DSP and saturation behavior:

1. First test `COM16=0x18` instead of `0x38`. This keeps the denoise/AWB-gain bits used by common tables but disables the edge-enhancement auto bit, which can make dark speckles look sharper.
2. Then test saturation reduction, especially `SATCTR=0xC0` and `0xA0`. The Linux-derived table commonly uses `0x60`; our current table uses `0xF0`, which may make chroma noise and red/blue sparkle much more visible.
3. Do not start by changing the RGB/YUV matrix or undocumented AWB registers. Those affect color cast strongly and can hide the noise problem without reducing it.

## Current project baseline

Current relevant values in `rtl/camera/ov7670_reg_rom.v`:

| Area | Register | Current default | Current profile override | Notes |
| --- | --- | ---: | ---: | --- |
| Auto controls | `COM8` `0x13` | `0xE7` final | low-noise profiles use `0xA7` | Keeps AGC/AEC/AWB enabled, but changes AEC step behavior. |
| Exposure window | `AEW/AEB` `0x24/0x25` | `0x75/0x63` | low-noise uses `0x60/0x50`; slow diagnostic uses `0x50/0x40` | Smaller thresholds can bias exposure behavior. |
| Denoise/edge | `COM16` `0x41` | `0x38` final | `sw7` profiles `01/10/11` use `0x18` | Enables AWB gain plus denoise auto and edge auto in common register descriptions. |
| Edge factor | `EDGE` `0x3F` | `0x00` | none | Auto edge adjustment may still change edge behavior when `COM16[5]` is enabled. |
| Denoise strength | `DNSTH` `0x4C` | `0x00` | low-noise profiles use `0x0C` | If `COM16` auto denoise threshold is enabled, manual writes may be overwritten internally. |
| UV/chroma | `REG4B` `0x4B` | `0x09` | none | Bit 0 is documented in public headers as UV average enable, so current value already has that bit set. |
| Saturation | `SATCTR` `0xC9` | `0xF0` | `sw7` profiles `10/11` use `0xC0` and `0xA0` | High saturation can make chroma noise obvious. |
| Contrast | `CONTRAS` `0x56` | `0x40` | none | Common default-like value. |
| Black level | `B0..B3`, `B8` | `0x84`, `0x0C`, `0x0E`, `0x82`, `0x0A` | none | Relevant to dark-scene sparkle, but less documented and should be changed later. |

## External references reviewed

| Source | Why it matters | Useful finding |
| --- | --- | --- |
| [Adafruit OV7670 driver](https://github.com/adafruit/Adafruit_OV7670/blob/master/src/ov7670.c) | Widely reused embedded OV7670 table and the likely ancestor of our current long table. | Its RGB path selects RGB565 full-range output, and its init table uses `COM9=0x20`, `AEW=0x75`, `AEB=0x63`, and common histogram AEC values. |
| [usedbytes Pico OV7670 library](https://github.com/usedbytes/camera-pico-ov7670) | Real Pico hardware project that explicitly says it reused the Adafruit low-level register settings. | Useful as confirmation that the Adafruit-style table works on simple microcontroller capture hardware, but it is not a noise-optimized table. |
| [Linux OV7670 driver mirror](https://android.googlesource.com/kernel/common/+/refs/tags/android12-5.4.296_r00/drivers/media/i2c/ov7670.c) | Mature driver table derived from V4L2 camera support. | Uses the familiar DSP sequence and a table with `SATCTR=0x60` and `COM16=0x38`, which suggests our `COM16=0x38` is common but our `SATCTR=0xF0` is more aggressive. |
| [OV7670 register reference gist](https://gist.github.com/max-dark/dec66db741f245650a89a2b9cf35aadb) | Convenient register map with bit descriptions based on the OV7670 datasheet. | Confirms `REG4B[0]` as UV average enable and `DNSTH` as de-noise strength. |
| [STM32 OV7670 header docs](https://stm32-camera.readthedocs.io/en/latest/ov7670_8h_source.html) | Another public register-description source. | Lists `COM8`, `COM9`, `COM11`, `REG4B`, `DNSTH`, `EDGE`, and scaling-control bit meanings. |
| Local `docs/OV7670_2006.pdf` | Datasheet already stored in the repo. | Documents `COM16`: bit 5 edge-enhancement auto adjustment, bit 4 de-noise threshold auto adjustment, and bit 3 AWB gain enable. |

## Register candidates

### 1. `COM16` `0x41`: denoise vs edge enhancement

Current final value is `0x38`.

Recommended first A/B values:

| Value | Meaning for our purpose | Expected result | Risk |
| ---: | --- | --- | --- |
| `0x38` | Current: AWB gain, denoise threshold auto, edge threshold auto | Sharpest, but can emphasize red/blue sparkle | Current noisy baseline |
| `0x18` | AWB gain plus denoise threshold auto, edge auto disabled | Less sharp speckle in dark areas | Slightly softer image |
| `0x08` | AWB gain only | Tests whether denoise auto itself creates artifacts | More raw sensor noise |

Best first experiment: make one new profile that changes only final `COM16` from `0x38` to `0x18`.

### 2. `SATCTR` `0xC9`: saturation and chroma noise visibility

Current value is `0xF0`. Public Linux-derived tables commonly show `0x60`. This is not true denoise, but lower saturation can make red/blue sparkle on dark brown surfaces much less visible.

Recommended values:

| Value | Expected result | Risk |
| ---: | --- | --- |
| `0xF0` | Current, vivid color | Chroma noise is very visible |
| `0xA0` | Mild saturation reduction | Usually still colorful |
| `0x80` | Medium saturation reduction | Less vivid |
| `0x60` | Linux-style lower saturation | May look washed out |

Best second experiment: keep exposure/gain unchanged and sweep only `SATCTR`.

### 3. `REG4B` `0x4B`: UV average

Current value is `0x09`, and bit 0 is already set. Public register maps describe bit 0 as UV average enable. Because bits `[7:1]` are reserved or undocumented, this is not a good first tuning target.

Do not change `REG4B` to `0x0E` as a first test. If the public bit description is correct, `0x0E` clears bit 0 and disables UV average.

Useful later test:

| Value | Purpose |
| ---: | --- |
| `0x09` | Current, UV average bit enabled |
| `0x08` | Same nearby reserved-bit pattern, but UV average bit disabled |

Use this only after `COM16` and `SATCTR` are tested.

### 5. Color matrix and AWB registers

The current matrix and AWB block are close to the Adafruit-style values. These registers can fix color cast, but they are risky for noise work because they can amplify one channel and make sparkle worse.

Avoid changing these until the noise floor is acceptable:

- `AWBC1..AWBC6` `0x43..0x48`
- `MTX1..MTX6` `0x4F..0x54`
- `MTXS` `0x58`
- `BLUE/RED/GGAIN` `0x01/0x02/0x6A`
- `GFIX` `0x69`

## Recommended next A/B profiles

Implemented on 2026-05-09: keep the current `sw7` geometry and averaging path, and change only one or two register groups per profile so hardware observations remain meaningful.

| Profile purpose | Changes from current `sw7=1, sw[4:3]=00` | What to look for |
| --- | --- | --- |
| Baseline | none | Current brightness, color, red sparkle |
| Denoise without edge | `COM16=0x18` | Less sharp sparkle, slightly softer edges |
| Lower saturation | `SATCTR=0xC0` or `0xA0` | Less red/blue chroma noise without too much color loss |
| Combined candidate | `COM16=0x18`, `SATCTR=0xA0` | Practical best-looking profile if individual tests are positive |

## Hardware test checklist

Use the same scene and lighting for each profile:

1. Reset workflow: set switches, press `btnC`, wait for camera init done.
2. Use the full-VGA averaging path: `sw[7]=1`, `sw[6]=0`.
3. Keep the same object distance and lens focus.
4. Test a dark brown or black surface, because that exposed red sparkle.
5. Test a normal colorful object, because saturation and AWB changes can look good on dark scenes but bad on real colors.
6. Test lens covered for black-frame noise. If sparkle remains with the lens fully covered, it is likely gain/DSP/black-level noise, not scene texture.
7. Record for each profile:
   - brightness
   - red/blue sparkle
   - grayscale-looking noise
   - color accuracy
   - motion smear
   - edge sharpness

## Recommendation

The temporary `sw7` full-VGA averaging tuning profiles are:

- `00`: current baseline, unchanged
- `01`: `COM16=0x18`
- `10`: `COM16=0x18`, `SATCTR=0xC0`
- `11`: `COM16=0x18`, `SATCTR=0xA0`

That sequence isolates the likely causes in order: edge-enhanced sparkle, then chroma-noise visibility.
