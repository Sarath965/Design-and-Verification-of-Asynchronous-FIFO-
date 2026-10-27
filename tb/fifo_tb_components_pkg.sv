package fifo_tb_components_pkg;

    `import fifo_tb_types_pkg::*;

    // Each testbench component class lives in its own file under ./components and is
    // pulled in here via `include. The include order is identical to the original
    // single-file declaration order, so elaboration and behaviour are unchanged.
    // Resolution relies on +incdir+./tb/pkg/components in tb/run/filelist.f.

    `include "fifo_generator.svh"
    `include "fifo_wr_driver.svh"
    `include "fifo_rd_driver.svh"
    `include "fifo_wr_monitor.svh"
    `include "fifo_rd_monitor.svh"
    `include "fifo_ref_model.svh"
    `include "fifo_scoreboard.svh"
    `include "fifo_coverage.svh"
    `include "fifo_env.svh"

endpackage
