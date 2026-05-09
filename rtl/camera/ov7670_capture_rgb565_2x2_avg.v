`timescale 1ns/1ps

// ov7670_capture_rgb565_2x2_avg
// Purpose: capture a full-resolution OV7670 RGB565 stream, average each 2x2
// source block, and write one 320x240 RGB565 pixel per block.
// Clock domain: camera pixel clock, pclk.
// Ports: camera sync/data inputs and linear framebuffer write-side outputs.
// Assumptions: RGB565 bytes arrive MSB first; VSYNC is an active-high frame boundary.
module ov7670_capture_rgb565_2x2_avg #(
    parameter integer SRC_WIDTH  = 640,
    parameter integer SRC_HEIGHT = 480,
    parameter integer DST_WIDTH  = 320,
    parameter integer DST_HEIGHT = 240,
    parameter integer RIGHT_CLAMP_DST_COLS = 0,
    parameter integer DIAG_EXTRA_PIXELS = 8,
    parameter integer FRAME_PIXELS = DST_WIDTH * DST_HEIGHT,
    parameter integer ADDR_WIDTH = 17
) (
    input  wire                  pclk,
    input  wire                  rst,
    input  wire                  vsync,
    input  wire                  href,
    input  wire [7:0]            cam_d,
    output reg                   wr_en,
    output reg  [ADDR_WIDTH-1:0] wr_addr,
    output reg  [15:0]           wr_data,
    output reg                   frame_done,
    output reg                   frame_active,
    output reg                   dbg_line_seen,
    output reg                   dbg_line_ge_width,
    output reg                   dbg_line_ge_width_plus_1,
    output reg                   dbg_line_ge_width_plus_extra
);

    localparam [ADDR_WIDTH-1:0] FRAME_LAST_ADDR = FRAME_PIXELS - 1;
    localparam [9:0] SRC_WIDTH_COUNT = SRC_WIDTH;
    localparam [8:0] SRC_HEIGHT_COUNT = SRC_HEIGHT;
    localparam [9:0] DIAG_WIDTH = SRC_WIDTH;
    localparam [9:0] DIAG_WIDTH_PLUS_1 = SRC_WIDTH + 1;
    localparam [9:0] DIAG_WIDTH_PLUS_EXTRA = SRC_WIDTH + DIAG_EXTRA_PIXELS;
    localparam [8:0] RIGHT_CLAMP_START =
        (RIGHT_CLAMP_DST_COLS >= DST_WIDTH) ? 9'd0 : (DST_WIDTH - RIGHT_CLAMP_DST_COLS);

    (* ram_style = "distributed" *) reg [15:0] previous_line [0:SRC_WIDTH-1];

    reg       vsync_d;
    reg       byte_phase;
    reg [7:0] first_byte;
    reg       frame_has_pixel;
    reg       frame_full;
    reg       href_d;
    reg       line_has_pixel;
    reg [9:0] x_count;
    reg [8:0] y_count;
    reg [15:0] previous_pixel;
    reg [15:0] top_left_hold;
    reg [15:0] last_unclamped_avg_pixel;

    wire vsync_rise = vsync && !vsync_d;
    wire [15:0] rgb565_pixel = {first_byte, cam_d};
    wire x_in_bounds = (x_count < SRC_WIDTH_COUNT);
    wire y_in_bounds = (y_count < SRC_HEIGHT_COUNT);
    wire [9:0] top_right_index = x_in_bounds ? x_count : 10'd0;
    wire [15:0] top_right = previous_line[top_right_index];
    wire [15:0] bottom_left = previous_pixel;
    wire [15:0] bottom_right = rgb565_pixel;

    wire source_in_bounds = x_in_bounds && y_in_bounds;
    wire output_pixel = source_in_bounds && x_count[0] && y_count[0];
    wire [8:0] dst_x = x_count[9:1];
    wire [7:0] dst_y = y_count[8:1];
    wire [31:0] dest_addr_full = (dst_y * DST_WIDTH) + dst_x;
    wire [ADDR_WIDTH-1:0] dest_addr = dest_addr_full[ADDR_WIDTH-1:0];
    wire right_clamp_pixel = (RIGHT_CLAMP_DST_COLS > 0) &&
                             (dst_x >= RIGHT_CLAMP_START);

    function [4:0] avg5;
        input [4:0] a;
        input [4:0] b;
        input [4:0] c;
        input [4:0] d;
        reg [6:0] sum;
        begin
            sum = {2'b00, a} + {2'b00, b} + {2'b00, c} + {2'b00, d} + 7'd2;
            avg5 = sum[6:2];
        end
    endfunction

    function [5:0] avg6;
        input [5:0] a;
        input [5:0] b;
        input [5:0] c;
        input [5:0] d;
        reg [7:0] sum;
        begin
            sum = {2'b00, a} + {2'b00, b} + {2'b00, c} + {2'b00, d} + 8'd2;
            avg6 = sum[7:2];
        end
    endfunction

    function [15:0] avg_rgb565_2x2;
        input [15:0] p00;
        input [15:0] p01;
        input [15:0] p10;
        input [15:0] p11;
        begin
            avg_rgb565_2x2 = {
                avg5(p00[15:11], p01[15:11], p10[15:11], p11[15:11]),
                avg6(p00[10:5],  p01[10:5],  p10[10:5],  p11[10:5]),
                avg5(p00[4:0],   p01[4:0],   p10[4:0],   p11[4:0])
            };
        end
    endfunction

    wire [15:0] averaged_pixel =
        avg_rgb565_2x2(top_left_hold, top_right, bottom_left, bottom_right);

    always @(posedge pclk) begin
        if (rst) begin
            vsync_d         <= 1'b0;
            byte_phase      <= 1'b0;
            first_byte      <= 8'h00;
            frame_has_pixel <= 1'b0;
            frame_full      <= 1'b0;
            href_d          <= 1'b0;
            line_has_pixel  <= 1'b0;
            x_count         <= 10'd0;
            y_count         <= 9'd0;
            previous_pixel  <= 16'h0000;
            top_left_hold   <= 16'h0000;
            last_unclamped_avg_pixel <= 16'h0000;
            wr_en           <= 1'b0;
            wr_addr         <= {ADDR_WIDTH{1'b0}};
            wr_data         <= 16'h0000;
            frame_done      <= 1'b0;
            frame_active    <= 1'b0;
            dbg_line_seen   <= 1'b0;
            dbg_line_ge_width <= 1'b0;
            dbg_line_ge_width_plus_1 <= 1'b0;
            dbg_line_ge_width_plus_extra <= 1'b0;
        end else begin
            vsync_d    <= vsync;
            href_d     <= href;
            wr_en      <= 1'b0;
            frame_done <= 1'b0;

            if (vsync) begin
                byte_phase     <= 1'b0;
                first_byte     <= 8'h00;
                line_has_pixel <= 1'b0;
                x_count        <= 10'd0;
                y_count        <= 9'd0;
                previous_pixel <= 16'h0000;
                top_left_hold <= 16'h0000;
                last_unclamped_avg_pixel <= 16'h0000;

                if (vsync_rise) begin
                    wr_addr         <= {ADDR_WIDTH{1'b0}};
                    frame_done      <= frame_has_pixel;
                    frame_active    <= 1'b0;
                    frame_has_pixel <= 1'b0;
                    frame_full      <= 1'b0;
                    dbg_line_seen   <= 1'b0;
                    dbg_line_ge_width <= 1'b0;
                    dbg_line_ge_width_plus_1 <= 1'b0;
                    dbg_line_ge_width_plus_extra <= 1'b0;
                end
            end else if (!href) begin
                byte_phase <= 1'b0;
                first_byte <= 8'h00;

                if (href_d && line_has_pixel) begin
                    dbg_line_seen <= 1'b1;
                    if (x_count >= DIAG_WIDTH) begin
                        dbg_line_ge_width <= 1'b1;
                    end
                    if (x_count >= DIAG_WIDTH_PLUS_1) begin
                        dbg_line_ge_width_plus_1 <= 1'b1;
                    end
                    if (x_count >= DIAG_WIDTH_PLUS_EXTRA) begin
                        dbg_line_ge_width_plus_extra <= 1'b1;
                    end

                    if (y_count < SRC_HEIGHT_COUNT) begin
                        y_count <= y_count + 1'b1;
                    end

                    x_count        <= 10'd0;
                    previous_pixel <= 16'h0000;
                    last_unclamped_avg_pixel <= 16'h0000;
                    line_has_pixel <= 1'b0;
                end
            end else begin
                frame_active <= 1'b1;

                if (!byte_phase) begin
                    first_byte <= cam_d;
                    byte_phase <= 1'b1;
                end else begin
                    byte_phase     <= 1'b0;
                    line_has_pixel <= 1'b1;

                    if (source_in_bounds) begin
                        if (y_count[0] && !x_count[0]) begin
                            top_left_hold <= top_right;
                        end

                        previous_line[x_count] <= rgb565_pixel;
                    end
                    previous_pixel <= rgb565_pixel;

                    if (x_count != 10'h3ff) begin
                        x_count <= x_count + 1'b1;
                    end

                    if (!frame_full && output_pixel) begin
                        wr_en           <= 1'b1;
                        wr_addr         <= dest_addr;
                        if (right_clamp_pixel) begin
                            wr_data <= last_unclamped_avg_pixel;
                        end else begin
                            wr_data <= averaged_pixel;
                            last_unclamped_avg_pixel <= averaged_pixel;
                        end
                        frame_has_pixel <= 1'b1;

                        if (dest_addr == FRAME_LAST_ADDR) begin
                            frame_full <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
