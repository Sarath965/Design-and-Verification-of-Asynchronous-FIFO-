class fifo_rd_monitor;
    virtual rd_if #(DATA_WIDTH) vif;
    mailbox #(fifo_rd_obs) out_mbx[$];
    longint unsigned sample_id;

    function new(virtual rd_if #(DATA_WIDTH) vif);
        this.vif = vif;
        this.sample_id = 0;
    endfunction

    function void add_subscriber(mailbox #(fifo_rd_obs) mbx);
        out_mbx.push_back(mbx);
    endfunction

    task run();
        fifo_rd_obs obs;

        forever begin
            @(posedge vif.rd_clk);
            obs = new();
            obs.sample_id       = sample_id++;
            obs.rd_en           = vif.rd_en;
            obs.accepted        = (vif.rd_en && !vif.empty);
            obs.data             = vif.rd_data;
            obs.empty            = vif.empty;
            obs.almost_empty     = vif.almost_empty;
            obs.underflow_pulse  = vif.underflow_pulse;

            foreach (out_mbx[i])
                out_mbx[i].put(obs);
        end
    endtask
endclass
