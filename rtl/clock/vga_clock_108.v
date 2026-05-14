`timescale 1ns/1ps

// vga_clock_108
// Purpose: derive the 108 MHz pixel/read clock used for 1280x960 @ 60 Hz VGA.
// Clock domain: input clk_100, output clk_108.
// Outputs: clk_108 and locked from an MMCME2_BASE in synthesis.
// Assumption: Icarus simulation uses a pass-through clock so non-Vivado testbenches can elaborate.
module vga_clock_108 (
    input  wire clk_100,
    input  wire rst,
    output wire clk_108,
    output wire locked
);

`ifndef __ICARUS__
    wire clkfb;
    wire clk108_unbuf;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKIN1_PERIOD      (10.000),
        .DIVCLK_DIVIDE      (5),
        .CLKFBOUT_MULT_F    (54.000),
        .CLKFBOUT_PHASE     (0.000),
        .CLKOUT0_DIVIDE_F   (10.000),
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk_100),
        .RST      (rst),
        .PWRDWN   (1'b0),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clk108_unbuf),
        .CLKOUT1  (),
        .CLKOUT2  (),
        .CLKOUT3  (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .LOCKED   (locked)
    );

    BUFG u_clk108_bufg (
        .I (clk108_unbuf),
        .O (clk_108)
    );
`else
    assign clk_108 = clk_100;
    assign locked  = ~rst;
`endif

endmodule
