interface rd_if #(parameter int DATA_WIDTH = 32) (input logic rd_clk);

    logic                  rd_rst_n;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;

    logic                  empty;
    logic                  almost_empty;
    logic                  underflow_pulse;

    clocking drv_cb @(posedge rd_clk);
        output rd_en;
        input  rd_data, empty, almost_empty, underflow_pulse;
    endclocking

    clocking mon_cb @(posedge rd_clk);
        input rd_rst_n, rd_en, rd_data, empty, almost_empty, underflow_pulse;
    endclocking

endinterface
