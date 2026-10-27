package fifo_tb_types_pkg;

    parameter int DATA_WIDTH = 32;
    parameter int ADDRSIZE   = 4;
    parameter int DEPTH      = (1 << ADDRSIZE);

    typedef enum int {
        TEST_RESET_SANITY = 0,
        TEST_SINGLE_WR_RD,
        TEST_MULTI_WR_RD,
        TEST_FILL_FULL,
        TEST_DRAIN_EMPTY,
        TEST_OVERFLOW,
        TEST_UNDERFLOW,
        TEST_SIMUL_RW,
        TEST_WRAP,
        TEST_ALMOST_FLAGS,
        TEST_CLK_RATIO,
        TEST_RANDOM_STRESS,
        TEST_FULL_RECOVERY,
        TEST_EMPTY_RECOVERY
    } test_kind_e;

    typedef enum int {
        OP_IDLE = 0,
        OP_WRITE_ONLY,
        OP_READ_ONLY,
        OP_SIMUL_RW
    } op_kind_e;

    typedef enum int {
        CLK_WR_FASTER = 0,
        CLK_RD_FASTER,
        CLK_EQUAL
    } clk_ratio_e;

    class fifo_config;
        test_kind_e test_kind = TEST_RESET_SANITY;
        int unsigned num_transactions = 1000;
        int unsigned wr_clk_period = 10;
        int unsigned rd_clk_period = 14;
        int unsigned reset_cycles_wr = 4;
        int unsigned reset_cycles_rd = 4;
        int unsigned post_gen_drain_cycles = 100;
        bit enable_coverage = 1;

        // When 1, wait_for_end() first waits until the driver mailboxes are fully
        // consumed before the fixed tail drain. Needed for large queued workloads
        // (e.g. random stress) where the fixed drain window would otherwise end the
        // test long before all queued transactions are driven. Default 0 -> no
        // change for any other test.
        bit drain_until_empty = 0;
    endclass

    class fifo_wr_txn;
        rand bit [DATA_WIDTH-1:0] data;
        rand int unsigned delay_cycles;
        rand int unsigned burst_len;

        // Optional gap-free burst payload. When non-empty, the write driver streams
        // one distinct data word per clock cycle with wr_en held continuously high (no
        // inter-write deassert).
        // Empty by default so existing tests are unaffected.
        bit [DATA_WIDTH-1:0] data_q[$];

        // When 1, drive_burst_bp() is used: the driver holds each data word until
        // the FIFO accepts it (!full), throttling naturally against back-pressure.
        // Use only for wrap-pointer tests that need all data accepted.
        // Default 0 -> no change for any other test.
        bit honor_full = 0;

        constraint c_delay {
            delay_cycles inside {[0:10]};
        }

        constraint c_burst {
            burst_len inside {[1:8]};
        }

        function void display(string tag="WR_TXN");
            $display("[%0t] %s data=0x%08h delay=%0d burst=%0d",
                     $time, tag, data, delay_cycles, burst_len);
        endfunction
    endclass

    class fifo_rd_txn;
        rand int unsigned delay_cycles;
        rand int unsigned burst_len;

        constraint c_delay {
            delay_cycles inside {[0:10]};
        }

        constraint c_burst {
            burst_len inside {[1:8]};
        }

        function void display(string tag="RD_TXN");
            $display("[%0t] %s delay=%0d burst=%0d",
                     $time, tag, delay_cycles, burst_len);
        endfunction
    endclass

    class fifo_wr_obs;
        bit wr_en;
        bit accepted;
        bit [DATA_WIDTH-1:0] data;
        bit full;
        bit almost_full;
        bit overflow_pulse;
        longint unsigned sample_id;
    endclass

    class fifo_rd_obs;
        bit rd_en;
        bit accepted;
        bit [DATA_WIDTH-1:0] data;
        bit empty;
        bit almost_empty;
        bit underflow_pulse;
        longint unsigned sample_id;
    endclass

    class fifo_exp_item;
        bit [DATA_WIDTH-1:0] data;
    endclass

endpackage
