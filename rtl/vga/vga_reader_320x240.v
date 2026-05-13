`timescale 1ns/1ps

// vga_reader_320x240
//
// Purpose:
//   Map 640x480 VGA coordinates to a 320x240 RGB565 framebuffer using exact
//   2x horizontal and vertical pixel doubling.
//
// Clock domain:
//   clk_100, advanced only on the 25 MHz pixel_ce strobe.
//
// Inputs:
//   vga_x/vga_y               - current 640x480 raster coordinate
//   hsync_in/vsync_in         - timing signals aligned to vga_x/vga_y
//   active_video_in           - visible-region qualifier
//   rd_data                   - framebuffer data from the previous read
//
// Outputs:
//   rd_addr                   - linear 320x240 framebuffer read address
//   hsync_out/vsync_out       - delayed sync aligned with rgb565_out
//   active_video_out          - delayed visible-region qualifier
//   rgb565_out                - RGB565 pixel, black outside active video
//
// Assumption:
//   rd_data is valid one pixel_ce step after rd_addr is presented.
module vga_reader_320x240 (
    input  wire        clk_100,
    input  wire        pixel_ce,
    input  wire        rst_vga,
    input  wire [9:0]  vga_x,
    input  wire [9:0]  vga_y,
    input  wire        hsync_in,
    input  wire        vsync_in,
    input  wire        active_video_in,
    input  wire [15:0] rd_data,
    output reg  [16:0] rd_addr,
    output reg         hsync_out,
    output reg         vsync_out,
    output reg         active_video_out,
    output reg  [15:0] rgb565_out
);

    wire [8:0] src_x = vga_x[9:1];
    wire [7:0] src_y = vga_y[8:1];

    wire [16:0] scaled_addr =
        {1'b0, src_y, 8'b0} + {3'b000, src_y, 6'b0} + {8'b00000000, src_x};

    wire [16:0] next_rd_addr = active_video_in ? scaled_addr : 17'd0;

    reg hsync_pipe = 1'b1;
    reg vsync_pipe = 1'b1;
    reg active_video_pipe = 1'b0;

    // One-pixel pipeline compensates for the synchronous framebuffer read:
    // address is issued this pixel_ce, and matching data/control leave on the
    // following pixel_ce.
    always @(posedge clk_100) begin
        if (rst_vga) begin
            rd_addr           <= 17'd0;
            hsync_pipe        <= 1'b1;
            vsync_pipe        <= 1'b1;
            active_video_pipe <= 1'b0;
            hsync_out         <= 1'b1;
            vsync_out         <= 1'b1;
            active_video_out  <= 1'b0;
            rgb565_out        <= 16'h0000;
        end else if (pixel_ce) begin
            rd_addr           <= next_rd_addr;
            hsync_pipe        <= hsync_in;
            vsync_pipe        <= vsync_in;
            active_video_pipe <= active_video_in;
            hsync_out         <= hsync_pipe;
            vsync_out         <= vsync_pipe;
            active_video_out  <= active_video_pipe;
            rgb565_out        <= active_video_pipe ? rd_data : 16'h0000;
        end
    end

endmodule
