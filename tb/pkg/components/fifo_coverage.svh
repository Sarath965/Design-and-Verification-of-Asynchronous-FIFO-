class fifo_coverage;

    mailbox #(fifo_wr_obs) wr_cov_mbx;
    mailbox #(fifo_rd_obs) rd_cov_mbx;

    bit                  wr_en_s;
    bit                  full_s;
    bit                  almost_full_s;
    bit                  overflow_s;
    bit [DATA_WIDTH-1:0] wr_data_s;

    bit                  rd_en_s;
    bit                  empty_s;
    bit                  almost_empty_s;
    bit                  underflow_s;
    bit [DATA_WIDTH-1:0] rd_data_s;

    op_kind_e  op_kind_s;
    clk_ratio_e clk_ratio_s;

    covergroup fifo_cg;
        option.per_instance = 1;

        cp_full        : coverpoint full_s
                         { bins b0 = {0}; bins b1 = {1}; }

        cp_empty       : coverpoint empty_s
                         { bins b0 = {0}; bins b1 = {1}; }

        cp_almost_full : coverpoint almost_full_s
                         { bins b0 = {0}; bins b1 = {1}; }

        cp_almost_empty: coverpoint almost_empty_s
                         { bins b0 = {0}; bins b1 = {1}; }

        cp_overflow    : coverpoint overflow_s
                         { bins b0 = {0}; bins b1 = {1}; }

        cp_underflow   : coverpoint underflow_s
                         { bins b0 = {0}; bins b1 = {1}; }

        cp_op_kind : coverpoint op_kind_s {
            bins write_only = {OP_WRITE_ONLY};
            bins read_only  = {OP_READ_ONLY};
            bins simul_rw   = {OP_SIMUL_RW};
            bins idle       = {OP_IDLE};
        }

        cp_clk_ratio : coverpoint clk_ratio_s {
            bins wr_fast = {CLK_WR_FASTER};
            bins rd_fast = {CLK_RD_FASTER};
            bins equal   = {CLK_EQUAL};
        }

        cp_wr_data : coverpoint wr_data_s {
            bins zero       = {32'h0000_0000};
            bins one        = {32'h0000_0001};
            bins low_range  = {[32'h0000_0002:32'h0000_FFFF]};
            bins mid_range  = {[32'h0001_0000:32'h7FFF_FFFF]};
            bins high_range = {[32'h8000_0000:32'hFFFF_FFFE]};
            bins all_ones   = {32'hFFFF_FFFF};
            bins alt_a      = {32'hAAAA_AAAA};
            bins alt_5      = {32'h5555_5555};
        }

        cp_rd_data : coverpoint rd_data_s
                     iff (rd_en_s && !empty_s) {
            bins zero       = {32'h0000_0000};
            bins one        = {32'h0000_0001};
            bins low_range  = {[32'h0000_0002:32'h0000_FFFF]};
            bins mid_range  = {[32'h0001_0000:32'h7FFF_FFFF]};
            bins high_range = {[32'h8000_0000:32'hFFFF_FFFE]};
            bins all_ones   = {32'hFFFF_FFFF};
            bins alt_a      = {32'hAAAA_AAAA};
            bins alt_5      = {32'h5555_5555};
        }

        cross_overflow_full :
            cross cp_overflow, cp_full;

        cross_underflow_empty :
            cross cp_underflow, cp_empty {
                // Underflow can occur only while the FIFO is empty.
                // underflow=1 with empty=0 is impossible.
                ignore_bins impossible =
                    binsof(cp_underflow.b1) &&
                    binsof(cp_empty.b0);
            }

    endgroup


    function new(
        mailbox #(fifo_wr_obs) wr_cov_mbx,
        mailbox #(fifo_rd_obs) rd_cov_mbx
    );
        this.wr_cov_mbx = wr_cov_mbx;
        this.rd_cov_mbx = rd_cov_mbx;

        fifo_cg = new();
    endfunction


    function void set_clk_ratio(
        int unsigned wr_p,
        int unsigned rd_p
    );
        if (wr_p < rd_p)
            clk_ratio_s = CLK_WR_FASTER;
        else if (wr_p > rd_p)
            clk_ratio_s = CLK_RD_FASTER;
        else
            clk_ratio_s = CLK_EQUAL;
    endfunction


    function void sample_status(
        bit                  wr_en_i,
        bit                  full_i,
        bit                  almost_full_i,
        bit                  overflow_i,
        bit [DATA_WIDTH-1:0] wr_data_i,
        bit                  rd_en_i,
        bit                  empty_i,
        bit                  almost_empty_i,
        bit                  underflow_i,
        bit [DATA_WIDTH-1:0] rd_data_i
    );

        wr_en_s       = wr_en_i;
        full_s        = full_i;
        almost_full_s = almost_full_i;
        overflow_s    = overflow_i;
        wr_data_s     = wr_data_i;

        rd_en_s       = rd_en_i;
        empty_s       = empty_i;
        almost_empty_s = almost_empty_i;
        underflow_s   = underflow_i;
        rd_data_s     = rd_data_i;

        if (wr_en_i && !rd_en_i)
            op_kind_s = OP_WRITE_ONLY;
        else if (wr_en_i && rd_en_i)
            op_kind_s = OP_SIMUL_RW;
        else if (!wr_en_i && rd_en_i)
            op_kind_s = OP_READ_ONLY;
        else
            op_kind_s = OP_IDLE;

        fifo_cg.sample();

    endfunction


    task run_wr();
        fifo_wr_obs w;

        forever begin
            wr_cov_mbx.get(w);

            wr_en_s       = w.wr_en;
            full_s        = w.full;
            almost_full_s = w.almost_full;
            overflow_s    = w.overflow_pulse;
            wr_data_s     = w.data;

            if (w.wr_en && !rd_en_s)
                op_kind_s = OP_WRITE_ONLY;
            else if (w.wr_en && rd_en_s)
                op_kind_s = OP_SIMUL_RW;
            else if (!w.wr_en && rd_en_s)
                op_kind_s = OP_READ_ONLY;
            else
                op_kind_s = OP_IDLE;

            fifo_cg.sample();
        end
    endtask


    task run_rd();
        fifo_rd_obs r;

        forever begin
            rd_cov_mbx.get(r);

            rd_en_s        = r.rd_en;
            empty_s        = r.empty;
            almost_empty_s = r.almost_empty;
            underflow_s    = (r.rd_en && r.empty);
            rd_data_s      = r.data;

            if (wr_en_s && !r.rd_en)
                op_kind_s = OP_WRITE_ONLY;
            else if (wr_en_s && r.rd_en)
                op_kind_s = OP_SIMUL_RW;
            else if (!wr_en_s && r.rd_en)
                op_kind_s = OP_READ_ONLY;
            else
                op_kind_s = OP_IDLE;

            fifo_cg.sample();
        end
    endtask


    task run();
        fork
            run_wr();
            run_rd();
        join
    endtask


    function void report();
        $display("================================================");
        $display("FUNCTIONAL COVERAGE = %0.2f%%",
                 fifo_cg.get_inst_coverage());
        $display("================================================");
    endfunction

endclass
