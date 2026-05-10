# Importing Haar Cascade weights into Vivado BRAM (quick guide)

This document explains how to convert OpenCV Haar cascade XML weights into a ROM you can instantiate in Vivado.

The current RTL uses a compact 32-bit packed ROM format in `rtl/top/face_detect.v`:

- stage header word: `[15:8] = feature_count`, `[7:0] = vote_threshold`
- feature header word: `[31:16] = weak_threshold` (signed 16-bit)
- rectangle word: `[31:27] x`, `[26:22] y`, `[21:17] w`, `[16:12] h`, `[11:4] weight`, `[3:0] reserved`

Each feature uses one header word followed by two rectangle words.

1) Convert XML to COE

   Use the provided converter script to create a `.coe` file. Example:

   ```bash
   python Hardware_Synthesis_Laboratory/scripts/util/opencv_haar_to_coe.py \
       haarcascade_frontalface_default.xml haarcascade_out.coe
   ```

  The script in `scripts/util` is a starter. It currently emits stage thresholds only,
  so you should extend it to pack stage headers, feature headers, and rectangle words
  in the format above before using it as the final cascade ROM source.

2) Create ROM in Vivado

   - Open IP Catalog -> Block Memory Generator.
  - Configure Data Width to 32 bits and depth to match the number of packed words.
   - In the GUI, choose "Use COE File" and point to your `.coe` file.
   - Generate the IP and add it to your block design or instantiate the core in RTL.

3) Connect ROM to cascade evaluator

   - The ROM will expose an address and data port. Implement a small FSM to step
     through the cascade structure, reading rectangle definitions, thresholds, and
     weak classifier outputs.
   - Use the 24x24 line buffers and local integral image to compute area sums needed
     by Haar features, then evaluate each feature using weights read from ROM.

4) Simulation

   - For behavioral simulation you can use the provided zero-filled placeholder ROM files.
   - The placeholder files are safe defaults and should not be treated as real weights.

Notes

- Many open-source projects (Risto97, lulinchen, jedbrooke) have scripts showing
  precise packing formats. Study them if you need a drop-in hardware cascade.
- The provided `opencv_haar_to_coe.py` is a starter; adapt it to pack the real
  cascade parameters into the 32-bit ROM layout used by `face_detect.v`.
