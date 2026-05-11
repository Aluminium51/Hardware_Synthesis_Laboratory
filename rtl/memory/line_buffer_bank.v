`timescale 1ns/1ps

// line_buffer_bank
// Purpose: dual-port line buffer for one RGB565 scanline.
// Clock domains: write port uses wr_clk, read port uses rd_clk.
// Ports: independent write and read address/data/enable for one line.
// Assumption: callers keep addresses within 0..LINE_PIXELS-1.
module line_buffer_bank #(
    parameter integer DATA_WIDTH   = 16,
    parameter integer LINE_PIXELS  = 640,
    parameter integer ADDR_WIDTH   = 10
) (
    input  wire                    wr_clk,
    input  wire                    wr_en,
    input  wire [ADDR_WIDTH-1:0]   wr_addr,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    input  wire                    rd_clk,
    input  wire                    rd_en,
    input  wire [ADDR_WIDTH-1:0]   rd_addr,
    output reg  [DATA_WIDTH-1:0]   rd_data
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:LINE_PIXELS-1];

    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end else begin
            rd_data <= {DATA_WIDTH{1'b0}};
        end
    end

endmodule
