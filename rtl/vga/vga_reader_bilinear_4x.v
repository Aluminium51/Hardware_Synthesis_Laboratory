`timescale 1ns/1ps

// vga_reader_bilinear_4x
// Purpose: line-buffered 320x240 to 1280x960 readout with optional 4x bilinear interpolation.
// Clock domain: selected 108 MHz VGA/read clock in 4x mode.
// Outputs: framebuffer read address during blanking plus aligned RGB565/sync/control output.
// Assumption: framebuffer read data is valid one clk after fb_rd_addr is presented.
module vga_reader_bilinear_4x (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire        enable_bilinear,
    input  wire [10:0] vga_x,
    input  wire [9:0]  vga_y,
    input  wire [10:0] h_count,
    input  wire [9:0]  v_count,
    input  wire        active_video_in,
    input  wire        hsync_in,
    input  wire        vsync_in,
    output reg  [16:0] fb_rd_addr,
    input  wire [15:0] fb_rd_data,
    output reg  [15:0] pixel_out,
    output reg         active_video_out,
    output reg         hsync_out,
    output reg         vsync_out
);

    localparam [10:0] H_ACTIVE = 11'd1280;
    localparam [9:0]  V_ACTIVE = 10'd960;

    localparam [1:0] LOAD_PRE0 = 2'd0;
    localparam [1:0] LOAD_PRE1 = 2'd1;
    localparam [1:0] LOAD_ROLL = 2'd2;

    (* ram_style = "distributed" *) reg [15:0] linebuf0 [0:319];
    (* ram_style = "distributed" *) reg [15:0] linebuf1 [0:319];

    reg        rows_ready = 1'b0;
    reg        row0_sel = 1'b0;
    reg        row1_sel = 1'b1;
    reg [7:0]  row0_src_y = 8'd0;
    reg [7:0]  row1_src_y = 8'd1;

    reg        load_active = 1'b0;
    reg        load_issuing = 1'b0;
    reg [1:0]  load_op = LOAD_PRE0;
    reg [8:0]  load_x = 9'd0;
    reg [7:0]  load_row = 8'd0;
    reg        load_target_sel = 1'b0;
    reg        load_valid_d = 1'b0;
    reg [8:0]  load_x_d = 9'd0;
    reg        load_target_sel_d = 1'b0;
    reg        load_valid_d2 = 1'b0;
    reg [8:0]  load_x_d2 = 9'd0;
    reg        load_target_sel_d2 = 1'b0;

    wire [8:0] src_x = vga_x[10:2];
    wire [7:0] src_y = vga_y[9:2];
    wire [8:0] right_x = (src_x == 9'd319) ? 9'd319 : (src_x + 1'b1);
    wire [1:0] frac_x = vga_x[1:0];
    wire [1:0] frac_y = vga_y[1:0];

    wire [15:0] p00 = row0_sel ? linebuf1[src_x]   : linebuf0[src_x];
    wire [15:0] p10 = row0_sel ? linebuf1[right_x] : linebuf0[right_x];
    wire [15:0] p01 = row1_sel ? linebuf1[src_x]   : linebuf0[src_x];
    wire [15:0] p11 = row1_sel ? linebuf1[right_x] : linebuf0[right_x];

    reg [15:0] p00_pipe = 16'h0000;
    reg [15:0] p10_pipe = 16'h0000;
    reg [15:0] p01_pipe = 16'h0000;
    reg [15:0] p11_pipe = 16'h0000;
    reg [1:0]  frac_x_pipe = 2'd0;
    reg [1:0]  frac_y_pipe = 2'd0;
    reg        enable_bilinear_pipe = 1'b0;
    reg        active_video_pipe = 1'b0;
    reg        hsync_pipe = 1'b0;
    reg        vsync_pipe = 1'b0;

    wire preload_start = enable && !load_active && (h_count == 11'd0) && (v_count == V_ACTIVE);
    wire rolling_start = enable && rows_ready && !load_active &&
                         (h_count == H_ACTIVE) && (v_count < 10'd956) && (v_count[1:0] == 2'b11);
    wire load_last_write = load_valid_d2 && (load_x_d2 == 9'd319);
    wire [7:0] rolling_row = (((v_count[9:2] + 8'd2) > 8'd239) ? 8'd239 :
                              (v_count[9:2] + 8'd2));

    function [16:0] fb_addr;
        input [7:0] y;
        input [8:0] x;
        begin
            fb_addr = {1'b0, y, 8'b0} + {3'b000, y, 6'b0} + {8'b00000000, x};
        end
    endfunction

    function [7:0] mul_0_to_4_5bit;
        input [4:0] value;
        input [2:0] weight;
        begin
            case (weight)
                3'd0: mul_0_to_4_5bit = 8'd0;
                3'd1: mul_0_to_4_5bit = {3'd0, value};
                3'd2: mul_0_to_4_5bit = {2'd0, value, 1'b0};
                3'd3: mul_0_to_4_5bit = {3'd0, value} + {2'd0, value, 1'b0};
                3'd4: mul_0_to_4_5bit = {1'd0, value, 2'b00};
                default: mul_0_to_4_5bit = 8'd0;
            endcase
        end
    endfunction

    function [8:0] mul_0_to_4_6bit;
        input [5:0] value;
        input [2:0] weight;
        begin
            case (weight)
                3'd0: mul_0_to_4_6bit = 9'd0;
                3'd1: mul_0_to_4_6bit = {3'd0, value};
                3'd2: mul_0_to_4_6bit = {2'd0, value, 1'b0};
                3'd3: mul_0_to_4_6bit = {3'd0, value} + {2'd0, value, 1'b0};
                3'd4: mul_0_to_4_6bit = {1'd0, value, 2'b00};
                default: mul_0_to_4_6bit = 9'd0;
            endcase
        end
    endfunction

    function [4:0] interp4_5bit;
        input [4:0] c00;
        input [4:0] c10;
        input [4:0] c01;
        input [4:0] c11;
        input [1:0] fx;
        input [1:0] fy;
        reg [2:0] wx0;
        reg [2:0] wx1;
        reg [2:0] wy0;
        reg [2:0] wy1;
        reg [8:0] top_sum;
        reg [8:0] bot_sum;
        reg [4:0] top;
        reg [4:0] bot;
        reg [8:0] out_sum;
        begin
            wx1 = {1'b0, fx};
            wx0 = 3'd4 - {1'b0, fx};
            wy1 = {1'b0, fy};
            wy0 = 3'd4 - {1'b0, fy};
            top_sum = {1'b0, mul_0_to_4_5bit(c00, wx0)} + {1'b0, mul_0_to_4_5bit(c10, wx1)};
            bot_sum = {1'b0, mul_0_to_4_5bit(c01, wx0)} + {1'b0, mul_0_to_4_5bit(c11, wx1)};
            top = top_sum[6:2];
            bot = bot_sum[6:2];
            out_sum = {1'b0, mul_0_to_4_5bit(top, wy0)} + {1'b0, mul_0_to_4_5bit(bot, wy1)};
            interp4_5bit = out_sum[6:2];
        end
    endfunction

    function [5:0] interp4_6bit;
        input [5:0] c00;
        input [5:0] c10;
        input [5:0] c01;
        input [5:0] c11;
        input [1:0] fx;
        input [1:0] fy;
        reg [2:0] wx0;
        reg [2:0] wx1;
        reg [2:0] wy0;
        reg [2:0] wy1;
        reg [9:0] top_sum;
        reg [9:0] bot_sum;
        reg [5:0] top;
        reg [5:0] bot;
        reg [9:0] out_sum;
        begin
            wx1 = {1'b0, fx};
            wx0 = 3'd4 - {1'b0, fx};
            wy1 = {1'b0, fy};
            wy0 = 3'd4 - {1'b0, fy};
            top_sum = {1'b0, mul_0_to_4_6bit(c00, wx0)} + {1'b0, mul_0_to_4_6bit(c10, wx1)};
            bot_sum = {1'b0, mul_0_to_4_6bit(c01, wx0)} + {1'b0, mul_0_to_4_6bit(c11, wx1)};
            top = top_sum[7:2];
            bot = bot_sum[7:2];
            out_sum = {1'b0, mul_0_to_4_6bit(top, wy0)} + {1'b0, mul_0_to_4_6bit(bot, wy1)};
            interp4_6bit = out_sum[7:2];
        end
    endfunction

    wire [15:0] bilinear_pixel = {
        interp4_5bit(p00_pipe[15:11], p10_pipe[15:11], p01_pipe[15:11], p11_pipe[15:11],
                     frac_x_pipe, frac_y_pipe),
        interp4_6bit(p00_pipe[10:5],  p10_pipe[10:5],  p01_pipe[10:5],  p11_pipe[10:5],
                     frac_x_pipe, frac_y_pipe),
        interp4_5bit(p00_pipe[4:0],   p10_pipe[4:0],   p01_pipe[4:0],   p11_pipe[4:0],
                     frac_x_pipe, frac_y_pipe)
    };

    always @(posedge clk) begin
        if (rst) begin
            fb_rd_addr        <= 17'd0;
            pixel_out         <= 16'h0000;
            active_video_out  <= 1'b0;
            hsync_out         <= 1'b0;
            vsync_out         <= 1'b0;
            rows_ready        <= 1'b0;
            row0_sel          <= 1'b0;
            row1_sel          <= 1'b1;
            row0_src_y        <= 8'd0;
            row1_src_y        <= 8'd1;
            load_active       <= 1'b0;
            load_issuing      <= 1'b0;
            load_op           <= LOAD_PRE0;
            load_x            <= 9'd0;
            load_row          <= 8'd0;
            load_target_sel   <= 1'b0;
            load_valid_d      <= 1'b0;
            load_x_d          <= 9'd0;
            load_target_sel_d <= 1'b0;
            load_valid_d2      <= 1'b0;
            load_x_d2          <= 9'd0;
            load_target_sel_d2 <= 1'b0;
            p00_pipe           <= 16'h0000;
            p10_pipe           <= 16'h0000;
            p01_pipe           <= 16'h0000;
            p11_pipe           <= 16'h0000;
            frac_x_pipe        <= 2'd0;
            frac_y_pipe        <= 2'd0;
            enable_bilinear_pipe <= 1'b0;
            active_video_pipe  <= 1'b0;
            hsync_pipe         <= 1'b0;
            vsync_pipe         <= 1'b0;
        end else begin
            if (load_valid_d2) begin
                if (load_target_sel_d2) begin
                    linebuf1[load_x_d2] <= fb_rd_data;
                end else begin
                    linebuf0[load_x_d2] <= fb_rd_data;
                end
            end

            load_valid_d2      <= load_valid_d;
            load_x_d2          <= load_x_d;
            load_target_sel_d2 <= load_target_sel_d;
            load_valid_d <= 1'b0;

            if (!enable) begin
                fb_rd_addr      <= 17'd0;
                load_active     <= 1'b0;
                load_issuing    <= 1'b0;
                rows_ready      <= 1'b0;
                load_valid_d    <= 1'b0;
                load_valid_d2   <= 1'b0;
            end else if (load_last_write) begin
                if (load_op == LOAD_PRE0) begin
                    load_active       <= 1'b1;
                    load_issuing      <= 1'b1;
                    load_op           <= LOAD_PRE1;
                    load_x            <= 9'd1;
                    load_row          <= 8'd1;
                    load_target_sel   <= 1'b1;
                    fb_rd_addr        <= fb_addr(8'd1, 9'd0);
                    load_valid_d      <= 1'b1;
                    load_x_d          <= 9'd0;
                    load_target_sel_d <= 1'b1;
                end else begin
                    load_active <= 1'b0;
                    load_issuing <= 1'b0;
                    fb_rd_addr  <= 17'd0;

                    if (load_op == LOAD_PRE1) begin
                        rows_ready <= 1'b1;
                        row0_sel   <= 1'b0;
                        row1_sel   <= 1'b1;
                        row0_src_y <= 8'd0;
                        row1_src_y <= 8'd1;
                    end else if (load_op == LOAD_ROLL) begin
                        row0_sel   <= row1_sel;
                        row1_sel   <= load_target_sel;
                        row0_src_y <= row1_src_y;
                        row1_src_y <= load_row;
                    end
                end
            end else if (load_active && load_issuing) begin
                fb_rd_addr        <= fb_addr(load_row, load_x);
                load_valid_d      <= 1'b1;
                load_x_d          <= load_x;
                load_target_sel_d <= load_target_sel;

                if (load_x != 9'd319) begin
                    load_x <= load_x + 1'b1;
                end else begin
                    load_issuing <= 1'b0;
                end
            end else if (preload_start) begin
                rows_ready        <= 1'b0;
                row0_sel          <= 1'b0;
                row1_sel          <= 1'b1;
                load_active       <= 1'b1;
                load_issuing      <= 1'b1;
                load_op           <= LOAD_PRE0;
                load_x            <= 9'd1;
                load_row          <= 8'd0;
                load_target_sel   <= 1'b0;
                fb_rd_addr        <= fb_addr(8'd0, 9'd0);
                load_valid_d      <= 1'b1;
                load_x_d          <= 9'd0;
                load_target_sel_d <= 1'b0;
            end else if (rolling_start) begin
                load_active       <= 1'b1;
                load_issuing      <= 1'b1;
                load_op           <= LOAD_ROLL;
                load_x            <= 9'd1;
                load_row          <= rolling_row;
                load_target_sel   <= row0_sel;
                fb_rd_addr        <= fb_addr(rolling_row, 9'd0);
                load_valid_d      <= 1'b1;
                load_x_d          <= 9'd0;
                load_target_sel_d <= row0_sel;
            end else begin
                fb_rd_addr <= 17'd0;
            end

            p00_pipe             <= p00;
            p10_pipe             <= p10;
            p01_pipe             <= p01;
            p11_pipe             <= p11;
            frac_x_pipe          <= frac_x;
            frac_y_pipe          <= frac_y;
            enable_bilinear_pipe <= enable_bilinear;
            active_video_pipe    <= active_video_in && rows_ready;
            hsync_pipe           <= hsync_in;
            vsync_pipe           <= vsync_in;

            hsync_out        <= hsync_pipe;
            vsync_out        <= vsync_pipe;
            active_video_out <= active_video_pipe;

            if (active_video_pipe) begin
                pixel_out <= enable_bilinear_pipe ? bilinear_pixel : p00_pipe;
            end else begin
                pixel_out <= 16'h0000;
            end
        end
    end

endmodule
