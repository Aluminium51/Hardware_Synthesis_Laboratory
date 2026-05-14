`timescale 1ns/1ps

// framebuffer_bram
//
// Purpose:
//   Dual-port RGB565 framebuffer wrapper for one 320x240 raw video frame.
//
// Clock domains:
//   wr_clk - camera-side write port
//   rd_clk - VGA-side read port
//
// Inputs:
//   wr_en/wr_addr/wr_data - synchronous write transaction
//   rd_addr               - synchronous read address
//
// Outputs:
//   rd_data               - read data returned on the next rd_clk edge
//
// Assumption:
//   Callers keep addresses within 0..FRAME_PIXELS-1 for the baseline frame.
module framebuffer_bram #(
    parameter DATA_WIDTH   = 16,
    parameter ADDR_WIDTH   = 17,
    parameter FRAME_PIXELS = 76800
) (
    input  wire                    wr_clk,
    input  wire                    wr_en,
    input  wire [ADDR_WIDTH-1:0]   wr_addr,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    input  wire                    rd_clk,
    input  wire [ADDR_WIDTH-1:0]   rd_addr,
    output reg  [DATA_WIDTH-1:0]   rd_data
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:FRAME_PIXELS-1];

    // Camera-domain write port. The capture block supplies bounded linear
    // addresses and pulses wr_en once per completed RGB565 pixel.
    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // VGA-domain read port. The readout modules delay sync/control signals to
    // match this registered BRAM read latency.
    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule
