class fifo_wr_monitor;
    virtual wr_if #(DATA_WIDTH) vif;
    mailbox #(fifo_wr_obs) out_mbx[$];
    longint unsigned sample_id;

    function new(virtual wr_if #(DATA_WIDTH) vif);
        this.vif = vif;
        this.sample_id = 0;
    endfunction

    function void add_subscriber(mailbox #(fifo_wr_obs) mbx);
        out_mbx.push_back(mbx);
    endfunction

    task run();
        fifo_wr_obs obs;

        forever begin
            @(posedge vif.wr_clk);
            obs = new();
            obs.sample_id    = sample_id++;
            obs.wr_en        = vif.wr_en;
            obs.data         = vif.wr_data;
            obs.full         = vif.full;
            obs.almost_full  = vif.almost_full;
            obs.overflow_pulse = vif.overflow_pulse;
            obs.accepted     = (vif.wr_en && !vif.full);

            foreach (out_mbx[i])
                out_mbx[i].put(obs);
        end
    endtask
endclass
