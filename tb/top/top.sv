import fifo_tb_types_pkg::*;
import fifo_tb_components_pkg::*;
import fifo_tb_tests_pkg::*;

module top;

    parameter int DATA_WIDTH = 32;
    parameter int ADDRSIZE = 4;
    parameter int ALMOST_FULL_THRESHOLD = 1;
    parameter int ALMOST_EMPTY_THRESHOLD = 1;

    logic wr_clk;
    logic rd_clk;

    int unsigned wr_clk_half_period;
    int unsigned rd_clk_half_period;

    wr_if #(DATA_WIDTH) wr_vif(wr_clk);
    rd_if #(DATA_WIDTH) rd_vif(rd_clk);

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRSIZE(ADDRSIZE),
        .ALMOST_FULL_THRESHOLD(ALMOST_FULL_THRESHOLD),
        .ALMOST_EMPTY_THRESHOLD(ALMOST_EMPTY_THRESHOLD)
    ) dut (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_vif.wr_rst_n),
        .wr_en(wr_vif.wr_en),
        .wr_data(wr_vif.wr_data),

        .rd_clk(rd_clk),
        .rd_rst_n(rd_vif.rd_rst_n),
        .rd_en(rd_vif.rd_en),
        .rd_data(rd_vif.rd_data),

        .full(wr_vif.full),
        .empty(rd_vif.empty),
        .almost_full(wr_vif.almost_full),
        .almost_empty(rd_vif.almost_empty),
        .overflow_pulse(wr_vif.overflow_pulse),
        .underflow_pulse(rd_vif.underflow_pulse)
    );

    initial begin
        wr_clk = 0;
        rd_clk = 0;

        wr_clk_half_period = 5;
        rd_clk_half_period = 7;

        void'($value$plusargs("WR_HALF_PERIOD=%d",
                              wr_clk_half_period));
        void'($value$plusargs("RD_HALF_PERIOD=%d",
                              rd_clk_half_period));
    end

    always #(wr_clk_half_period) wr_clk = ~wr_clk;
    always #(rd_clk_half_period) rd_clk = ~rd_clk;

    fifo_base_test test_h;

    initial begin
        string testname;

        if (!$value$plusargs("TESTNAME=%s", testname))
            testname = "fifo_random_stress_test";

        $display("[%0t] Running TESTNAME=%s", $time, testname);

        case (testname)
            "fifo_reset_sanity_test":
                test_h = fifo_reset_sanity_test::new(wr_vif, rd_vif);

            "fifo_single_wr_rd_test":
                test_h = fifo_single_wr_rd_test::new(wr_vif, rd_vif);

            "fifo_multi_wr_rd_test":
                test_h = fifo_multi_wr_rd_test::new(wr_vif, rd_vif);

            "fifo_fill_full_test":
                test_h = fifo_fill_full_test::new(wr_vif, rd_vif);

            "fifo_drain_empty_test":
                test_h = fifo_drain_empty_test::new(wr_vif, rd_vif);

            "fifo_overflow_test":
                test_h = fifo_overflow_test::new(wr_vif, rd_vif);

            "fifo_underflow_test":
                test_h = fifo_underflow_test::new(wr_vif, rd_vif);

            "fifo_simul_rw_test":
                test_h = fifo_simul_rw_test::new(wr_vif, rd_vif);

            "fifo_wrap_test":
                test_h = fifo_wrap_test::new(wr_vif, rd_vif);

            "fifo_almost_flags_test":
                test_h = fifo_almost_flags_test::new(wr_vif, rd_vif);

            "fifo_clk_ratio_wr_fast_test":
                test_h = fifo_clk_ratio_wr_fast_test::new(wr_vif, rd_vif);

            "fifo_clk_ratio_rd_fast_test":
                test_h = fifo_clk_ratio_rd_fast_test::new(wr_vif, rd_vif);

            "fifo_clk_ratio_equal_test":
                test_h = fifo_clk_ratio_equal_test::new(wr_vif, rd_vif);

            "fifo_full_recovery_test":
                test_h = fifo_full_recovery_test::new(wr_vif, rd_vif);

            "fifo_empty_recovery_test":
                test_h = fifo_empty_recovery_test::new(wr_vif, rd_vif);

            "fifo_random_stress_test":
                test_h = fifo_random_stress_test::new(wr_vif, rd_vif);

            default:
                test_h = fifo_random_stress_test::new(wr_vif, rd_vif);
        endcase

        test_h.run();

        #50;
        $finish;
    end

    initial begin
        $dumpfile("fifo_waveform.fsdb");
        $dumpvars(0, top);
    end

endmodule
