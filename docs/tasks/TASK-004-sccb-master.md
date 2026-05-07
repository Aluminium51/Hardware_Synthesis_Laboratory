# TASK-004 — SCCB Master

## Status
Complete / simulation passed.

Date completed: 2026-04-22

Verified behavior:
- `ov7670_sccb_master.v` implements a write-only SCCB transaction engine.
- The master emits START, three MSB-first byte phases, ACK phases, STOP, and a one-cycle completion pulse.
- ACK failure stops additional byte transmission, executes the normal STOP sequence, and reports `ack_error`.

Verification:
- `tb_ov7670_sccb_master.sv` passed with Icarus Verilog using `-g2012`.
- Simulation covered ACK success and ACK failure with clean termination.
- VCD output is generated at `sim/run/tb_ov7670_sccb_master.vcd`.

Scope note:
- Camera register ROM, full OV7670 init sequencing, pixel capture, framebuffer writes, and top-level hardware integration remain out of scope.

Next task:
- `TASK-005-ov7670-init.md`

## Purpose
Implement a reusable **SCCB write master** for the OV7670 camera module.

This task is the first control-plane milestone for camera bring-up. It does **not** capture image pixels and does **not** initialize the full camera yet. Its purpose is only to prove that the FPGA can generate a correct SCCB transaction waveform and successfully write one register-value pair to the camera interface model.

This module will be used by the next task (`TASK-005-ov7670-init.md`) as the low-level transport layer for the camera register initialization sequence.

---

# 1. Goal

Create a synthesizable SCCB master module that can perform a **single register write transaction** of the form:

```text
START
device address + write bit
ACK
register address
ACK
register data
ACK
STOP
```

The design must:
- be synthesizable
- be simple and explicit
- expose a clean handshake interface to higher-level logic
- be verified with a focused simulation testbench

The output of this task is **not** “camera works.”  
The output of this task is:

> the FPGA-side SCCB transaction engine is correct and reusable.

---

# 2. Why this task exists

The OV7670 cannot be assumed to power up in exactly the format/resolution needed by the project. The course brief explicitly requires the camera to be configured via **SCCB** before proper capture.

This task isolates that requirement so it can be debugged independently from:
- frame capture
- RGB byte assembly
- BRAM writes
- VGA display
- clock-domain crossing with `PCLK`

That separation is critical. Do not combine SCCB debugging with pixel-path debugging.

---

# 3. Scope

## In scope
- low-level SCCB write engine
- start condition generation
- stop condition generation
- byte transmission
- ACK sampling
- transaction busy/done/error reporting
- simulation testbench for one or more register-write transactions

## Out of scope
- full camera initialization sequence
- camera register ROM
- power-up delay sequencing
- camera pixel capture
- framebuffer writes
- live VGA integration
- read transactions
- multi-master bus behavior
- general-purpose I2C support beyond what is needed for OV7670 SCCB writes

This task is intentionally narrow.

---

# 4. Deliverables

Required files:

```text
rtl/camera/ov7670_sccb_master.v
sim/tb/tb_ov7670_sccb_master.sv
docs/tasks/TASK-004-sccb-master.md
```

Optional helper file if useful:

```text
rtl/util/clock_enable_divider.v
```

but avoid introducing extra files unless they clearly improve clarity.

---

# 5. External interface

## Module name
`ov7670_sccb_master`

## Required top-level interface
Use a simple transaction-style interface.

### Inputs
- `clk`
- `rst`
- `start`
- `dev_addr[7:0]`
- `reg_addr[7:0]`
- `reg_data[7:0]`
- `siod_in`

### Outputs
- `busy`
- `done`
- `ack_error`
- `sioc`
- `siod_oe`
- `siod_out`

Recommended interpretation:
- `sioc` is the SCCB serial clock output
- `siod_out` is the data value driven by FPGA when output-enabled
- `siod_oe` controls whether FPGA actively drives the line
- `siod_in` is the observed external line state for ACK sampling

This split is preferred over using a Verilog `inout` internally because:
- it is easier to simulate
- it is easier to reason about
- it makes bus ownership explicit

Top-level integration can later convert this into an actual board-level bidirectional pin if needed.

---

# 6. Behavioral contract

## Idle state
When idle:
- `busy = 0`
- `done = 0`
- `ack_error = 0`
- `sioc = 1`
- `siod_oe = 0` or released-high behavior depending on implementation style

## Start request
A transaction begins when:
- `start` is asserted for one clock cycle while `busy == 0`

The module then:
- latches `dev_addr`, `reg_addr`, and `reg_data`
- asserts `busy`
- generates the SCCB waveform
- ends by pulsing `done`

## Completion
At the end of a successful transaction:
- `busy` returns to `0`
- `done` pulses high for one clock cycle
- `ack_error` remains `0`

## ACK failure
If any ACK phase fails:
- `ack_error` must be asserted
- transaction must still terminate cleanly with STOP
- `busy` must eventually return to `0`
- `done` should still pulse to indicate transaction completion, unless you explicitly define a separate failure completion policy

Choose one policy and keep it consistent. Recommended:
- `done` means “transaction finished”
- `ack_error` tells whether it failed

---

# 7. SCCB transaction format

For this task, implement **write-only register transactions**.

Use this byte order:

```text
START
dev_addr
ACK
reg_addr
ACK
reg_data
ACK
STOP
```

### Notes
- Use an **8-bit device address input** so higher-level logic can pass the exact write address byte explicitly.
- Do not make this task depend on knowledge of read/write bit construction in the caller unless clearly documented.
- Keep the engine agnostic: it transmits the bytes it is given.

This avoids ambiguity and keeps the master reusable.

---

# 8. Clocking strategy

The SCCB master runs in a normal internal FPGA logic clock domain, not in a camera pixel clock domain.

## For this task
Use:
- `clk = clk_100` or a similarly stable internal system clock

Generate a slower SCCB timing enable internally.

## Recommendation
Use a small divider/counter so SCCB bit transitions happen at a slow, simulation-friendly, hardware-friendly rate.

Do **not** optimize for maximum speed.

Priorities:
1. correctness
2. clarity
3. debuggability

---

# 9. Line-driving model

Use explicit output-enable control for `SIOD`.

## Recommended rule
- when sending bits: FPGA drives `SIOD`
- when waiting for ACK: FPGA releases `SIOD`, external side may pull it low
- `SIOC` is always actively driven by FPGA

This makes the ACK phase explicit.

Avoid hidden tri-state behavior inside the core logic.

---

# 10. State machine plan

Use a simple explicit FSM.

Recommended states:

```text
IDLE
START_A
START_B
SEND_DEV_BIT
DEV_ACK_A
DEV_ACK_B
SEND_REG_BIT
REG_ACK_A
REG_ACK_B
SEND_DATA_BIT
DATA_ACK_A
DATA_ACK_B
STOP_A
STOP_B
DONE
```

You may compress this if the implementation remains very readable, but do **not** turn it into a clever opaque bit-machine.

## State responsibilities

### `IDLE`
Wait for `start`.

### `START_*`
Generate SCCB start condition:
- data transitions low while clock is high

### `SEND_*`
Shift out the current byte MSB-first.

### `*_ACK_*`
Release `SIOD`, pulse/observe clock, sample ACK.

### `STOP_*`
Generate stop condition:
- data returns high while clock is high

### `DONE`
Pulse `done`, clear `busy`, return to idle

---

# 11. Bit-level timing expectations

You do **not** need cycle-accurate real-world SCCB timing for this task, but the waveform must be logically correct.

The simulation must clearly show:
- start
- 8 transmitted bits
- ACK phase
- next byte
- stop

The important logical rules are:
- data is stable while clock is high
- data changes only during the low phase except for start/stop conditions
- ACK is sampled when the bus is released by FPGA

Keep this simple and deterministic.

---

# 12. Coding requirements

## Required style
- synthesizable Verilog/SystemVerilog only
- explicit sequential logic
- explicit combinational next-state logic if used
- no inferred latches
- no giant nested ad hoc logic blob
- clear separation of:
  - timing divider
  - FSM state
  - current byte/bit index
  - line drive control

## Naming suggestions
Use names like:
- `state`
- `bit_idx`
- `shift_reg`
- `clk_div`
- `sccb_tick`
- `busy`
- `done`
- `ack_error`

Avoid vague names like:
- `tmp`
- `flag2`
- `x`
- `kk`

---

# 13. Testbench requirements

## Testbench name
`tb_ov7670_sccb_master.sv`

## Goal
Verify that the SCCB master emits the expected logical waveform and correctly handles ACK success and failure.

## Required checks

### Case 1 — successful transaction
Provide a fake SCCB target model that:
- observes `siod_oe`
- returns ACK low on each ACK phase
- allows the transaction to complete successfully

Verify:
- `busy` goes high after `start`
- `done` pulses after transaction completes
- `ack_error == 0`
- bytes are transmitted in the expected order
- line is released during ACK phases

### Case 2 — ACK failure
Provide a model that refuses at least one ACK.

Verify:
- transaction still terminates cleanly
- `busy` returns low
- `done` pulses
- `ack_error == 1`

## Waveform requirements
The testbench should make waveform inspection easy.

Recommended:
```verilog
initial begin
    $dumpfile("tb_ov7670_sccb_master.vcd");
    $dumpvars(0, tb_ov7670_sccb_master);
end
```

Useful signals to inspect:
- `clk`
- `start`
- `busy`
- `done`
- `ack_error`
- `sioc`
- `siod_out`
- `siod_oe`
- `siod_in`
- `state`
- current byte index / bit index

## Minimum pass criteria
Simulation must clearly prove:
- valid start and stop
- three bytes transmitted in order
- ACK sampled correctly
- success and failure cases both behave cleanly

---

# 14. Hardware acceptance for this task

Hardware testing is optional for TASK-004.

If attempted, keep it minimal.

Possible optional hardware behavior:
- use LEDs to indicate:
  - transaction started
  - transaction done
  - ACK error

But do **not** block task completion on real hardware yet.

Primary acceptance is **simulation correctness**.

---

# 15. Integration expectations for later tasks

This module will later be driven by `ov7670_init.v`.

That means:
- its interface must be easy to use from a higher-level FSM
- one transaction must be startable with one `start` pulse
- the caller must be able to wait on `busy/done`
- the caller must be able to detect `ack_error`

Do not bake camera-register sequencing into this module.

Keep it transport-only.

---

# 16. Non-goals and anti-patterns

Do **not** do any of the following in this task:

- do not implement full camera init here
- do not mix SCCB with pixel capture logic
- do not introduce framebuffer logic
- do not make this a generic feature-rich I2C core
- do not add read transactions “because maybe later”
- do not over-optimize timing
- do not hide handshake semantics
- do not use a monolithic unreadable always block

This task is meant to be boring and reliable.

---

# 17. Exit criteria

TASK-004 is complete only when all of the following are true:

1. `ov7670_sccb_master.v` exists and is synthesizable
2. one register-write transaction can be initiated with a clean `start` handshake
3. the transaction produces start, byte transfer, ACK phases, and stop in the right order
4. `busy`, `done`, and `ack_error` behave consistently
5. `tb_ov7670_sccb_master.sv` exists
6. simulation passes for:
   - ACK success
   - ACK failure
7. generated waveforms are understandable and useful for debug

---

# 18. Suggested implementation notes for Codex

If this task is implemented by Codex, the implementation should follow these rules:

- keep the module small and explicit
- prefer readability over cleverness
- use a simple tick/divider for SCCB pacing
- separate bus drive control from FSM state
- treat `done` as a one-cycle completion pulse
- treat `ack_error` as sticky for the current transaction until return to idle
- avoid introducing unrelated refactors outside this task

---

# 19. What success looks like

At the end of this task, the project should have this proven building block:

```text
Higher-level init FSM
    -> start/dev_addr/reg_addr/reg_data
    -> SCCB master
    -> SIOC / SIOD waveform
```

That is enough to move to TASK-005.

Nothing more is required here.
