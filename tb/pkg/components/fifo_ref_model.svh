class fifo_ref_model;

    mailbox #(fifo_wr_obs) wr_obs_mbx;
    bit [DATA_WIDTH-1:0] exp_q[$];
    int unsigned accepted_write_count;

    function new(mailbox #(fifo_wr_obs) wr_obs_mbx);
        this.wr_obs_mbx = wr_obs_mbx;
        this.accepted_write_count = 0;
    endfunction

    task flush();
        exp_q.delete();
    endtask

    task run();
        fifo_wr_obs obs;

        forever begin
            wr_obs_mbx.get(obs);

            if (obs.accepted) begin
                exp_q.push_back(obs.data);
                accepted_write_count++;
            end
        end
    endtask

    function bit has_expected();
        return (exp_q.size() > 0);
    endfunction

    function bit [DATA_WIDTH-1:0] pop_expected();
        bit [DATA_WIDTH-1:0] d;

        if (exp_q.size() == 0) begin
            $error("[%0t] REF_MODEL: expected queue empty on pop", $time);
            return '0;
        end

        d = exp_q.pop_front();
        return d;
    endfunction

    function int unsigned size();
        return exp_q.size();
    endfunction

endclass
