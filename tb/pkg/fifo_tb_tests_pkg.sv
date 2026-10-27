package fifo_tb_tests_pkg;

    import fifo_tb_types_pkg::*;
    import fifo_tb_components_pkg::*;

    class fifo_base_test;
        fifo_env env;
        fifo_config cfg;
        virtual wr_if #(DATA_WIDTH) wr_vif;
        virtual rd_if #(DATA_WIDTH) rd_vif;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            this.wr_vif = wr_vif;
            this.rd_vif = rd_vif;
            cfg = new();
        endfunction

        virtual function void configure();
            cfg.test_kind = TEST_RESET_SANITY;
            cfg.num_transactions = 100;
            cfg.wr_clk_period = 10;
            cfg.rd_clk_period = 14;
            cfg.enable_coverage = 1;
            cfg.post_gen_drain_cycles = 100;
        endfunction

        virtual task run();
            longint unsigned watchdog_ns;
            bit timed_out;

            configure();
            env = new(wr_vif, rd_vif, cfg);

            // Generous workload-scaled watchdog so a real DUT/TB hang fails with a
            // clear message instead of looking like an external timeout/kill.
            watchdog_ns = (cfg.num_transactions +
                          cfg.post_gen_drain_cycles + 1000) *
                          (cfg.wr_clk_period + cfg.rd_clk_period) * 10;
            timed_out = 0;

            fork : run_or_timeout
                begin
                    env.run();
                    env.wait_for_end();
                end
                begin
                    #(watchdog_ns);
                    timed_out = 1;
                end
            join_any
            disable run_or_timeout;

            if (timed_out)
                $fatal(1,
                    "WATCHDOG TIMEOUT (%0t time units): test did not complete (possible DUT/TB hang)",
                    watchdog_ns);

            env.report();

            if (!env.scb.pass())
                $fatal(1, "TEST FAILED");
            else
                $display("TEST PASSED");
        endtask
    endclass


    class fifo_reset_sanity_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_RESET_SANITY;
        endfunction

    endclass


    class fifo_single_wr_rd_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_SINGLE_WR_RD;
        endfunction

    endclass


    class fifo_multi_wr_rd_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_MULTI_WR_RD;
        endfunction

    endclass


    class fifo_fill_full_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_FILL_FULL;
            cfg.post_gen_drain_cycles = 60;
        endfunction

    endclass


    class fifo_drain_empty_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_DRAIN_EMPTY;
            cfg.post_gen_drain_cycles = 80;
        endfunction

    endclass


    class fifo_overflow_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_OVERFLOW;
            cfg.post_gen_drain_cycles = 60;
        endfunction

    endclass


    class fifo_underflow_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_UNDERFLOW;
            cfg.post_gen_drain_cycles = 40;
        endfunction

    endclass


    class fifo_simul_rw_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_SIMUL_RW;
            cfg.wr_clk_period = 10;
            cfg.rd_clk_period = 13;
            cfg.post_gen_drain_cycles = 100;
        endfunction

    endclass


    class fifo_wrap_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_WRAP;
            cfg.post_gen_drain_cycles = 150;
        endfunction

    endclass


    class fifo_almost_flags_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_ALMOST_FLAGS;
            cfg.post_gen_drain_cycles = 100;
        endfunction

    endclass


    class fifo_clk_ratio_wr_fast_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_CLK_RATIO;
            cfg.wr_clk_period = 8;
            cfg.rd_clk_period = 20;
            cfg.post_gen_drain_cycles = 160;
        endfunction

    endclass


    class fifo_clk_ratio_rd_fast_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_CLK_RATIO;
            cfg.wr_clk_period = 20;
            cfg.rd_clk_period = 8;
            cfg.post_gen_drain_cycles = 160;
        endfunction

    endclass


    class fifo_clk_ratio_equal_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_CLK_RATIO;
            cfg.wr_clk_period = 10;
            cfg.rd_clk_period = 10;
            cfg.post_gen_drain_cycles = 160;
        endfunction

    endclass


    class fifo_random_stress_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_RANDOM_STRESS;
            cfg.num_transactions = 1000;
            cfg.wr_clk_period = 9;
            cfg.rd_clk_period = 15;
            cfg.post_gen_drain_cycles = 200;
            cfg.drain_until_empty = 1;
        endfunction

    endclass


    class fifo_full_recovery_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_FULL_RECOVERY;
            cfg.post_gen_drain_cycles = 150;
        endfunction

    endclass


    class fifo_empty_recovery_test extends fifo_base_test;

        function new(
            virtual wr_if #(DATA_WIDTH) wr_vif,
            virtual rd_if #(DATA_WIDTH) rd_vif
        );
            super.new(wr_vif, rd_vif);
        endfunction

        virtual function void configure();
            super.configure();
            cfg.test_kind = TEST_EMPTY_RECOVERY;
            cfg.post_gen_drain_cycles = 120;
        endfunction

    endclass

endpackage
