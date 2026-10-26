class fifo_scoreboard;

    mailbox #(fifo_wr_obs) wr_obs_mbx;
    mailbox #(fifo_rd_obs) rd_obs_mbx;
    fifo_ref_model          refm;

    int unsigned accepted_write_count;
    int unsigned overflow_count;
    int unsigned compare_count;
    int unsigned mismatch_count;
    int unsigned accepted_read_count;
    int unsigned underflow_count;

    function new(
        mailbox #(fifo_wr_obs) wr_obs_mbx,
        mailbox #(fifo_rd_obs) rd_obs_mbx,
        fifo_ref_model refm
    );
        this.wr_obs_mbx = wr_obs_mbx;
        this.rd_obs_mbx = rd_obs_mbx;
        this.refm       = refm;

        accepted_write_count = 0;
        overflow_count       = 0;
        compare_count        = 0;
        mismatch_count       = 0;
        accepted_read_count  = 0;
        underflow_count      = 0;
    endfunction

    task run_wr();
        fifo_wr_obs obs;

        forever begin
            wr_obs_mbx.get(obs);

            if (obs.accepted)
                accepted_write_count++;

            if (obs.overflow_pulse)
                overflow_count++;
        end
    endtask

    task run_rd();
        fifo_rd_obs obs;
        bit pending_compare;
        bit [DATA_WIDTH-1:0] exp_data;

        pending_compare = 0;

        forever begin
            rd_obs_mbx.get(obs);

            if (obs.underflow_pulse)
                underflow_count++;

            if (pending_compare) begin
                accepted_read_count++;

                if (!refm.has_expected()) begin
                    mismatch_count++;
                    $error("[%0t] SCB: accepted read when ref queue empty. data=0x%08h",
                           $time, obs.data);
                end
                else begin
                    exp_data = refm.pop_expected();
                    compare_count++;

                    if (obs.data !== exp_data) begin
                        mismatch_count++;
                        $error("[%0t] SCB MISMATCH: exp=0x%08h act=0x%08h",
                               $time, exp_data, obs.data);
                    end
                    else begin
                        $display("[%0t] SCB MATCH: 0x%08h",
                                 $time, obs.data);
                    end
                end
            end

            pending_compare = obs.accepted;
        end
    endtask

    task run();
        fork
            run_wr();
            run_rd();
        join
    endtask

    function bit pass();
        return (mismatch_count == 0);
    endfunction

    function void report();
        $display("--------------------------------------------------");
        $display("SCOREBOARD REPORT");
        $display("  accepted_write_count = %0d", accepted_write_count);
        $display("  overflow_count       = %0d", overflow_count);
        $display("  compare_count        = %0d", compare_count);
        $display("  accepted_read_count  = %0d", accepted_read_count);
        $display("  underflow_count      = %0d", underflow_count);
        $display("  mismatch_count       = %0d", mismatch_count);
        $display("  unread_in_fifo       = %0d (written but not yet read back)",
                 refm.size());
        $display("--------------------------------------------------");
    endfunction

endclass
