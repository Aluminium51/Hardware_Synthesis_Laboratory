`timescale 1ns/1ps

// framebuffer_bram
// Purpose: dual-port RGB444 framebuffer wrapper for one 320x240 raw frame.
// Clock domains: write port uses wr_clk, read port uses rd_clk.
// Ports: independent write address/data/enable and synchronous read address/data.
// Assumption: callers keep addresses within 0..76799 for the baseline frame.
module framebuffer_bram #(
    parameter DATA_WIDTH   = 12,
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

    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule
