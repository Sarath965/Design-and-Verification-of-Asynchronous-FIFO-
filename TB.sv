interface fifo_if #(
    parameter int DATA_WIDTH = 8
);

    logic wr_clk;
    logic rd_clk;

    logic wr_rst_n;
    logic rd_rst_n;

    logic [DATA_WIDTH-1:0] wr_data;
    logic                  wr_en;
    logic                  full;

    logic [DATA_WIDTH-1:0] rd_data;
    logic                  rd_en;
    logic                  empty;

endinterface



// ============================================================================
// TRANSACTION
// ============================================================================

class fifo_transaction #(
    parameter int DATA_WIDTH = 8
);

    rand bit                   wr_en;
    rand bit                   rd_en;
    rand logic [DATA_WIDTH-1:0] wr_data;

    bit full;
    bit empty;

    bit write_accepted;
    bit read_accepted;

    logic [DATA_WIDTH-1:0] rd_data;


    constraint c_enable {

        wr_en dist {
            1 := 5,
            0 := 5
        };

        rd_en dist {
            1 := 5,
            0 := 5
        };

    }


    function void print(string tag = "TRANSACTION");

        $display(
            "[%s] wr_en=%0b wr_data=%0h rd_en=%0b full=%0b empty=%0b",
            tag,
            wr_en,
            wr_data,
            rd_en,
            full,
            empty
        );

    endfunction

endclass



// ============================================================================
// GENERATOR
// ============================================================================

class fifo_generator #(
    parameter int DATA_WIDTH = 8
);

    mailbox #(fifo_transaction #(DATA_WIDTH)) gen2drv;

    int num_transactions;


    function new(
        mailbox #(fifo_transaction #(DATA_WIDTH)) gen2drv,
        int num_transactions = 100
    );

        this.gen2drv = gen2drv;
        this.num_transactions = num_transactions;

    endfunction


    task run();

        fifo_transaction #(DATA_WIDTH) tr;

        repeat (num_transactions) begin

            tr = new();

            if (!tr.randomize())
                $error("Generator randomization failed");

            gen2drv.put(tr);

        end

        gen2drv.put(null);

    endtask

endclass



// ============================================================================
// DRIVER
// ============================================================================

class fifo_driver #(
    parameter int DATA_WIDTH = 8
);

    virtual fifo_if #(DATA_WIDTH) vif;

    mailbox #(fifo_transaction #(DATA_WIDTH)) gen2drv;


    function new(
        virtual fifo_if #(DATA_WIDTH) vif,
        mailbox #(fifo_transaction #(DATA_WIDTH)) gen2drv
    );

        this.vif = vif;
        this.gen2drv = gen2drv;

    endfunction


    task run();

        fifo_transaction #(DATA_WIDTH) tr;

        vif.wr_en   = 0;
        vif.rd_en   = 0;
        vif.wr_data = '0;


        forever begin

            gen2drv.get(tr);

            if (tr == null)
                break;


            // Write side
            @(negedge vif.wr_clk);

            vif.wr_en   <= tr.wr_en;
            vif.wr_data <= tr.wr_data;


            // Read side
            @(negedge vif.rd_clk);

            vif.rd_en <= tr.rd_en;

        end


        vif.wr_en = 0;
        vif.rd_en = 0;

    endtask

endclass



// ============================================================================
// WRITE MONITOR
// ============================================================================

class fifo_write_monitor #(
    parameter int DATA_WIDTH = 8
);

    virtual fifo_if #(DATA_WIDTH) vif;

    mailbox #(fifo_transaction #(DATA_WIDTH)) wr_mon2sb;


    function new(
        virtual fifo_if #(DATA_WIDTH) vif,
        mailbox #(fifo_transaction #(DATA_WIDTH)) wr_mon2sb
    );

        this.vif = vif;
        this.wr_mon2sb = wr_mon2sb;

    endfunction


    task run();

        fifo_transaction #(DATA_WIDTH) tr;

        forever begin

            @(posedge vif.wr_clk);

            if (!vif.wr_rst_n)
                continue;


            if (vif.wr_en && !vif.full) begin

                tr = new();

                tr.wr_en          = 1;
                tr.wr_data        = vif.wr_data;
                tr.write_accepted = 1;

                wr_mon2sb.put(tr);

            end

        end

    endtask

endclass



// ============================================================================
// READ MONITOR
// ============================================================================

class fifo_read_monitor #(
    parameter int DATA_WIDTH = 8
);

    virtual fifo_if #(DATA_WIDTH) vif;

    mailbox #(fifo_transaction #(DATA_WIDTH)) rd_mon2sb;


    function new(
        virtual fifo_if #(DATA_WIDTH) vif,
        mailbox #(fifo_transaction #(DATA_WIDTH)) rd_mon2sb
    );

        this.vif = vif;
        this.rd_mon2sb = rd_mon2sb;

    endfunction


    task run();

        fifo_transaction #(DATA_WIDTH) tr;

        forever begin

            @(posedge vif.rd_clk);

            if (!vif.rd_rst_n)
                continue;


            if (vif.rd_en && !vif.empty) begin

                tr = new();

                tr.rd_en         = 1;
                tr.rd_data       = vif.rd_data;
                tr.read_accepted = 1;

                rd_mon2sb.put(tr);

            end

        end

    endtask

endclass



// ============================================================================
// SCOREBOARD
// ============================================================================

class fifo_scoreboard #(
    parameter int DATA_WIDTH = 8
);

    mailbox #(fifo_transaction #(DATA_WIDTH)) wr_mon2sb;
    mailbox #(fifo_transaction #(DATA_WIDTH)) rd_mon2sb;


    logic [DATA_WIDTH-1:0] reference_fifo[$];

    int write_count;
    int read_count;
    int error_count;


    function new(
        mailbox #(fifo_transaction #(DATA_WIDTH)) wr_mon2sb,
        mailbox #(fifo_transaction #(DATA_WIDTH)) rd_mon2sb
    );

        this.wr_mon2sb = wr_mon2sb;
        this.rd_mon2sb = rd_mon2sb;

        write_count = 0;
        read_count  = 0;
        error_count = 0;

    endfunction


    // ------------------------------------------------------------------------
    // Process writes
    // ------------------------------------------------------------------------

    task process_write();

        fifo_transaction #(DATA_WIDTH) tr;

        forever begin

            wr_mon2sb.get(tr);

            reference_fifo.push_back(tr.wr_data);

            write_count++;

            $display(
                "[SCOREBOARD] WRITE : data=%0h depth=%0d",
                tr.wr_data,
                reference_fifo.size()
            );

        end

    endtask


    // ------------------------------------------------------------------------
    // Process reads
    // ------------------------------------------------------------------------

    task process_read();

        fifo_transaction #(DATA_WIDTH) tr;

        logic [DATA_WIDTH-1:0] expected;


        forever begin

            rd_mon2sb.get(tr);


            if (reference_fifo.size() == 0) begin

                $error(
                    "[SCOREBOARD] ERROR: Read observed with empty reference FIFO"
                );

                error_count++;

            end
            else begin

                expected = reference_fifo.pop_front();

                read_count++;


                if (tr.rd_data !== expected) begin

                    $error(
                        "[SCOREBOARD] DATA MISMATCH: expected=%0h actual=%0h",
                        expected,
                        tr.rd_data
                    );

                    error_count++;

                end
                else begin

                    $display(
                        "[SCOREBOARD] READ PASS : expected=%0h actual=%0h",
                        expected,
                        tr.rd_data
                    );

                end

            end

        end

    endtask


    task run();

        fork

            process_write();
            process_read();

        join_none

    endtask


    function void report();

        $display("\n");
        $display("=================================================");
        $display("             SCOREBOARD REPORT");
        $display("=================================================");
        $display("Total writes              : %0d", write_count);
        $display("Total reads               : %0d", read_count);
        $display("Errors                    : %0d", error_count);
        $display("Reference FIFO remaining  : %0d",
                 reference_fifo.size());
        $display("=================================================");


        if (error_count == 0)
            $display("              TEST PASSED");
        else
            $display("              TEST FAILED");

        $display("=================================================\n");

    endfunction

endclass



// ============================================================================
// FUNCTIONAL COVERAGE
// ============================================================================

class fifo_coverage #(
    parameter int DATA_WIDTH = 8
);

    virtual fifo_if #(DATA_WIDTH) vif;


    covergroup write_cg @(posedge vif.wr_clk);

        cp_wr_en : coverpoint vif.wr_en {

            bins disabled = {0};
            bins enabled  = {1};

        }


        cp_full : coverpoint vif.full {

            bins not_full = {0};
            bins full     = {1};

        }


        wr_en_x_full : cross cp_wr_en, cp_full;

    endgroup



    covergroup read_cg @(posedge vif.rd_clk);

        cp_rd_en : coverpoint vif.rd_en {

            bins disabled = {0};
            bins enabled  = {1};

        }


        cp_empty : coverpoint vif.empty {

            bins not_empty = {0};
            bins empty     = {1};

        }


        rd_en_x_empty : cross cp_rd_en, cp_empty;

    endgroup


    function new(
        virtual fifo_if #(DATA_WIDTH) vif
    );

        this.vif = vif;

        write_cg = new();
        read_cg  = new();

    endfunction


    function void report();

        $display("\n");
        $display("=================================================");
        $display("             FUNCTIONAL COVERAGE");
        $display("=================================================");

        $display(
            "Write Coverage = %0.2f%%",
            write_cg.get_inst_coverage()
        );

        $display(
            "Read Coverage  = %0.2f%%",
            read_cg.get_inst_coverage()
        );

        $display("=================================================\n");

    endfunction

endclass



// ============================================================================
// ENVIRONMENT
// ============================================================================

class fifo_environment #(
    parameter int DATA_WIDTH = 8
);

    virtual fifo_if #(DATA_WIDTH) vif;


    mailbox #(fifo_transaction #(DATA_WIDTH)) gen2drv;
    mailbox #(fifo_transaction #(DATA_WIDTH)) wr_mon2sb;
    mailbox #(fifo_transaction #(DATA_WIDTH)) rd_mon2sb;


    fifo_generator #(DATA_WIDTH) generator;

    fifo_driver #(DATA_WIDTH) driver;

    fifo_write_monitor #(DATA_WIDTH) wr_monitor;

    fifo_read_monitor #(DATA_WIDTH) rd_monitor;

    fifo_scoreboard #(DATA_WIDTH) scoreboard;

    fifo_coverage #(DATA_WIDTH) coverage;


    function new(
        virtual fifo_if #(DATA_WIDTH) vif
    );

        this.vif = vif;


        gen2drv   = new();
        wr_mon2sb = new();
        rd_mon2sb = new();


        generator = new(
            gen2drv,
            1000
        );


        driver = new(
            vif,
            gen2drv
        );


        wr_monitor = new(
            vif,
            wr_mon2sb
        );


        rd_monitor = new(
            vif,
            rd_mon2sb
        );


        scoreboard = new(
            wr_mon2sb,
            rd_mon2sb
        );


        coverage = new(vif);

    endfunction


    task run();

        fork

            generator.run();

            driver.run();

            wr_monitor.run();

            rd_monitor.run();

            scoreboard.run();

        join_none

    endtask


    function void report();

        scoreboard.report();

        coverage.report();

    endfunction

endclass



// ============================================================================
// TOP-LEVEL TESTBENCH
// ============================================================================

module tb_top;

    parameter int DATA_WIDTH = 8;
    parameter int ADDR_WIDTH = 4;


    // ------------------------------------------------------------------------
    // Interface
    // ------------------------------------------------------------------------

    fifo_if #(DATA_WIDTH) vif();


    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (

        .wr_clk   (vif.wr_clk),
        .wr_rst_n (vif.wr_rst_n),
        .wr_data  (vif.wr_data),
        .wr_en    (vif.wr_en),
        .full     (vif.full),

        .rd_clk   (vif.rd_clk),
        .rd_rst_n (vif.rd_rst_n),
        .rd_data  (vif.rd_data),
        .rd_en    (vif.rd_en),
        .empty    (vif.empty)

    );


    // ------------------------------------------------------------------------
    // Environment
    // ------------------------------------------------------------------------

    fifo_environment #(
        .DATA_WIDTH(DATA_WIDTH)
    ) env;


    // ------------------------------------------------------------------------
    // WRITE CLOCK
    // 100 MHz
    // ------------------------------------------------------------------------

    initial begin

        vif.wr_clk = 0;

        forever #5 vif.wr_clk = ~vif.wr_clk;

    end


    // ------------------------------------------------------------------------
    // READ CLOCK
    // ~71 MHz
    // ------------------------------------------------------------------------

    initial begin

        vif.rd_clk = 0;

        forever #7 vif.rd_clk = ~vif.rd_clk;

    end


    // ------------------------------------------------------------------------
    // RESET
    // ------------------------------------------------------------------------

    initial begin

        vif.wr_rst_n = 0;
        vif.rd_rst_n = 0;

        vif.wr_en   = 0;
        vif.rd_en   = 0;
        vif.wr_data = '0;


        #30;


        vif.wr_rst_n = 1;
        vif.rd_rst_n = 1;

    end


    // ------------------------------------------------------------------------
    // TEST
    // ------------------------------------------------------------------------

    initial begin

        env = new(vif);


        wait(vif.wr_rst_n && vif.rd_rst_n);


        #20;


        $display("\n");
        $display("=================================================");
        $display("       ASYNCHRONOUS FIFO VERIFICATION");
        $display("=================================================");
        $display("DATA_WIDTH = %0d", DATA_WIDTH);
        $display("ADDR_WIDTH = %0d", ADDR_WIDTH);
        $display("DEPTH      = %0d", 1 << ADDR_WIDTH);
        $display("=================================================\n");


        env.run();


        // Allow sufficient time for transactions to complete.
        #20000;


        env.report();


        $display("\nSimulation completed.\n");

        $finish;

    end


    // ------------------------------------------------------------------------
    // FSDB waveform dump
    // ------------------------------------------------------------------------

    initial begin

        $fsdbDumpfile("async_fifo.fsdb");

        $fsdbDumpvars(0, tb_top);

    end

endmodule
