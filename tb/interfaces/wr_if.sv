interface wr_if #(parameter int DATA_WIDTH = 32) (input logic wr_clk);

    logic                  wr_rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;

    logic                  full;
    logic                  almost_full;
    logic                  overflow_pulse;

    clocking drv_cb @(posedge wr_clk);
        output wr_en, wr_data;
        input  full, almost_full, overflow_pulse;
    endclocking

    clocking mon_cb @(posedge wr_clk);
        input wr_rst_n, wr_en, wr_data, full, almost_full, overflow_pulse;
    endclocking

endinterface
