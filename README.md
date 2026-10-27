# Asynchronous FIFO Design & Verification using SystemVerilog

<p align="center">
  <strong>RTL Design | Clock Domain Crossing (CDC) | Assertions | Functional Coverage | SystemVerilog Verification</strong>
</p>

---

## 📌 Project Overview

This project focuses on the **design and functional verification of a parameterized Asynchronous FIFO (First-In, First-Out)** using SystemVerilog.

An asynchronous FIFO enables reliable data transfer between two independent clock domains. It is commonly used in digital systems where data producers and consumers operate at different clock frequencies or with unrelated clock phases.

The FIFO is verified using a class-based SystemVerilog testbench that combines directed testing, constrained-random stimulus, embedded SystemVerilog Assertions (SVA), a queue-based reference model, a scoreboard, and functional coverage.

### 🎯 Verification Objectives

- Verify correct FIFO write and read functionality.
- Ensure FIFO ordering and end-to-end data integrity.
- Validate full, empty, almost-full, and almost-empty status flags.
- Verify correct handling of overflow and underflow conditions.
- Check binary-to-Gray pointer conversion and clock-domain synchronization.
- Exercise pointer wraparound and simultaneous read/write operations.
- Verify behavior under different write and read clock ratios.
- Achieve functional coverage of important states, transitions, and corner cases.

---

## ⚙️ Design Specifications

### Configuration Parameters

| Parameter | Description | Example Value |
|---|---|---:|
| `DATA_WIDTH` | Width of each FIFO data word | `32` |
| `ADDRSIZE` | Address pointer width | `4` |
| `ALMOST_FULL_THRESHOLD` | Programmable almost-full threshold | `1` |
| `ALMOST_EMPTY_THRESHOLD` | Programmable almost-empty threshold | `1` |

For the example configuration:

- **Data width:** 32 bits
- **Address size:** 4 bits
- **FIFO depth:** Typically \(2^4 = 16\) entries
- **Write clock:** Independent of the read clock
- **Read clock:** Independent of the write clock
- **Reset:** Active-low, with separate write- and read-domain reset signals

The exact FIFO depth and threshold interpretation depend on the RTL implementation.

### Interface Signals

| Signal | Direction / Domain | Description |
|---|---|---|
| `wr_clk` | Write domain | Write clock |
| `wr_rst_n` | Write domain | Active-low write reset |
| `wr_en` | Write domain | Write request |
| `wr_data` | Write domain | Input data |
| `full` | Write-side status | Indicates that the FIFO is full |
| `almost_full` | Write-side status | Indicates that the FIFO is approaching full |
| `overflow_pulse` | Write-side status | Indicates an attempted write while full |
| `rd_clk` | Read domain | Read clock |
| `rd_rst_n` | Read domain | Active-low read reset |
| `rd_en` | Read domain | Read request |
| `rd_data` | Read domain | Output data |
| `empty` | Read-side status | Indicates that the FIFO is empty |
| `almost_empty` | Read-side status | Indicates that the FIFO is approaching empty |
| `underflow_pulse` | Read-side status | Indicates an attempted read while empty |

### Internal Design Concepts

The asynchronous FIFO uses the following techniques:

1. **Binary pointers:** Used for local memory addressing and pointer arithmetic.
2. **Gray-coded pointers:** Used to reduce the risk of inconsistent multi-bit transitions during clock-domain crossing.
3. **Two-flop synchronizers:** Synchronize Gray-coded pointers into the opposite clock domain.
4. **Full and empty detection:** Determine whether writes and reads are permitted.
5. **Registered status flags:** Provide registered FIFO status outputs.
6. **Registered read data:** The read path uses a registered memory-read mechanism.

> **Important:** Because status flags are registered, their outputs can lag the underlying combinational conditions by one clock cycle. Verification must account for the implementation's precise timing and reset behavior.

---

## 🏗️ Verification Testbench Architecture

The testbench combines static SystemVerilog modules and interfaces with class-based verification components.

```text
                         +----------------------+
                         |         TOP          |
                         |  Clocks / Interfaces |
                         |    Test Selection    |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         |         TEST         |
                         | Directed / Random    |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         |         ENV          |
                         +----------+-----------+
                                    |
                 +------------------+------------------+
                 |                                     |
        +--------v---------+                 +---------v--------+
        |  WRITE CHANNEL   |                 |   READ CHANNEL   |
        +------------------+                 +------------------+
        | Write Generator  |                 | Read Generator  |
        | Write Driver     |                 | Read Driver     |
        | Write Monitor    |                 | Read Monitor    |
        +--------+---------+                 +---------+--------+
                 |                                     |
        +--------v---------+                 +---------v--------+
        |   Write Interface|                 |   Read Interface |
        +--------+---------+                 +---------+--------+
                 |                                     |
                 +------------------+------------------+
                                    |
                         +----------v-----------+
                         |          DUT         |
                         |    Asynchronous FIFO |
                         +----------------------+

             Monitored transactions and observed FIFO activity
                                    |
                         +----------v-----------+
                         |    Reference Model   |
                         |   Queue-Based Model  |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         |      Scoreboard      |
                         | Expected vs. Actual  |
                         +----------------------+

                         +----------------------+
                         |  Functional Coverage |
                         | States / Data / Ops  |
                         +----------------------+
```

### Verification Components

| Component | Responsibility |
|---|---|
| `top.sv` | Instantiates the DUT and interfaces, generates independent clocks, selects the test, and starts simulation |
| `wr_if.sv` | Encapsulates write-domain signals |
| `rd_if.sv` | Encapsulates read-domain signals |
| `fifo_base_test` | Provides the base test class and common test setup |
| `fifo_env` | Integrates the verification components |
| `fifo_generator` | Generates write/read stimulus |
| `fifo_wr_driver` | Drives write transactions |
| `fifo_rd_driver` | Drives read transactions |
| `fifo_wr_monitor` | Observes write-side activity |
| `fifo_rd_monitor` | Observes read-side activity |
| `fifo_ref_model` | Maintains the expected FIFO contents using a queue-based golden model |
| `fifo_scoreboard` | Compares actual read data against expected data and checks ordering |
| `fifo_coverage` | Collects functional coverage for states, operations, clock ratios, and data patterns |
| Transaction classes | Represent generated transactions and observed activity |

### Verification Flow

1. The selected test configures and starts the verification environment.
2. Generators create write and read stimulus.
3. Drivers apply stimulus through the corresponding interfaces.
4. Monitors observe the DUT's interface activity.
5. The reference model tracks the expected FIFO contents.
6. The scoreboard checks read data and FIFO ordering.
7. Assertions check design invariants and illegal-operation handling.
8. Functional coverage records which scenarios have been exercised.

---

## 🧪 Verification Strategy

The verification process follows a layered approach.

| Stage | Method | Purpose |
|---|---|---|
| 1 | Directed testing | Validate basic behavior with controlled stimulus |
| 2 | Assertion-based verification | Check pointer, reset, CDC, and error-handling properties |
| 3 | Reference model and scoreboard | Detect data corruption, ordering errors, and unexpected reads |
| 4 | Functional coverage | Measure scenario and corner-case coverage |
| 5 | Constrained-random testing | Explore different traffic patterns and operation sequences |
| 6 | Stress testing | Exercise prolonged mixed traffic and repeated boundary conditions |

### 1. Directed Testing

Directed tests target specific scenarios, making functional failures easier to reproduce and debug.

### 2. Assertion-Based Verification

Assertions embedded in the RTL are reused to check pointer movement, Gray-code correctness, reset behavior, and status-flag timing.

### 3. Scoreboard-Based Checking

A queue-based reference model maintains the expected sequence of FIFO data. The scoreboard compares expected values with actual DUT output and detects data mismatches or ordering violations.

### 4. Functional Coverage

Coverage monitors whether important FIFO states, operations, data categories, and error scenarios have occurred.

### 5. Constrained-Random Testing

Random stimulus varies burst lengths, idle intervals, data values, enables, and the relationship between the two clock periods.

### 6. Stress Testing

Long mixed-traffic sequences exercise repeated transitions between empty, partially occupied, almost-full, and full states.

---

## 📋 Directed Test Plan

The testbench supports the following 16 test scenarios.

| # | Test Name | Verification Objective |
|---:|---|---|
| 1 | `fifo_reset_sanity_test` | Verify initial state and reset behavior |
| 2 | `fifo_single_wr_rd_test` | Write one item and read it back |
| 3 | `fifo_multi_wr_rd_test` | Verify multiple writes, reads, and FIFO ordering |
| 4 | `fifo_fill_full_test` | Fill the FIFO until the full condition is reached |
| 5 | `fifo_drain_empty_test` | Read available entries until the FIFO becomes empty |
| 6 | `fifo_overflow_test` | Attempt a write while the FIFO is full |
| 7 | `fifo_underflow_test` | Attempt a read while the FIFO is empty |
| 8 | `fifo_simul_rw_test` | Exercise simultaneous read and write activity |
| 9 | `fifo_wrap_test` | Exercise pointer rollover and memory wraparound |
| 10 | `fifo_almost_flags_test` | Verify almost-full and almost-empty behavior |
| 11 | `fifo_clk_ratio_wr_fast_test` | Exercise a faster write clock |
| 12 | `fifo_clk_ratio_rd_fast_test` | Exercise a faster read clock |
| 13 | `fifo_clk_ratio_equal_test` | Exercise equal write and read clock periods |
| 14 | `fifo_random_stress_test` | Exercise randomized mixed traffic |
| 15 | `fifo_full_recovery_test` | Fill the FIFO, drain part of it, and verify subsequent writes |
| 16 | `fifo_empty_recovery_test` | Exercise empty reads, refill the FIFO, and drain again |

### Key Corner Cases

- Reset assertion and release
- First write after reset
- First read after data becomes available
- Last accepted write before full
- Last accepted read before empty
- Write attempts while full
- Read attempts while empty
- Simultaneous read and write near occupancy boundaries
- Pointer wraparound
- Almost-full and almost-empty threshold transitions
- Different asynchronous clock ratios
- Recovery from full and empty conditions

---

## 🎲 Constrained-Random Verification

After basic directed tests pass, constrained-random testing increases scenario diversity.

### Randomized Variables

- Write burst length
- Read burst length
- Idle gaps between operations
- Data values and data patterns
- Write-enable and read-enable sequences
- Write and read clock periods
- Simultaneous read/write activity
- Repeated near-full and near-empty operation

### Why Constrained-Random Testing?

Directed tests validate known scenarios, while constrained-random testing explores different combinations of legal and boundary operations.

For example, random traffic may expose an issue that occurs only when a write burst ends near the full threshold while the read clock is slower than the write clock.

Random testing should be combined with assertions, scoreboard checking, reproducible seeds, and coverage analysis.

---

## 🛡️ Assertion-Based Verification

The RTL contains assertions grouped into six major categories.

### Category 1: Configuration and Parameter Assertions

These checks verify that the FIFO is instantiated with meaningful parameter values.

- `ADDRSIZE >= 1`
- `DATA_WIDTH >= 1`
- `ALMOST_FULL_THRESHOLD` is within the valid range.
- `ALMOST_EMPTY_THRESHOLD` is within the valid range.

### Category 2: Functional Pointer Assertions

These checks verify correct binary pointer movement.

- The write pointer increments on every accepted write.
- The write pointer remains unchanged when a write is blocked.
- The read pointer increments on every accepted read.
- The read pointer remains unchanged when a read is blocked.

### Category 3: Gray-Code Correctness Assertions

These checks validate the pointer encoding used for CDC.

- `wgray == bin2gray(wbin)`
- `rgray == bin2gray(rbin)`
- A Gray-coded pointer changes by at most one bit per increment.
- Synchronized Gray pointers in the opposite clock domain also change by at most one bit per valid increment.

### Category 4: Error-Handling Assertions

These checks verify behavior during illegal access attempts.

- `overflow_pulse` asserts when a write is attempted while full.
- `underflow_pulse` asserts when a read is attempted while empty.
- The write pointer does not advance when a write is blocked because the FIFO is full.
- The read pointer does not advance when a read is blocked because the FIFO is empty.

### Category 5: Reset and Sanity Assertions

These checks verify post-reset initialization and flag consistency.

- `full == 0` after the write-domain reset.
- `empty == 1` after the read-domain reset.
- Synchronized pointers do not contain unknown (`X`) or high-impedance (`Z`) values after reset release.
- `full` and `empty` are not asserted simultaneously.

### Category 6: Status-Flag Timing Assertions

The status flags are registered, so the assertions account for the cycle delay between an underlying occupancy condition and the observed flag.

The documented checks include:

- `full` compared with the previous cycle's full condition, such as `$past(wfull_val)`.
- `almost_full` checked against the previous cycle's free-slot count and configured threshold.
- `empty` compared with the previous cycle's empty condition, such as `$past(rempty_val)`.
- `almost_empty` checked against the previous cycle's used-word count and configured threshold.

**Note:** The exact assertion expressions and sampling events must match the RTL implementation. Reset disable conditions and clock-domain boundaries must also be handled correctly.

---

## 📊 Functional Coverage Plan

Functional coverage is used to measure whether important FIFO behaviors have been exercised.

### Coverpoint Summary

| Coverpoint | Coverage Goal |
|---|---|
| `cp_full` | Observe full low and high |
| `cp_empty` | Observe empty low and high |
| `cp_almost_full` | Observe almost-full low and high |
| `cp_almost_empty` | Observe almost-empty low and high |
| `cp_overflow` | Observe overflow inactive and active |
| `cp_underflow` | Observe underflow inactive and active |
| `cp_op_kind` | Cover write-only, read-only, simultaneous read/write, and idle |
| `cp_clk_ratio` | Cover write-fast, read-fast, and equal-clock scenarios |
| `cp_wr_data` | Cover representative write-data categories |
| `cp_rd_data` | Cover representative read-data categories on accepted reads |

### Data-Pattern Coverage

For a 32-bit FIFO data path, the planned bins include:

| Bin | Example Value or Range | Purpose |
|---|---|---|
| `zero` | `32'h0000_0000` | All-zero data |
| `one` | `32'h0000_0001` | Single-bit least-significant value |
| `low_range` | `32'h0000_0000`–`32'h0000_FFFF` | Low-valued data |
| `mid_range` | `32'h0001_0000`–`32'h7FFF_FFFF` | Middle positive range |
| `high_range` | `32'h8000_0000`–`32'hFFFF_FFFE` | Values with the most-significant bit set, excluding all ones |
| `all_ones` | `32'hFFFF_FFFF` | All-one data |
| `alt_a` | `32'hAAAA_AAAA` | Alternating bit pattern |
| `alt_5` | `32'h5555_5555` | Complementary alternating bit pattern |

Read-data coverage is sampled only when a read is accepted, for example when `rd_en_s && !empty_s` is true.

### Cross Coverage

Two important crosses are planned.

| Cross | What It Checks |
|---|---|
| `cross_overflow_full` | Overflow event × full status |
| `cross_underflow_empty` | Underflow event × empty status |

These crosses help confirm that the error scenarios occur in the corresponding boundary states.

### Coverage Goals

The intended coverage goals include:

- All important status-flag values
- All four operation categories
- All three clock-ratio categories
- Representative data-pattern bins
- Overflow and underflow behavior
- Full and empty recovery
- Pointer wraparound
- Relevant cross-coverage combinations

Coverage closure should be confirmed from the actual simulator coverage report rather than assumed from the test list.

---

## 🗂️ Project Structure

The following file structure is based on the provided file list and component names.

```text
async_fifo_verif/
├── rtl/
│   └── async_fifo.sv
│
├── tb/
│   ├── interfaces/
│   │   ├── wr_if.sv
│   │   └── rd_if.sv
│   │
│   ├── pkg/
│   │   ├── fifo_tb_types_pkg.sv
│   │   ├── fifo_tb_components_pkg.sv
│   │   ├── fifo_tb_tests_pkg.sv
│   │   └── components/
│   │       ├── fifo_env.sv
│   │       ├── fifo_generator.sv
│   │       ├── fifo_wr_driver.sv
│   │       ├── fifo_rd_driver.sv
│   │       ├── fifo_wr_monitor.sv
│   │       ├── fifo_rd_monitor.sv
│   │       ├── fifo_ref_model.sv
│   │       ├── fifo_scoreboard.sv
│   │       └── fifo_coverage.sv
│   │
│   ├── top/
│   │   └── top.sv
│   │
│   └── run/
│       └── filelist.f
│
└── README.md
```

> The tree is illustrative. Adjust filenames and locations to match the actual repository, especially if some classes are grouped into shared source files.

---

## ▶️ Running the Tests

### Test Selection

The top-level testbench selects a scenario using the `TESTNAME` plusarg.

Example:

```text
+TESTNAME=fifo_reset_sanity_test
```

If no test name is supplied, the shown top-level code defaults to:

```text
fifo_random_stress_test
```

### Clock Configuration

The testbench supports plusargs for the write- and read-clock half-periods.

| Plusarg | Description | Example |
|---|---|---:|
| `WR_HALF_PERIOD` | Write-clock half-period | `5` |
| `RD_HALF_PERIOD` | Read-clock half-period | `7` |

Example runtime arguments:

```text
+TESTNAME=fifo_clk_ratio_wr_fast_test
+WR_HALF_PERIOD=5
+RD_HALF_PERIOD=7
```

These values are examples. Verify the intended clock ratios in the actual testbench before using them for a particular scenario.

### Source File List

The provided `filelist.f` contains:

```text
+incdir+./tb/interfaces
+incdir+./tb/pkg
+incdir+./tb/pkg/components

./tb/interfaces/wr_if.sv
./tb/interfaces/rd_if.sv
./rtl/async_fifo.sv
./tb/pkg/fifo_tb_types_pkg.sv
./tb/pkg/fifo_tb_components_pkg.sv
./tb/pkg/fifo_tb_tests_pkg.sv
./tb/top/top.sv
```

Compile the sources in dependency order, using the simulator's supported command-line syntax and the correct working directory.

### Simulation and Waveforms

After compilation:

1. Run the selected test.
2. Inspect compile and simulation logs.
3. Check assertion failures and scoreboard mismatches.
4. Review the waveform around any failure.
5. Inspect functional coverage reports.
6. Re-run failing tests with reproducible stimulus where supported.

The top-level screenshot shows `$dumpfile("fifo_waveform.fsdb")` and `$dumpvars(0, top)`. Confirm that these tasks are supported by your simulator. Some environments require simulator-specific FSDB tasks such as `$fsdbDumpfile` and `$fsdbDumpvars`.

---

## ✅ Expected Verification Results

A successful verification campaign should demonstrate:

- Correct behavior for accepted writes and reads.
- Preservation of FIFO ordering and data integrity.
- Correct full, empty, almost-full, and almost-empty behavior.
- No unintended pointer movement during blocked operations.
- Correct overflow and underflow handling.
- Correct Gray-code pointer behavior and synchronization.
- Correct operation through pointer wraparound.
- Correct behavior across write/read clock ratios.
- No unexpected scoreboard mismatches.
- All intended coverage scenarios exercised and documented.

**Verification status should be reported from actual simulation results.** A test being implemented or listed in the plan does not by itself prove that it passes.

---

## 🧠 Key Concepts Demonstrated

This project brings together several important digital design and verification concepts:

- Asynchronous FIFO architecture
- Clock-domain crossing (CDC)
- Binary and Gray-code pointer conversion
- Two-flop synchronization
- Registered status-flag timing
- SystemVerilog interfaces and packages
- Class-based testbench architecture
- Reference models and scoreboards
- SystemVerilog Assertions (SVA)
- Constrained-random verification
- Functional and cross coverage
- Directed and stress testing

---

## 📌 Conclusion

This project provides a structured approach to verifying an asynchronous FIFO using SystemVerilog. By combining directed scenarios, constrained-random traffic, assertions, reference-model checking, and functional coverage, the testbench is designed to detect functional errors, data-integrity issues, pointer-handling bugs, and corner-case failures across independent clock domains.

The resulting verification environment also serves as a practical example of reusable, modular verification techniques applicable to more complex RTL blocks.

---

*Built with SystemVerilog and digital design verification methodologies.*
