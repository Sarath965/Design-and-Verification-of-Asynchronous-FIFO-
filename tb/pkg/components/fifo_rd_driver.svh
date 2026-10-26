class fifo_rd_driver;
    virtual rd_if #(DATA_WIDTH) vif;
    mailbox #(fifo_rd_txn) rd_mbx;
    int unsigned sent_count;

    function new(virtual rd_if #(DATA_WIDTH) vif,
                 mailbox #(fifo_rd_txn) rd_mbx);
        this.vif = vif;
        this.rd_mbx = rd_mbx;
        sent_count = 0;
    endfunction

    task reset_signals();
        vif.drv_cb.rd_en <= 1'b0;
    endtask

    task drive_one(fifo_rd_txn t);
        repeat (t.delay_cycles) @(vif.drv_cb);
        repeat (t.burst_len) begin
            @(vif.drv_cb);
            vif.drv_cb.rd_en <= 1'b1;
            sent_count++;
        end
        @(vif.drv_cb);
        vif.drv_cb.rd_en <= 1'b0;
    endtask

    task run();
        fifo_rd_txn t;
        reset_signals();
        forever begin
            rd_mbx.get(t);
            drive_one(t);
        end
    endtask
endclass
