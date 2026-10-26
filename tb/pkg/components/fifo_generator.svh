class fifo_generator;

    mailbox #(fifo_wr_txn) wr_mbx;
    mailbox #(fifo_rd_txn) rd_mbx;
    fifo_config cfg;

    function new(
        mailbox #(fifo_wr_txn) wr_mbx,
        mailbox #(fifo_rd_txn) rd_mbx,
        fifo_config cfg
    );
        this.wr_mbx = wr_mbx;
        this.rd_mbx = rd_mbx;
        this.cfg    = cfg;
    endfunction


    task generate_reset_sanity();
    endtask


    task generate_single_wr_rd();
        fifo_wr_txn w;
        fifo_rd_txn r;

        w = new();
        w.data = 32'hA5A5_1234;
        w.delay_cycles = 1;
        w.burst_len = 1;
        wr_mbx.put(w);

        r = new();
        r.delay_cycles = 4;
        r.burst_len = 1;
        rd_mbx.put(r);
    endtask


    task generate_multi_wr_rd();
        fifo_wr_txn w;
        fifo_rd_txn r;

        w = new();
        w.delay_cycles = 1;

        for (int i = 0; i < 8; i++) begin
            w.data_q.push_back(32'h1000_0000 + i);
        end

        wr_mbx.put(w);

        r = new();
        r.delay_cycles = 5;
        r.burst_len = 8;
        rd_mbx.put(r);
    endtask


    task generate_fill_full();
        fifo_wr_txn w;

        w = new();
        w.delay_cycles = 0;

        for (int i = 0; i < DEPTH; i++)
            w.data_q.push_back(32'h2000_0000 + i);

        wr_mbx.put(w);
    endtask


    task generate_drain_empty();
        fifo_wr_txn w;
        fifo_rd_txn r;

        w = new();
        w.delay_cycles = 0;

        for (int i = 0; i < DEPTH; i++)
            w.data_q.push_back(32'h3000_0000 + i);

        wr_mbx.put(w);

        r = new();
        r.delay_cycles = 12;
        r.burst_len = DEPTH + 1;
        rd_mbx.put(r);
    endtask


    task generate_overflow();
        fifo_wr_txn w;

        generate_fill_full();

        begin
            w = new();
            w.delay_cycles = 0;

            for (int i = 0; i < 4; i++)
                w.data_q.push_back(32'hDEAD_0000 + i);

            wr_mbx.put(w);
        end
    endtask


    task generate_underflow();
        fifo_rd_txn r;

        r = new();
        r.delay_cycles = 1;
        r.burst_len = 6;
        rd_mbx.put(r);
    endtask


    // Fill to full, drain half, write again, and drain fully.
    // Exercises backpressure release and write resumption after full.
    task generate_full_recovery();
        fifo_wr_txn w;
        fifo_rd_txn r;

        // Phase 1: fill completely so full asserts.
        w = new();
        w.delay_cycles = 0;

        for (int i = 0; i < DEPTH; i++)
            w.data_q.push_back(32'h8000_0000 + i);

        wr_mbx.put(w);

        // Phase 2: drain half to release backpressure.
        r = new();
        r.delay_cycles = 6;
        r.burst_len = DEPTH / 2;
        rd_mbx.put(r);

        // Phase 3: write again into the freed slots.
        // Full must have deasserted.
        w = new();
        w.delay_cycles = 4;

        for (int i = 0; i < DEPTH / 2; i++)
            w.data_q.push_back(32'h9000_0000 + i);

        wr_mbx.put(w);

        // Phase 4: drain everything left.
        r = new();
        r.delay_cycles = 8;
        r.burst_len = DEPTH;
        rd_mbx.put(r);
    endtask


    // Read while empty (underflow), then write and read back.
    // Exercises empty deassertion and normal operation resuming
    // after an underflow event.
    task generate_empty_recovery();
        fifo_wr_txn w;
        fifo_rd_txn r;

        // Phase 1: read an empty FIFO to force underflow.
        r = new();
        r.delay_cycles = 1;
        r.burst_len = 4;
        rd_mbx.put(r);

        // Phase 2: write a small batch after the underflow.
        w = new();
        w.delay_cycles = 6;

        for (int i = 0; i < DEPTH / 2; i++)
            w.data_q.push_back(32'hA000_0000 + i);

        wr_mbx.put(w);

        // Phase 3: read it all back to confirm recovery and data integrity.
        r = new();
        r.delay_cycles = 8;
        r.burst_len = DEPTH / 2;
        rd_mbx.put(r);
    endtask


    task generate_simul_rw();
        fifo_wr_txn w;
        fifo_rd_txn r;

        for (int i = 0; i < 8; i++) begin
            w = new();
            w.data = 32'h4000_0000 + i;
            w.delay_cycles = 0;
            w.burst_len = 1;
            wr_mbx.put(w);
        end

        for (int i = 0; i < 16; i++) begin
            w = new();
            w.data = 32'h4000_0100 + i;
            w.delay_cycles = 0;
            w.burst_len = 1;
            wr_mbx.put(w);

            r = new();

            // Delay only the first read so it starts after the pre-fill
            // data has crossed the W->R synchronizer (empty deasserted).
            // Without this, the reader races the writer from t=0 and the
            // first couple of reads hit an empty FIFO, causing startup
            // underflows and residual unread items.
            r.delay_cycles = (i == 0) ? 7 : 0;
            r.burst_len = 1;
            rd_mbx.put(r);
        }

        r = new();
        r.delay_cycles = 12;
        r.burst_len = 8;
        rd_mbx.put(r);
    endtask


    task generate_wrap();
        fifo_wr_txn w;
        fifo_rd_txn r;

        w = new();
        w.delay_cycles = 0;
        w.honor_full = 1; // Backpressure-aware: all 48 words must be accepted.

        for (int i = 0; i < (DEPTH * 3); i++)
            w.data_q.push_back(32'h5000_0000 + i);

        wr_mbx.put(w);

        r = new();
        r.delay_cycles = 21;
        r.burst_len = DEPTH * 3;
        rd_mbx.put(r);
    endtask


    task generate_almost_flags();
        fifo_wr_txn w;
        fifo_rd_txn r;

        w = new();
        w.delay_cycles = 0;

        for (int i = 0; i < DEPTH - 1; i++)
            w.data_q.push_back(32'h6000_0000 + i);

        wr_mbx.put(w);

        r = new();
        r.delay_cycles = 12;
        r.burst_len = DEPTH;
        rd_mbx.put(r);
    endtask


    task generate_clk_ratio();
        fifo_wr_txn w;
        fifo_rd_txn r;
        int unsigned rd_delay;

        w = new();
        w.delay_cycles = 0;

        for (int i = 0; i < 20; i++)
            w.data_q.push_back(32'h7000_0000 + i);

        wr_mbx.put(w);

        // Compute read-start delay so all 20 writes at wr_clk rate
        // complete and the W->R CDC has propagated before the first read.
        // Without this, a faster rd_clk can start reading before writes arrive.
        // Formula: 20 write cycles x wr_clk_period, converted to rd_clk units + margin.
        rd_delay = (20 * cfg.wr_clk_period) / cfg.rd_clk_period + 5;

        r = new();
        r.delay_cycles = rd_delay;
        r.burst_len = 20;
        rd_mbx.put(r);
    endtask


    task generate_random_stress();
        fifo_wr_txn w;
        fifo_rd_txn r;

        bit [31:0] patterns[$] = '{
            32'h0000_0000,
            32'h0000_0001,
            32'h0000_0002,
            32'h0000_00FF,
            32'h0000_FFFF,
            32'h0001_0000,
            32'h7FFF_FFFF,
            32'h8000_0000,
            32'hFFFF_FFFE,
            32'hFFFF_FFFF,
            32'hAAAA_AAAA,
            32'h5555_5555
        };

        foreach (patterns[i]) begin
            w = new();
            w.data = patterns[i];
            w.delay_cycles = 0;
            w.burst_len = 1;
            wr_mbx.put(w);
        end

        r = new();
        r.delay_cycles = 20;
        r.burst_len = patterns.size();
        rd_mbx.put(r);

        for (int i = 0; i < cfg.num_transactions; i++) begin

            if ($urandom_range(0, 1)) begin
                w = new();

                assert(w.randomize() with {
                    delay_cycles inside {[0:5]};
                    burst_len inside {[1:4]};
                });

                wr_mbx.put(w);
            end

            if ($urandom_range(0, 1)) begin
                r = new();

                assert(r.randomize() with {
                    delay_cycles inside {[0:5]};
                    burst_len inside {[1:4]};
                });

                rd_mbx.put(r);
            end

        end
    endtask


    task run();

        case (cfg.test_kind)

            TEST_RESET_SANITY:
                generate_reset_sanity();

            TEST_SINGLE_WR_RD:
                generate_single_wr_rd();

            TEST_MULTI_WR_RD:
                generate_multi_wr_rd();

            TEST_FILL_FULL:
                generate_fill_full();

            TEST_DRAIN_EMPTY:
                generate_drain_empty();

            TEST_OVERFLOW:
                generate_overflow();

            TEST_UNDERFLOW:
                generate_underflow();

            TEST_SIMUL_RW:
                generate_simul_rw();

            TEST_WRAP:
                generate_wrap();

            TEST_ALMOST_FLAGS:
                generate_almost_flags();

            TEST_CLK_RATIO:
                generate_clk_ratio();

            TEST_RANDOM_STRESS:
                generate_random_stress();

            TEST_FULL_RECOVERY:
                generate_full_recovery();

            TEST_EMPTY_RECOVERY:
                generate_empty_recovery();

            default:
                generate_reset_sanity();

        endcase

    endtask

endclass
