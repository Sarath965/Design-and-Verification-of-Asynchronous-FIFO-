class fifo_env;

    virtual wr_if #(DATA_WIDTH) wr_vif;
    virtual rd_if #(DATA_WIDTH) rd_vif;
    fifo_config cfg;

    fifo_generator   gen;
    fifo_wr_driver   wr_drv;
    fifo_rd_driver   rd_drv;
    fifo_wr_monitor  wr_mon;
    fifo_rd_monitor  rd_mon;
    fifo_ref_model   refm;
    fifo_scoreboard  scb;
    fifo_coverage    cov;

    mailbox #(fifo_wr_txn) wr_drv_mbx;
    mailbox #(fifo_rd_txn) rd_drv_mbx;

    mailbox #(fifo_wr_obs) wr_ref_mbx;
    mailbox #(fifo_wr_obs) wr_scb_mbx;
    mailbox #(fifo_wr_obs) wr_cov_mbx;

    mailbox #(fifo_rd_obs) rd_scb_mbx;
    mailbox #(fifo_rd_obs) rd_cov_mbx;


    function new(
        virtual wr_if #(DATA_WIDTH) wr_vif,
        virtual rd_if #(DATA_WIDTH) rd_vif,
        fifo_config cfg
    );

        this.wr_vif = wr_vif;
        this.rd_vif = rd_vif;
        this.cfg    = cfg;

        wr_drv_mbx = new();
        rd_drv_mbx = new();

        wr_ref_mbx = new();
        wr_scb_mbx = new();
        wr_cov_mbx = new();

        rd_scb_mbx = new();
        rd_cov_mbx = new();

        gen    = new(wr_drv_mbx, rd_drv_mbx, cfg);
        wr_drv = new(wr_vif, wr_drv_mbx);
        rd_drv = new(rd_vif, rd_drv_mbx);

        wr_mon = new(wr_vif);
        rd_mon = new(rd_vif);

        wr_mon.add_subscriber(wr_ref_mbx);
        wr_mon.add_subscriber(wr_scb_mbx);
        wr_mon.add_subscriber(wr_cov_mbx);

        rd_mon.add_subscriber(rd_scb_mbx);
        rd_mon.add_subscriber(rd_cov_mbx);

        refm = new(wr_ref_mbx);
        scb  = new(wr_scb_mbx, rd_scb_mbx, refm);
        cov  = new(wr_cov_mbx, rd_cov_mbx);

        cov.set_clk_ratio(cfg.wr_clk_period, cfg.rd_clk_period);

    endfunction


    task reset_dut();

        wr_vif.wr_rst_n <= 1'b0;
        rd_vif.rd_rst_n <= 1'b0;

        wr_drv.reset_signals();
        rd_drv.reset_signals();

        repeat (cfg.reset_cycles_wr)
            @(posedge wr_vif.wr_clk);

        repeat (cfg.reset_cycles_rd)
            @(posedge rd_vif.rd_clk);

        if (cfg.enable_coverage) begin
            cov.sample_status(
                wr_vif.wr_en,
                wr_vif.full,
                wr_vif.almost_full,
                wr_vif.overflow_pulse,
                wr_vif.wr_data,
                rd_vif.rd_en,
                rd_vif.empty,
                rd_vif.almost_empty,
                rd_vif.underflow_pulse,
                rd_vif.rd_data
            );
        end

        wr_vif.wr_rst_n <= 1'b1;
        rd_vif.rd_rst_n <= 1'b1;

    endtask


    task run();

        fork
            wr_drv.run();
            rd_drv.run();
            wr_mon.run();
            rd_mon.run();
            refm.run();
            scb.run();

            if (cfg.enable_coverage) begin
                cov.run();
            end
        join_none

        reset_dut();
        gen.run();

    endtask


    task wait_for_end();

        // Stimulus is queued into unbounded mailboxes in zero simulation time,
        // so a fixed drain window truncates large workloads before they are fully driven.
        // When requested, first wait until both driver mailboxes are empty.

        if (cfg.drain_until_empty) begin
            while (wr_drv_mbx.num() > 0 ||
                   rd_drv_mbx.num() > 0)
                @(posedge rd_vif.rd_clk);
        end

        repeat (cfg.post_gen_drain_cycles)
            @(posedge rd_vif.rd_clk);

    endtask


    function void report();

        scb.report();

        if (cfg.enable_coverage)
            cov.report();

    endfunction

endclass
