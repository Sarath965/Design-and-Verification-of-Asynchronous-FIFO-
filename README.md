# Asynchronous FIFO --- SystemVerilog Design & Verification

A parameterized asynchronous FIFO with independent write and read clock
domains, verified using a class-based SystemVerilog testbench. The
verification strategy combines directed tests, constrained-random
traffic, embedded RTL assertions, a queue-based reference model, a
scoreboard, and functional coverage.

## Overview

The goal is to verify functional correctness across independent write
and read clock domains, including FIFO ordering, data integrity,
status-flag behavior, corner cases, and coverage closure.

## Design Features

  -----------------------------------------------------------------------------
  Parameter                  Description                                Example
  -------------------------- --------------------- ----------------------------
  `DATA_WIDTH`               Width of each data                            `32`
                             word                  

  `ADDRSIZE`                 Pointer/address                                `4`
                             width; depth is       
                             typically             
                             `2**ADDRSIZE`         

  `ALMOST_FULL_THRESHOLD`    Almost-full threshold                          `1`

  `ALMOST_EMPTY_THRESHOLD`   Almost-empty                                   `1`
                             threshold             
  -----------------------------------------------------------------------------

With `DATA_WIDTH = 32` and `ADDRSIZE = 4`, the typical FIFO depth is 16
entries.

### Write-side signals

-   `wr_clk`: write clock
-   `wr_rst_n`: active-low write reset
-   `wr_en`, `wr_data`: write request and input data
-   `full`, `almost_full`: write-side status
-   `overflow_pulse`: attempted write while full

### Read-side signals

-   `rd_clk`: read clock
-   `rd_rst_n`: active-low read reset
-   `rd_en`: read request
-   `rd_data`: output data
-   `empty`, `almost_empty`: read-side status
-   `underflow_pulse`: attempted read while empty

The design uses binary pointers for local memory addressing, Gray-coded
pointers for clock-domain crossing (CDC), and two-flop synchronizers to
transfer Gray-coded pointers between domains. Status flags are
registered and may lag their underlying combinational conditions by one
cycle. The memory read path is registered.

## Verification Architecture

``` text
                         TOP
                          |
                         TEST
                          |
                         ENV
             +------------+-------------+
             |                          |
       Write-side path             Read-side path
       Generator                   Generator
       Write Driver                Read Driver
       Write Interface             Read Interface
             |                          |
             +----------- DUT ----------+
             |                          |
       Write Monitor                Read Monitor
             +-----------+--------------+
                         |
                  Reference Model
                         |
                     Scoreboard
                         |
                 Functional Coverage
```

  -----------------------------------------------------------------------
  Component                           Responsibility
  ----------------------------------- -----------------------------------
  `top.sv`                            Instantiates DUT/interfaces,
                                      generates independent clocks,
                                      selects and starts a test

  `wr_if.sv`, `rd_if.sv`              Bundle write- and read-domain
                                      signals

  `fifo_base_test`                    Base test class and common setup

  Test classes                        Execute individual verification
                                      scenarios

  `fifo_env`                          Integrates generators, drivers,
                                      monitors, reference model,
                                      scoreboard, and coverage

  `fifo_generator`                    Creates stimulus

  `fifo_wr_driver`, `fifo_rd_driver`  Drive write and read requests

  `fifo_wr_monitor`,                  Observe interface activity
  `fifo_rd_monitor`                   

  `fifo_ref_model`                    Queue-based golden model of FIFO
                                      contents

  `fifo_scoreboard`                   Compares expected and actual read
                                      data and checks ordering

  `fifo_coverage`                     Samples flags, operations, clock
                                      ratios, and data categories
  -----------------------------------------------------------------------

## Verification Strategy

1.  **Directed testing:** establish basic functionality and simplify
    debug.
2.  **Assertion checking:** check pointer, CDC, reset, and
    error-handling rules.
3.  **Scoreboard checking:** compare DUT output against the queue-based
    reference model.
4.  **Functional coverage:** confirm important states, transitions, data
    categories, and operation combinations were exercised.
5.  **Constrained-random testing:** vary bursts, idle gaps, data
    patterns, enables, clock periods, and traffic combinations.
6.  **Stress testing:** run longer mixed-traffic sequences, including
    repeated near-full and near-empty operation.

## Directed Test Plan

  -----------------------------------------------------------------------
  Test name                           Purpose
  ----------------------------------- -----------------------------------
  `fifo_reset_sanity_test`            Check reset behavior and initial
                                      status

  `fifo_single_wr_rd_test`            Write one item and read it back

  `fifo_multi_wr_rd_test`             Write multiple items and verify
                                      ordering

  `fifo_fill_full_test`               Fill FIFO until full

  `fifo_drain_empty_test`             Drain FIFO until empty

  `fifo_overflow_test`                Attempt a write while full

  `fifo_underflow_test`               Attempt a read while empty

  `fifo_simul_rw_test`                Exercise simultaneous reads and
                                      writes

  `fifo_wrap_test`                    Exercise pointer rollover and
                                      memory wraparound

  `fifo_almost_flags_test`            Check almost-full/almost-empty
                                      thresholds

  `fifo_clk_ratio_wr_fast_test`       Exercise faster write clock

  `fifo_clk_ratio_rd_fast_test`       Exercise faster read clock

  `fifo_clk_ratio_equal_test`         Exercise equal write/read clock
                                      periods

  `fifo_full_recovery_test`           Fill to full, drain partially, then
                                      write again

  `fifo_empty_recovery_test`          Exercise empty reads, refill, and
                                      drain again

  `fifo_random_stress_test`           Run extended randomized mixed
                                      traffic
  -----------------------------------------------------------------------

### Constrained-random scenarios

Randomized stimulus varies: - Write and read burst lengths - Idle gaps
and data patterns - Write/read enable sequences - Clock periods and
ratios - Simultaneous read/write traffic - Repeated operation near full
and near empty

## Assertions

Assertions embedded in the RTL are intended to check these properties.

### Configuration and parameters

-   `ADDRSIZE >= 1`
-   `DATA_WIDTH >= 1`
-   Almost-full and almost-empty thresholds are in valid ranges

### Pointer behavior

-   Write pointer increments on every accepted write and remains
    unchanged when a write is not accepted.
-   Read pointer increments on every accepted read and remains unchanged
    when a read is not accepted.

### Gray-code and CDC

-   `wgray == bin2gray(wbin)`
-   `rgray == bin2gray(rbin)`
-   Gray-coded pointers change by at most one bit per increment.
-   Synchronized Gray pointers in the opposite domain also change by at
    most one bit.

### Error handling

-   `overflow_pulse` asserts on an attempted write while full.
-   `underflow_pulse` asserts on an attempted read while empty.
-   Blocked writes while full do not advance the write pointer.
-   Blocked reads while empty do not advance the read pointer.

### Reset and sanity

-   `full` is low after write-domain reset.
-   `empty` is high after read-domain reset.
-   Synchronized pointers contain no unknown (`X`) or high-impedance
    (`Z`) values after reset release.
-   `full` and `empty` are not asserted simultaneously.

### Registered status-flag timing

Because flags are registered, assertions account for the one-cycle delay
between the underlying condition and the registered flag. Checks cover
`full`, `almost_full`, `empty`, and `almost_empty` using the previous
cycle's relevant condition or occupancy calculation. Exact expressions
must match the RTL implementation and sampling clocks.

## Functional Coverage

### Coverpoints

  -----------------------------------------------------------------------
  Coverpoint                          Values/categories
  ----------------------------------- -----------------------------------
  `cp_full`                           `0`, `1`

  `cp_empty`                          `0`, `1`

  `cp_almost_full`                    `0`, `1`

  `cp_almost_empty`                   `0`, `1`

  `cp_overflow`                       `0`, `1`

  `cp_underflow`                      `0`, `1`

  `cp_op_kind`                        Write-only, read-only, simultaneous
                                      read/write, idle

  `cp_clk_ratio`                      Write clock faster, read clock
                                      faster, equal clocks

  `cp_wr_data`                        Zero, one, low/middle/high ranges,
                                      all ones, alternating patterns

  `cp_rd_data`                        Same data categories, sampled only
                                      on an accepted read
  -----------------------------------------------------------------------

### Data bins (32-bit examples)

-   `zero`: `32'h0000_0000`
-   `one`: `32'h0000_0001`
-   `low_range`: `32'h0000_0000`--`32'h0000_FFFF`
-   `mid_range`: `32'h0001_0000`--`32'h7FFF_FFFF`
-   `high_range`: `32'h8000_0000`--`32'hFFFF_FFFE`
-   `all_ones`: `32'hFFFF_FFFF`
-   `alt_a`: `32'hAAAA_AAAA`
-   `alt_5`: `32'h5555_5555`

Read-data coverage is sampled only when a read is accepted, for example
when `rd_en_s && !empty_s`.

### Cross coverage

-   `cross_overflow_full`: overflow event × full status
-   `cross_underflow_empty`: underflow event × empty status

## Running Tests

The top-level testbench selects a test using the `TESTNAME` plusarg. If
it is not provided, the default test is `fifo_random_stress_test`.

Example plusargs:

``` text
+TESTNAME=fifo_reset_sanity_test
+WR_HALF_PERIOD=5
+RD_HALF_PERIOD=7
```

Compile files in dependency order: interfaces, RTL, type/package files,
component package, test package, and top-level testbench. Use
`filelist.f` if it matches the repository structure.

Example file list:

``` text
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

The exact compile/run command depends on the simulator and project
scripts. Inspect simulation logs and waveforms after each run. The
screenshots show `$dumpfile("fifo_waveform.fsdb")` and
`$dumpvars(0, top)`; native FSDB dumping may instead require
simulator-specific tasks such as `$fsdbDumpfile` and `$fsdbDumpvars`.

## Expected Outcomes

A successful run should demonstrate: - Correct accepted read/write
behavior and FIFO ordering - No unexpected scoreboard data mismatches -
Correct full, empty, almost-full, and almost-empty flag behavior - No
incorrect pointer movement on blocked operations - Correct overflow and
underflow handling - Valid Gray-code and synchronization behavior -
Correct pointer wraparound and operation under different clock ratios -
Coverage of intended states, operations, data patterns, and cross
scenarios

