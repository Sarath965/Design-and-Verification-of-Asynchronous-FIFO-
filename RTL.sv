`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Two-flop synchronizer for crossing a Gray-coded pointer between clock domains
// -----------------------------------------------------------------------------
module async_fifo_sync #(
    parameter int PTR_W = 5
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [PTR_W-1:0] d_in,
    output logic [PTR_W-1:0] d_out
);

    (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] sync_ff1, sync_ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= '0;
            sync_ff2 <= '0;
        end else begin
            sync_ff1 <= d_in;
            sync_ff2 <= sync_ff1;
        end
    end

    assign d_out = sync_ff2;

endmodule


// -----------------------------------------------------------------------------
// Write pointer, Gray-code generation, full/almost-full and overflow detection
// -----------------------------------------------------------------------------
module async_fifo_wptr_full #(
    parameter int ADDRSIZE = 4,
    parameter int ALMOST_FULL_THRESHOLD = 1
) (
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [ADDRSIZE:0]     rq2_wgray,
    output logic [ADDRSIZE:0]     wbin,
    output logic [ADDRSIZE:0]     wgray,
    output logic                  full,
    output logic                  almost_full,
    output logic                  overflow_pulse
);

    localparam int PTR_W = ADDRSIZE + 1;
    localparam int DEPTH = (1 << ADDRSIZE);
    localparam logic [PTR_W-1:0] FULL_MASK =
        ({{(PTR_W-2){1'b0}}, 2'b11} << (PTR_W-2));

    logic [PTR_W-1:0] wbinnext, wgraynext, wq2_rbin;
    logic [PTR_W-1:0] used_words_wr, free_slots_wr;
    logic             winc, wfull_val;

    function automatic logic [PTR_W-1:0] bin2gray(
        input logic [PTR_W-1:0] bin
    );
        bin2gray = (bin >> 1) ^ bin;
    endfunction

    function automatic logic [PTR_W-1:0] gray2bin(
        input logic [PTR_W-1:0] gray
    );
        logic [PTR_W-1:0] bin;
        int i;
        begin
            bin[PTR_W-1] = gray[PTR_W-1];
            for (i = PTR_W-2; i >= 0; i--)
                bin[i] = bin[i+1] ^ gray[i];
            gray2bin = bin;
        end
    endfunction

    function automatic logic [PTR_W-1:0] inc_ptr(
        input logic [PTR_W-1:0] ptr
    );
        inc_ptr = ptr + {{(PTR_W-1){1'b0}}, 1'b1};
    endfunction

    assign winc       = wr_en && !full;
    assign wbinnext   = wbin + winc;
    assign wgraynext  = bin2gray(wbinnext);
    assign wq2_rbin   = gray2bin(rq2_wgray);
    assign used_words_wr = wbinnext - wq2_rbin;
    assign free_slots_wr = DEPTH - used_words_wr;

    // Full is asserted when the next write pointer is one complete FIFO
    // traversal ahead of the synchronized read pointer.
    assign wfull_val = (wgraynext == (rq2_wgray ^ FULL_MASK));

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wbin          <= '0;
            wgray         <= '0;
            full          <= 1'b0;
            almost_full   <= 1'b0;
            overflow_pulse <= 1'b0;
        end else begin
            wbin           <= wbinnext;
            wgray          <= wgraynext;
            full           <= wfull_val;
            almost_full    <= (free_slots_wr <= ALMOST_FULL_THRESHOLD);
            overflow_pulse <= wr_en && full;
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (ADDRSIZE >= 1)
            else $error("async_fifo_wptr_full: ADDRSIZE must be >= 1");
        assert (ALMOST_FULL_THRESHOLD >= 0 &&
                ALMOST_FULL_THRESHOLD <= DEPTH)
            else $error("async_fifo_wptr_full: ALMOST_FULL_THRESHOLD out of range");
    end

    property p_wbin_increments_on_accept;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $past(wr_en && !full) |-> (wbin == $past(wbin) + 1'b1);
    endproperty
    assert property (p_wbin_increments_on_accept)
        else $error("Write pointer failed to increment on accepted write");

    property p_wbin_holds_without_accept;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $past(!(wr_en && !full)) |-> (wbin == $past(wbin));
    endproperty
    assert property (p_wbin_holds_without_accept)
        else $error("Write pointer changed without accepted write");

    property p_wgray_onebit_change;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $onehot0(wgray ^ $past(wgray));
    endproperty
    assert property (p_wgray_onebit_change)
        else $error("Write Gray pointer changed by more than one bit");

    property p_wgray_matches_bin2gray;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        wgray == bin2gray(wbin);
    endproperty
    assert property (p_wgray_matches_bin2gray)
        else $error("Write Gray pointer is inconsistent with wbin");

    property p_full_implies_no_accept;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $past(full && wr_en) |-> (wbin == $past(wbin));
    endproperty
    assert property (p_full_implies_no_accept)
        else $error("Write pointer advanced while full");

    property p_overflow_pulse_definition;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        overflow_pulse == $past(wr_en && full);
    endproperty
    assert property (p_overflow_pulse_definition)
        else $error("overflow_pulse definition mismatch");

    property p_full_raised_at_correct_time;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        full == $past(wfull_val);
    endproperty
    assert property (p_full_raised_at_correct_time)
        else $error("full flag timing mismatch");
`endif

endmodule


// -----------------------------------------------------------------------------
// Read pointer, Gray-code generation, empty/almost-empty and underflow detection
// -----------------------------------------------------------------------------
module async_fifo_rptr_empty #(
    parameter int ADDRSIZE = 4,
    parameter int ALMOST_EMPTY_THRESHOLD = 1
) (
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    input  logic [ADDRSIZE:0]     wq2_rgray,
    output logic [ADDRSIZE:0]     rbin,
    output logic [ADDRSIZE:0]     rgray,
    output logic                  empty,
    output logic                  almost_empty,
    output logic                  underflow_pulse
);

    localparam int PTR_W = ADDRSIZE + 1;
    localparam int DEPTH = (1 << ADDRSIZE);

    logic [PTR_W-1:0] rbinnext, rgraynext, rq2_wbin;
    logic [PTR_W-1:0] used_words_rd;
    logic             rinc, rempty_val;

    function automatic logic [PTR_W-1:0] bin2gray(
        input logic [PTR_W-1:0] bin
    );
        bin2gray = (bin >> 1) ^ bin;
    endfunction

    function automatic logic [PTR_W-1:0] gray2bin(
        input logic [PTR_W-1:0] gray
    );
        logic [PTR_W-1:0] bin;
        int i;
        begin
            bin[PTR_W-1] = gray[PTR_W-1];
            for (i = PTR_W-2; i >= 0; i--)
                bin[i] = bin[i+1] ^ gray[i];
            gray2bin = bin;
        end
    endfunction

    assign rinc         = rd_en && !empty;
    assign rbinnext     = rbin + rinc;
    assign rgraynext    = bin2gray(rbinnext);
    assign rq2_wbin     = gray2bin(wq2_rgray);
    assign used_words_rd = rq2_wbin - rbinnext;
    assign rempty_val   = (rgraynext == wq2_rgray);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rbin           <= '0;
            rgray          <= '0;
            empty          <= 1'b1;
            almost_empty   <= 1'b1;
            underflow_pulse <= 1'b0;
        end else begin
            rbin            <= rbinnext;
            rgray           <= rgraynext;
            empty           <= rempty_val;
            almost_empty    <= (used_words_rd <= ALMOST_EMPTY_THRESHOLD);
            underflow_pulse <= rd_en && empty;
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (ADDRSIZE >= 1)
            else $error("async_fifo_rptr_empty: ADDRSIZE must be >= 1");
        assert (ALMOST_EMPTY_THRESHOLD >= 0 &&
                ALMOST_EMPTY_THRESHOLD <= DEPTH)
            else $error("async_fifo_rptr_empty: ALMOST_EMPTY_THRESHOLD out of range");
    end

    property p_rbin_increments_on_accept;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $past(rd_en && !empty) |-> (rbin == $past(rbin) + 1'b1);
    endproperty
    assert property (p_rbin_increments_on_accept)
        else $error("Read pointer failed to increment on accepted read");

    property p_rbin_holds_without_accept;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $past(!(rd_en && !empty)) |-> (rbin == $past(rbin));
    endproperty
    assert property (p_rbin_holds_without_accept)
        else $error("Read pointer changed without accepted read");

    property p_rgray_onebit_change;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $onehot0(rgray ^ $past(rgray));
    endproperty
    assert property (p_rgray_onebit_change)
        else $error("Read Gray pointer changed by more than one bit");

    property p_rgray_matches_bin2gray;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        rgray == bin2gray(rbin);
    endproperty
    assert property (p_rgray_matches_bin2gray)
        else $error("Read Gray pointer is inconsistent with rbin");

    property p_empty_implies_no_accept;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $past(empty && rd_en) |-> (rbin == $past(rbin));
    endproperty
    assert property (p_empty_implies_no_accept)
        else $error("Read pointer advanced while empty");

    property p_underflow_pulse_definition;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        underflow_pulse == $past(rd_en && empty);
    endproperty
    assert property (p_underflow_pulse_definition)
        else $error("underflow_pulse definition mismatch");

    property p_empty_raised_at_correct_time;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        empty == $past(rempty_val);
    endproperty
    assert property (p_empty_raised_at_correct_time)
        else $error("empty flag timing mismatch");
`endif

endmodule


// -----------------------------------------------------------------------------
// Asynchronous FIFO top-level
// -----------------------------------------------------------------------------
module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDRSIZE = 4,
    parameter int ALMOST_FULL_THRESHOLD = 1,
    parameter int ALMOST_EMPTY_THRESHOLD = 1
) (
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    output logic                  full,
    output logic                  empty,
    output logic                  almost_full,
    output logic                  almost_empty,
    output logic                  overflow_pulse,
    output logic                  underflow_pulse
);

    localparam int PTR_W = ADDRSIZE + 1;
    localparam int DEPTH = (1 << ADDRSIZE);

    logic [PTR_W-1:0] wbin, wgray;
    logic [PTR_W-1:0] rbin, rgray;
    logic [PTR_W-1:0] wq2_rgray, rq2_wgray;
    logic             wr_en_mem, rd_en_mem;

    assign wr_en_mem = wr_en && !full;
    assign rd_en_mem = rd_en && !empty;

    // Synchronize the read Gray pointer into the write clock domain.
    async_fifo_sync #(
        .PTR_W(PTR_W)
    ) u_sync_r2w (
        .clk   (wr_clk),
        .rst_n (wr_rst_n),
        .d_in  (rgray),
        .d_out (wq2_rgray)
    );

    // Synchronize the write Gray pointer into the read clock domain.
    async_fifo_sync #(
        .PTR_W(PTR_W)
    ) u_sync_w2r (
        .clk   (rd_clk),
        .rst_n (rd_rst_n),
        .d_in  (wgray),
        .d_out (rq2_wgray)
    );

    async_fifo_wptr_full #(
        .ADDRSIZE              (ADDRSIZE),
        .ALMOST_FULL_THRESHOLD (ALMOST_FULL_THRESHOLD)
    ) u_wptr_full (
        .wr_clk        (wr_clk),
        .wr_rst_n      (wr_rst_n),
        .wr_en         (wr_en),
        .rq2_wgray     (wq2_rgray),
        .wbin          (wbin),
        .wgray         (wgray),
        .full          (full),
        .almost_full   (almost_full),
        .overflow_pulse(overflow_pulse)
    );

    async_fifo_rptr_empty #(
        .ADDRSIZE               (ADDRSIZE),
        .ALMOST_EMPTY_THRESHOLD (ALMOST_EMPTY_THRESHOLD)
    ) u_rptr_empty (
        .rd_clk         (rd_clk),
        .rd_rst_n       (rd_rst_n),
        .rd_en          (rd_en),
        .wq2_rgray      (rq2_wgray),
        .rbin           (rbin),
        .rgray          (rgray),
        .empty          (empty),
        .almost_empty   (almost_empty),
        .underflow_pulse(underflow_pulse)
    );

    async_fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDRSIZE   (ADDRSIZE)
    ) u_mem (
        .wr_clk   (wr_clk),
        .wr_en_mem(wr_en_mem),
        .wr_addr  (wbin[ADDRSIZE-1:0]),
        .wr_data  (wr_data),
        .rd_clk   (rd_clk),
        .rd_rst_n (rd_rst_n),
        .rd_en_mem(rd_en_mem),
        .rd_addr  (rbin[ADDRSIZE-1:0]),
        .rd_data  (rd_data)
    );

`ifndef SYNTHESIS
    initial begin
        assert (DATA_WIDTH >= 1)
            else $error("async_fifo: DATA_WIDTH must be >= 1");
        assert (ADDRSIZE >= 1)
            else $error("async_fifo: ADDRSIZE must be >= 1");
        assert (ALMOST_FULL_THRESHOLD >= 0 &&
                ALMOST_FULL_THRESHOLD <= DEPTH)
            else $error("async_fifo: ALMOST_FULL_THRESHOLD out of range");
        assert (ALMOST_EMPTY_THRESHOLD >= 0 &&
                ALMOST_EMPTY_THRESHOLD <= DEPTH)
            else $error("async_fifo: ALMOST_EMPTY_THRESHOLD out of range");
    end

    property p_not_full_and_empty_same_time_wr;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        !(full && empty);
    endproperty
    assert property (p_not_full_and_empty_same_time_wr)
        else $error("full and empty asserted simultaneously (write domain)");

    property p_not_full_and_empty_same_time_rd;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        !(full && empty);
    endproperty
    assert property (p_not_full_and_empty_same_time_rd)
        else $error("full and empty asserted simultaneously (read domain)");

    property p_reset_flags_wr;
        @(posedge wr_clk)
        !wr_rst_n |=> (full == 1'b0);
    endproperty
    assert property (p_reset_flags_wr)
        else $error("full not low after write reset");

    property p_reset_flags_rd;
        @(posedge rd_clk)
        !rd_rst_n |=> (empty == 1'b1);
    endproperty
    assert property (p_reset_flags_rd)
        else $error("empty not high after read reset");

    property p_no_x_on_sync_rgray;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        !$isunknown(wq2_rgray);
    endproperty
    assert property (p_no_x_on_sync_rgray)
        else $error("wq2_rgray contains X/Z");

    property p_no_x_on_sync_wgray;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        !$isunknown(rq2_wgray);
    endproperty
    assert property (p_no_x_on_sync_wgray)
        else $error("rq2_wgray contains X/Z");
`endif

endmodule
