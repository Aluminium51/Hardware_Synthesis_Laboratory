`timescale 1ns/1ps

// vga_clock_select
// Purpose: select the VGA/readout clock between 100 MHz 2x mode and 108 MHz 4x mode.
// Clock domain: clock mux primitive output.
// Outputs: clk_out selected by a reset-latched static select.
// Assumption: select changes only while the VGA domain is held in reset.
module vga_clock_select (
    input  wire clk_100,
    input  wire clk_108,
    input  wire select_108,
    output wire clk_out
);

`ifndef __ICARUS__
    BUFGMUX_CTRL u_vga_clk_mux (
        .I0 (clk_100),
        .I1 (clk_108),
        .S  (select_108),
        .O  (clk_out)
    );
`else
    assign clk_out = select_108 ? clk_108 : clk_100;
`endif

endmodule
