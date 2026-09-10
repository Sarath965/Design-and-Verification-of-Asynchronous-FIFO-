module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
)(
    // Write clock domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  wr_en,
    output logic                  full,

    // Read clock domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    output logic [DATA_WIDTH-1:0] rd_data,
    input  logic                  rd_en,
    output logic                  empty
);

    localparam int DEPTH = 1 << ADDR_WIDTH;

    // ------------------------------------------------------------
    // Memory
    // ------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ------------------------------------------------------------
    // Binary and Gray-coded pointers
    // Extra MSB is used for full/empty detection
    // ------------------------------------------------------------
    logic [ADDR_WIDTH:0] wr_ptr_bin;
    logic [ADDR_WIDTH:0] wr_ptr_gray;

    logic [ADDR_WIDTH:0] rd_ptr_bin;
    logic [ADDR_WIDTH:0] rd_ptr_gray;

    // ------------------------------------------------------------
    // Synchronized pointers
    // Write domain receives synchronized read pointer
    // Read domain receives synchronized write pointer
    // ------------------------------------------------------------
    logic [ADDR_WIDTH:0] rd_ptr_gray_sync1;
    logic [ADDR_WIDTH:0] rd_ptr_gray_sync2;

    logic [ADDR_WIDTH:0] wr_ptr_gray_sync1;
    logic [ADDR_WIDTH:0] wr_ptr_gray_sync2;

    // ------------------------------------------------------------
    // Next-state signals
    // ------------------------------------------------------------
    logic [ADDR_WIDTH:0] wr_ptr_bin_next;
    logic [ADDR_WIDTH:0] wr_ptr_gray_next;

    logic [ADDR_WIDTH:0] rd_ptr_bin_next;
    logic [ADDR_WIDTH:0] rd_ptr_gray_next;

    logic full_next;
    logic empty_next;

    // ------------------------------------------------------------
    // Write pointer next-state logic
    // ------------------------------------------------------------
    always_comb begin

        if (wr_en && !full)
            wr_ptr_bin_next = wr_ptr_bin + 1'b1;
        else
            wr_ptr_bin_next = wr_ptr_bin;

        wr_ptr_gray_next =
            (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

    end

    // ------------------------------------------------------------
    // Read pointer next-state logic
    // ------------------------------------------------------------
    always_comb begin

        if (rd_en && !empty)
            rd_ptr_bin_next = rd_ptr_bin + 1'b1;
        else
            rd_ptr_bin_next = rd_ptr_bin;

        rd_ptr_gray_next =
            (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;

    end

    // ------------------------------------------------------------
    // Full detection
    //
    // FIFO is full when the next write Gray pointer equals
    // the synchronized read pointer with the two MSBs inverted.
    // ------------------------------------------------------------
    always_comb begin

        full_next =
            (wr_ptr_gray_next ==
             {
                ~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                 rd_ptr_gray_sync2[ADDR_WIDTH-2:0]
             });

    end

    // ------------------------------------------------------------
    // Empty detection
    //
    // FIFO is empty when next read pointer equals synchronized
    // write pointer.
    // ------------------------------------------------------------
    always_comb begin

        empty_next =
            (rd_ptr_gray_next == wr_ptr_gray_sync2);

    end

    // ------------------------------------------------------------
    // Write pointer register and memory write
    // ------------------------------------------------------------
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end
        else begin

            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;

            if (wr_en && !full)
                mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;

        end

    end

    // ------------------------------------------------------------
    // Full flag register
    // ------------------------------------------------------------
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n)
            full <= 1'b0;
        else
            full <= full_next;

    end

    // ------------------------------------------------------------
    // Read pointer register and memory read
    // ------------------------------------------------------------
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
            rd_data     <= '0;
        end
        else begin

            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;

            if (rd_en && !empty)
                rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

        end

    end

    // ------------------------------------------------------------
    // Empty flag register
    // ------------------------------------------------------------
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n)
            empty <= 1'b1;
        else
            empty <= empty_next;

    end

    // ------------------------------------------------------------
    // Synchronize read pointer into write clock domain
    // ------------------------------------------------------------
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= '0;
            rd_ptr_gray_sync2 <= '0;
        end
        else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end

    end

    // ------------------------------------------------------------
    // Synchronize write pointer into read clock domain
    // ------------------------------------------------------------
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= '0;
            wr_ptr_gray_sync2 <= '0;
        end
        else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end

    end

    // ============================================================
    // SystemVerilog Assertions
    // ============================================================

    // Never write when FIFO is full
    property p_no_write_when_full;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        full |-> !(wr_en);
    endproperty

    assert property (p_no_write_when_full)
        else $error("Write attempted while FIFO is FULL");

    // Never read when FIFO is empty
    property p_no_read_when_empty;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        empty |-> !(rd_en);
    endproperty

    assert property (p_no_read_when_empty)
        else $error("Read attempted while FIFO is EMPTY");

    // Write pointer should not change without a valid write
    property p_wr_ptr_stable;
        @(posedge wr_clk)
        disable iff (!wr_rst_n)
        (!wr_en || full) |=> (wr_ptr_bin == $past(wr_ptr_bin));
    endproperty

    assert property (p_wr_ptr_stable)
        else $error("Write pointer changed without a valid write");

    // Read pointer should not change without a valid read
    property p_rd_ptr_stable;
        @(posedge rd_clk)
        disable iff (!rd_rst_n)
        (!rd_en || empty) |=> (rd_ptr_bin == $past(rd_ptr_bin));
    endproperty

    assert property (p_rd_ptr_stable)
        else $error("Read pointer changed without a valid read");

endmodule
