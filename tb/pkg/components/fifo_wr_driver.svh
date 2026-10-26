class fifo_wr_driver;
    virtual wr_if #(DATA_WIDTH) vif;
    mailbox #(fifo_wr_txn) wr_mbx;
    int unsigned sent_count;

    function new(virtual wr_if #(DATA_WIDTH) vif,
                 mailbox #(fifo_wr_txn) wr_mbx);
        this.vif = vif;
        this.wr_mbx = wr_mbx;
        sent_count = 0;
    endfunction

    task reset_signals();
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
    endtask

    task drive_one(fifo_wr_txn t);
        if (t.data_q.size() > 0 && t.honor_full) begin
            drive_burst_bp(t);
            return;
        end

        if (t.data_q.size() > 0) begin
            drive_burst(t);
            return;
        end

        repeat (t.delay_cycles) @(vif.drv_cb);

        repeat (t.burst_len) begin
            @(vif.drv_cb);
            vif.drv_cb.wr_en   <= 1'b1;
            vif.drv_cb.wr_data <= t.data;
            sent_count++;
        end

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
    endtask

    // Gap-free burst — no backpressure awareness.
    // wr_en is held high for exactly data_q.size() cycles;
    // any cycle where full=1 silently drops that word.
    task drive_burst(fifo_wr_txn t);
        repeat (t.delay_cycles) @(vif.drv_cb);

        foreach (t.data_q[i]) begin
            @(vif.drv_cb);
            vif.drv_cb.wr_en   <= 1'b1;
            vif.drv_cb.wr_data <= t.data_q[i];
            sent_count++;
        end

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
    endtask

    // Back-pressure-aware burst.
    // Holds each data word on the bus until the FIFO accepts it
    // (!full), then advances to the next word. Guarantees all
    // data_q.size() items are actually written — no silent data loss.
    // Used only when t.honor_full == 1 (currently only fifo_wrap_test).
    task drive_burst_bp(fifo_wr_txn t);
        int idx;
        idx = 0;

        repeat (t.delay_cycles) @(vif.drv_cb);

        while (idx < t.data_q.size()) begin
            @(vif.drv_cb);
            vif.drv_cb.wr_en   <= 1'b1;
            vif.drv_cb.wr_data <= t.data_q[idx];

            if (!vif.drv_cb.full) begin
                sent_count++;
                idx++;
            end
        end

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
    endtask

    task run();
        fifo_wr_txn t;
        reset_signals();

        forever begin
            wr_mbx.get(t);
            drive_one(t);
        end
    endtask
endclass
