# TASK-005 — OV7670 Initialization

## Status
Complete / simulation passed.

Date updated: 2026-05-09

Verified behavior:
- `ov7670_reg_rom.v` now exposes a deterministic extended RGB565/QVGA startup table derived from the known-good hardware reference design.
- The final ROM entry keeps OV7670 internal color bars enabled so hardware bring-up can target a stable debug pattern before switching to live video.
- The horizontal window is shifted right by 19 source pixels using `HSTART=8'h16`, `HSTOP=8'h04`, and `HREF=8'h89` low-bit packing to address the observed left-edge stripe while preserving 320 captured pixels per line.
- The vertical window is shifted up by two visible high-bit window steps using `VSTART=8'h04`, `VSTOP=8'h7C`, and the known-good `VREF=8'h0A` low-bit packing to address the observed bright top-edge line.
- `sw[6]=1, sw[4:3]=00` now selects an averaged-QVGA A/B profile that keeps live-auto exposure/gain/clock tuning while changing `COM3`, `COM14`, `SCALING_XSC`, `SCALING_YSC`, `SCALING_DCWCTR`, and `SCALING_PCLK_DIV` together instead of changing `SCALING_DCWCTR` alone.
- `sw[7]=1` now selects full-VGA RGB profiles for FPGA-side 2x2 averaging; it disables COM7 QVGA mode, keeps the tuned vertical edge-skip window, keeps the hardware-selected 8-source-pixel horizontal shift for all subprofiles, and uses `sw[4:3]` for `COM16`/`SATCTR` noise tuning.
- Invalid ROM indices return the final valid entry with `is_last=1`.
- `ov7670_init.v` waits for startup delay and explicit `start_init` before issuing SCCB traffic.
- The init FSM emits one `sccb_start` pulse per ROM entry and holds transaction fields stable while SCCB is busy.
- The FSM waits `POST_RESET_DELAY_CLKS` after the `12/80` soft-reset write.
- `init_done` and `init_error` are sticky until reset, and failures stop ROM advancement.
- Hardware validation passed on 2026-05-07 as part of the completed baseline; camera initialization reaches the expected done state without the error indicator.

Verification:
- `tb_ov7670_init.sv` passed with Icarus Verilog using `-g2012`.
- Simulation covered full successful initialization and injected SCCB ACK failure.
- VCD output is generated at `sim/run/tb_ov7670_init.vcd`.

Scope note:
- Pixel capture, framebuffer writes, live VGA display integration, and top-level LED wiring were out of scope for the standalone TASK-005 module work and are covered by the later integration tasks.

Next task:
- `TASK-006-camera-capture.md`

## Purpose
Implement the **OV7670 camera initialization layer** that uses the SCCB master from TASK-004 to program the camera with a known-good startup register sequence.

This task is the second control-plane milestone for camera bring-up. It does **not** capture image pixels yet. Its purpose is to prove that the FPGA can step through a table of OV7670 register writes, drive the SCCB master correctly, and reach a clean `init_done` state with explicit error handling.

This module will be used by later tasks to prepare the camera for:
- RGB output
- baseline 320x240 operation
- stable live capture into the framebuffer

---

# 1. Goal

Create a synthesizable OV7670 initialization subsystem composed of:

1. a **register table / ROM**
2. an **initialization FSM**
3. a clean interface to the SCCB master from TASK-004

The initialization layer must:
- wait for camera power/reset stabilization
- walk through a fixed register/value sequence
- issue one SCCB write per entry
- stop cleanly on completion
- expose `init_done`, `busy`, and `error` status

The output of this task is **not** “live camera works.”  
The output of this task is:

> the FPGA can reliably configure the OV7670 using a controlled sequence of SCCB register writes.

---

# 2. Why this task exists

The course brief explicitly requires the OV7670 camera to be configured through **SCCB** before valid capture. It also expects modular design and testbench coverage for major modules. This task isolates camera configuration from pixel capture so that initialization can be debugged independently. 

This separation is important because camera bring-up has two distinct problems:

1. **control plane**
   - SCCB communication
   - register programming
   - startup sequencing

2. **data plane**
   - `PCLK`
   - `HREF`
   - `VSYNC`
   - RGB byte capture
   - framebuffer writes

This task handles only the first one.

---

# 3. Scope

## In scope
- OV7670 initialization register table
- initialization FSM
- SCCB write sequencing using the TASK-004 master
- startup delay / reset stabilization behavior
- end-of-table detection
- status outputs: `init_busy`, `init_done`, `init_error`

## Out of scope
- pixel capture
- framebuffer writes
- live VGA display integration beyond optional debug LEDs
- dynamic runtime camera reconfiguration
- camera register reads
- automatic recovery/retry logic
- image orientation tuning unless explicitly placed in the register table
- filter logic

This task is intentionally focused on deterministic camera startup.

---

# 4. Deliverables

Required files:

```text
rtl/camera/ov7670_reg_rom.v
rtl/camera/ov7670_init.v
sim/tb/tb_ov7670_init.sv
docs/tasks/TASK-005-ov7670-init.md
```

Required dependency from previous task:

```text
rtl/camera/ov7670_sccb_master.v
```

Optional helper file if useful:

```text
rtl/util/delay_counter.v
```

but avoid introducing extra files unless they improve clarity.

---

# 5. High-level architecture

The initialization subsystem should look like this:

```text
ov7670_reg_rom
    -> provides {reg_addr, reg_data, is_last}

ov7670_init
    -> sequences startup delay
    -> reads ROM entries
    -> drives SCCB master start/data handshake
    -> waits for done / checks ack_error
    -> advances ROM index
    -> asserts init_done or init_error
```

The SCCB master remains a separate transport block.
The init FSM is the policy/controller layer on top of it.

This separation must remain clean.

---

# 6. Register-table strategy

## Basic rule
Use a **small, conservative, known-good initialization sequence**.

Do **not** try to configure every possible OV7670 feature.

For this task, the sequence should aim for:
- reset / startup sanity
- RGB output mode
- baseline QVGA-style operation if possible
- stable output suitable for later capture

## Recommended contents of the ROM
The register ROM should store entries as:

```text
{reg_addr[7:0], reg_data[7:0], is_last}
```

or equivalently:
```text
{is_last, reg_addr, reg_data}
```

Choose one format and document it clearly.

## Recommended design rule
Keep the ROM simple:
- plain combinational `case`
- or small constant array if using SystemVerilog and tool flow supports it cleanly

Do not over-engineer this.

---

# 7. Initialization FSM behavior

## Required startup phases

The init FSM should include these conceptual phases:

```text
RESET_WAIT
LOAD_ENTRY
ISSUE_WRITE
WAIT_SCCB_DONE
CHECK_RESULT
ADVANCE_OR_FINISH
INIT_DONE
INIT_ERROR
```

You may break these into smaller states if that improves clarity.

## Behavioral flow

### Phase 1 — stabilization
After reset release:
- wait a fixed number of clock cycles before starting SCCB transactions
- this gives camera reset/power lines time to settle

### Phase 2 — register sequencing
For each ROM entry:
1. load `reg_addr` and `reg_data`
2. present write transaction inputs to SCCB master
3. pulse `start`
4. wait for `done`
5. if `ack_error`, move to `INIT_ERROR`
6. else continue to next entry

### Phase 3 — completion
After the last entry:
- assert `init_done`
- stop issuing SCCB traffic
- hold stable status

---

# 8. External interface

## Module name
`ov7670_init`

## Required top-level interface

### Inputs
- `clk`
- `rst`
- `start_init`
- `sccb_busy`
- `sccb_done`
- `sccb_ack_error`

### Outputs
- `init_busy`
- `init_done`
- `init_error`
- `sccb_start`
- `sccb_dev_addr[7:0]`
- `sccb_reg_addr[7:0]`
- `sccb_reg_data[7:0]`

### Notes
- `start_init` should be a one-shot request from top-level control or tied high after reset in a simple bring-up design
- `sccb_dev_addr` should normally be a fixed OV7670 write address value for all transactions in this task
- `sccb_start` must be a pulse, not a level held high indefinitely

The init block should not directly drive SCCB wires.
It should only drive the SCCB master control interface.

---

# 9. Status signal contract

## `init_busy`
High from the moment initialization starts until it either completes or fails.

## `init_done`
Should assert when the full register sequence completes successfully.

Recommended behavior:
- either sticky-high until reset
- or one-cycle pulse plus a separate sticky success flag

Preferred for this project:
- **sticky-high until reset**

because it is easier to observe on hardware with an LED.

## `init_error`
Assert when any SCCB register write fails.

Recommended behavior:
- sticky-high until reset

This is also easier for hardware debug.

---

# 10. SCCB interaction contract

The init FSM must assume the SCCB master from TASK-004 works as follows:

- caller provides `dev_addr`, `reg_addr`, `reg_data`
- caller pulses `start`
- SCCB master raises `busy`
- SCCB master eventually asserts `done`
- SCCB master also indicates whether an ACK failure happened

The init FSM should not assume any internal SCCB timing details beyond that handshake.

## Important rules
- do not pulse `sccb_start` while `sccb_busy` is high
- do not change transaction fields while a transaction is in progress
- latch or hold the current register pair stable until the SCCB transaction finishes

---

# 11. Reset and startup policy

This task should include a simple startup delay before the first SCCB transaction.

## Recommended policy
After reset deassertion:
- enter `RESET_WAIT`
- wait a fixed number of `clk` cycles
- then begin loading ROM entry 0

Do not make this delay extremely long in simulation.
If needed, parameterize it so simulation can use a smaller value.

Example:
- hardware default: moderate delay
- testbench override: tiny delay

That keeps simulation fast without changing logic structure.

---

# 12. Register ROM requirements

## Module name
`ov7670_reg_rom`

## Required interface
### Inputs
- `index`

### Outputs
- `reg_addr[7:0]`
- `reg_data[7:0]`
- `is_last`

## Design requirements
- deterministic ordering
- no side effects
- easy to inspect in simulation
- easy to edit later if camera tuning changes

## Strong recommendation
Add comments for each entry explaining its intent where practical.

Example:
- reset / common control
- RGB output format
- QVGA scaling / size
- clocking tweak
- color matrix / format fix if needed

Do not turn this into an unexplained wall of hex constants.

---

# 13. Coding requirements

## Required style
- synthesizable Verilog/SystemVerilog only
- explicit FSM
- explicit ROM contents
- no inferred latches
- no mixed unrelated responsibilities in one module
- clear handshake separation between init FSM and SCCB master

## Naming suggestions
Use names like:
- `rom_index`
- `current_reg_addr`
- `current_reg_data`
- `start_pulse`
- `init_busy`
- `init_done`
- `init_error`
- `startup_delay_done`

Avoid vague names like:
- `temp`
- `cfg1`
- `flagx`

---

# 14. Testbench requirements

## Testbench name
`tb_ov7670_init.sv`

## Goal
Verify that the initialization FSM walks the ROM correctly and drives the SCCB master interface correctly under both success and failure conditions.

## Recommended testbench structure
Use a **fake SCCB responder model**, not the real SCCB waveform generator, for this task.

That means:
- instantiate `ov7670_init`
- emulate the SCCB master handshake using a small behavioral model
- let the testbench control:
  - `sccb_busy`
  - `sccb_done`
  - `sccb_ack_error`

This isolates the init FSM behavior from low-level SCCB timing.

## Required checks

### Case 1 — successful initialization
Testbench behavior:
- after `start_init`, emulate successful SCCB completion for each ROM entry

Verify:
- ROM index starts at 0
- one SCCB write request is issued per ROM entry
- writes occur in the expected order
- last entry terminates initialization
- `init_done == 1`
- `init_error == 0`

### Case 2 — failure on a chosen entry
Testbench behavior:
- force `sccb_ack_error = 1` on one selected transaction

Verify:
- FSM stops further progress
- `init_error == 1`
- `init_done == 0`
- no additional entries are issued after failure

### Optional Case 3 — ignore repeated start requests
If `start_init` pulses again after completion or during busy state:
- verify behavior remains stable and no duplicate re-entry occurs unless explicitly supported

---

# 15. Waveform and observability requirements

The testbench should produce waveform output.

Recommended:

```verilog
initial begin
    $dumpfile("tb_ov7670_init.vcd");
    $dumpvars(0, tb_ov7670_init);
end
```

Useful signals to inspect:
- `clk`
- `rst`
- `start_init`
- `rom_index`
- `current_reg_addr`
- `current_reg_data`
- `sccb_start`
- `sccb_busy`
- `sccb_done`
- `sccb_ack_error`
- `init_busy`
- `init_done`
- `init_error`
- FSM state

The waveform should make it obvious which register entry is being issued at each step.

---

# 16. Hardware acceptance for this task

Hardware testing is optional but useful.

If attempted, keep it minimal.

## Recommended optional top-level hardware behavior
- `led[0]` heartbeat
- `led[1]` init_busy
- `led[2]` init_done
- `led[3]` init_error

You do **not** need live camera output yet.

The purpose of optional hardware for this task is only:
- confirm the FSM runs
- confirm it reaches done or error deterministically

Do not block task completion on live video.

Primary acceptance is:
- simulation correctness
- clean integration contract with SCCB master

---

# 17. Integration expectations for later tasks

This module will later connect like this:

```text
top control
   -> ov7670_init
   -> ov7670_sccb_master
   -> OV7670 camera
```

Later, pixel capture should only begin after:
- `init_done == 1`
- `init_error == 0`

That means this task defines a gating condition for later camera capture and top-level integration.

---

# 18. Non-goals and anti-patterns

Do **not** do any of the following in this task:

- do not merge SCCB bit-level logic into the init FSM
- do not implement pixel capture here
- do not add framebuffer logic here
- do not add runtime camera setting changes here
- do not add retry loops unless explicitly requested
- do not make the ROM dynamically writable
- do not hide the register sequence in unreadable packed constants without comments
- do not assume success without checking `ack_error`

This task should be deterministic and boring.

---

# 19. Exit criteria

TASK-005 is complete only when all of the following are true:

1. `ov7670_reg_rom.v` exists and exposes a deterministic register sequence
2. `ov7670_init.v` exists and is synthesizable
3. initialization waits for startup delay before issuing SCCB traffic
4. one SCCB transaction is issued per ROM entry
5. the sequence stops cleanly at the last ROM entry
6. `init_done` asserts on success
7. `init_error` asserts on failure
8. `tb_ov7670_init.sv` exists
9. simulation passes for:
   - full successful sequence
   - injected SCCB failure
10. waveforms are understandable and clearly show sequence progress

---

# 20. Suggested implementation notes for Codex

If Codex implements this task, it should follow these rules:

- keep ROM and FSM in separate modules
- keep the interface to the SCCB master explicit and narrow
- use a simple startup wait state
- use sticky `init_done` and sticky `init_error`
- do not refactor unrelated top-level VGA/framebuffer logic
- do not start pixel capture work in this task
- keep the register table minimal and conservative

---

# 21. What success looks like

At the end of this task, the project should have this proven control chain:

```text
Register ROM
    -> OV7670 init FSM
    -> SCCB master handshake
    -> register writes issued in correct order
    -> init_done or init_error
```

That is enough to move to camera pixel capture in TASK-006.

Nothing more is required here.
