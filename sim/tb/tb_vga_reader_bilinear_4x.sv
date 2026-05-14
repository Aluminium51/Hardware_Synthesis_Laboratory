`timescale 1ns/1ps

module tb_vga_reader_bilinear_4x;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg enable = 1'b1;
    reg enable_bilinear = 1'b0;
    reg [10:0] vga_x = 11'd0;
    reg [9:0]  vga_y = 10'd0;
    reg [10:0] h_count = 11'd0;
    reg [9:0]  v_count = 10'd0;
    reg        active_video_in = 1'b0;
    reg        hsync_in = 1'b0;
    reg        vsync_in = 1'b0;
    reg [15:0] fb_rd_data = 16'h0000;

    wire [16:0] fb_rd_addr;
    wire [15:0] pixel_out;
    wire        active_video_out;
    wire        hsync_out;
    wire        vsync_out;

    int errors;

    vga_reader_bilinear_4x dut (
        .clk              (clk),
        .rst              (rst),
        .enable           (enable),
        .enable_bilinear  (enable_bilinear),
        .vga_x            (vga_x),
        .vga_y            (vga_y),
        .h_count          (h_count),
        .v_count          (v_count),
        .active_video_in  (active_video_in),
        .hsync_in         (hsync_in),
        .vsync_in         (vsync_in),
        .fb_rd_addr       (fb_rd_addr),
        .fb_rd_data       (fb_rd_data),
        .pixel_out        (pixel_out),
        .active_video_out (active_video_out),
        .hsync_out        (hsync_out),
        .vsync_out        (vsync_out)
    );

    always #5 clk = ~clk;

    function automatic [16:0] fb_addr(input [7:0] y, input [8:0] x);
        begin
            fb_addr = {1'b0, y, 8'b0} + {3'b000, y, 6'b0} + {8'b00000000, x};
        end
    endfunction

    function automatic [15:0] mem_pixel(input [8:0] x, input [7:0] y);
        reg [4:0] r;
        reg [5:0] g;
        reg [4:0] b;
        begin
            r = x[4:0];
            g = {y[4:0], 1'b0};
            b = (x[4:0] + y[4:0]) & 5'h1f;
            mem_pixel = {r, g, b};
        end
    endfunction

    function automatic [15:0] mem_word(input [16:0] addr);
        int y;
        int x;
        begin
            y = addr / 320;
            x = addr - (y * 320);
            if ((y >= 0) && (y < 240) && (x >= 0) && (x < 320)) begin
                mem_word = mem_pixel(x[8:0], y[7:0]);
            end else begin
                mem_word = 16'h0000;
            end
        end
    endfunction

    function automatic [7:0] mul5(input [4:0] value, input [2:0] weight);
        begin
            case (weight)
                3'd0: mul5 = 8'd0;
                3'd1: mul5 = {3'd0, value};
                3'd2: mul5 = {2'd0, value, 1'b0};
                3'd3: mul5 = {3'd0, value} + {2'd0, value, 1'b0};
                3'd4: mul5 = {1'd0, value, 2'b00};
                default: mul5 = 8'd0;
            endcase
        end
    endfunction

    function automatic [8:0] mul6(input [5:0] value, input [2:0] weight);
        begin
            case (weight)
                3'd0: mul6 = 9'd0;
                3'd1: mul6 = {3'd0, value};
                3'd2: mul6 = {2'd0, value, 1'b0};
                3'd3: mul6 = {3'd0, value} + {2'd0, value, 1'b0};
                3'd4: mul6 = {1'd0, value, 2'b00};
                default: mul6 = 9'd0;
            endcase
        end
    endfunction

    function automatic [4:0] interp5(
        input [4:0] c00, input [4:0] c10, input [4:0] c01, input [4:0] c11,
        input [1:0] fx, input [1:0] fy
    );
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
            top_sum = {1'b0, mul5(c00, wx0)} + {1'b0, mul5(c10, wx1)};
            bot_sum = {1'b0, mul5(c01, wx0)} + {1'b0, mul5(c11, wx1)};
            top = top_sum[6:2];
            bot = bot_sum[6:2];
            out_sum = {1'b0, mul5(top, wy0)} + {1'b0, mul5(bot, wy1)};
            interp5 = out_sum[6:2];
        end
    endfunction

    function automatic [5:0] interp6(
        input [5:0] c00, input [5:0] c10, input [5:0] c01, input [5:0] c11,
        input [1:0] fx, input [1:0] fy
    );
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
            top_sum = {1'b0, mul6(c00, wx0)} + {1'b0, mul6(c10, wx1)};
            bot_sum = {1'b0, mul6(c01, wx0)} + {1'b0, mul6(c11, wx1)};
            top = top_sum[7:2];
            bot = bot_sum[7:2];
            out_sum = {1'b0, mul6(top, wy0)} + {1'b0, mul6(bot, wy1)};
            interp6 = out_sum[7:2];
        end
    endfunction

    function automatic [15:0] expected_pixel(input [10:0] x, input [9:0] y, input bit bilinear);
        reg [8:0] src_x;
        reg [7:0] src_y;
        reg [8:0] right_x;
        reg [7:0] down_y;
        reg [15:0] p00;
        reg [15:0] p10;
        reg [15:0] p01;
        reg [15:0] p11;
        begin
            src_x = x[10:2];
            src_y = y[9:2];
            right_x = (src_x == 9'd319) ? 9'd319 : (src_x + 1'b1);
            down_y = (src_y == 8'd239) ? 8'd239 : (src_y + 1'b1);
            p00 = mem_pixel(src_x, src_y);
            p10 = mem_pixel(right_x, src_y);
            p01 = mem_pixel(src_x, down_y);
            p11 = mem_pixel(right_x, down_y);

            if (!bilinear) begin
                expected_pixel = p00;
            end else begin
                expected_pixel = {
                    interp5(p00[15:11], p10[15:11], p01[15:11], p11[15:11], x[1:0], y[1:0]),
                    interp6(p00[10:5],  p10[10:5],  p01[10:5],  p11[10:5],  x[1:0], y[1:0]),
                    interp5(p00[4:0],   p10[4:0],   p01[4:0],   p11[4:0],   x[1:0], y[1:0])
                };
            end
        end
    endfunction

    always @(posedge clk) begin
        fb_rd_data <= mem_word(fb_rd_addr);
    end

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t h=%0d v=%0d x=%0d y=%0d: %s",
                         $time, h_count, v_count, vga_x, vga_y, message);
            end
        end
    endtask

    task automatic drive_cycle(
        input [10:0] h,
        input [9:0]  v,
        input [10:0] x,
        input [9:0]  y,
        input        active
    );
        begin
            @(negedge clk);
            h_count = h;
            v_count = v;
            vga_x = x;
            vga_y = y;
            active_video_in = active;
            hsync_in = h[0];
            vsync_in = v[0];
            @(posedge clk);
            #1;
        end
    endtask

    task automatic preload_rows_0_1;
        int i;
        begin
            drive_cycle(11'd0, 10'd960, 11'd0, 10'd960, 1'b0);
            for (i = 1; i < 760; i++) begin
                drive_cycle(i[10:0], 10'd960, i[10:0], 10'd960, 1'b0);
            end
            check_signal(dut.rows_ready == 1'b1, "rows 0 and 1 did not preload");
        end
    endtask

    task automatic load_next_row_after_line(input [9:0] visible_y);
        int i;
        begin
            drive_cycle(11'd1280, visible_y, 11'd1280, visible_y, 1'b0);
            for (i = 1281; i < 1650; i++) begin
                drive_cycle(i[10:0], visible_y, i[10:0], visible_y, 1'b0);
            end
        end
    endtask

    task automatic check_output_pixel(input [10:0] x, input [9:0] y, input bit bilinear);
        reg [15:0] exp;
        begin
            enable_bilinear = bilinear;
            exp = expected_pixel(x, y, bilinear);
            drive_cycle(x, y, x, y, 1'b1);
            drive_cycle(x, y, x, y, 1'b1);
            check_signal(active_video_out === 1'b1, "active_video_out should follow active input");
            check_signal(hsync_out === x[0], "hsync_out should follow hsync input");
            check_signal(vsync_out === y[0], "vsync_out should follow vsync input");
            check_signal(pixel_out === exp,
                         $sformatf("pixel mismatch exp=0x%04h got=0x%04h", exp, pixel_out));
        end
    endtask

    int fx;
    int fy;

    initial begin
        errors = 0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        preload_rows_0_1();

        for (fy = 0; fy < 4; fy++) begin
            for (fx = 0; fx < 4; fx++) begin
                check_output_pixel(fx[10:0], fy[9:0], 1'b0);
            end
        end

        for (fy = 0; fy < 4; fy++) begin
            for (fx = 0; fx < 4; fx++) begin
                check_output_pixel(fx[10:0], fy[9:0], 1'b1);
            end
        end

        load_next_row_after_line(10'd3);
        check_signal(dut.row0_src_y == 8'd1, "row0 did not advance to source row 1 after line 3");
        check_signal(dut.row1_src_y == 8'd2, "row1 did not load source row 2 after line 3");
        check_output_pixel(11'd0, 10'd4, 1'b0);
        check_output_pixel(11'd2, 10'd6, 1'b1);

        load_next_row_after_line(10'd7);
        check_signal(dut.row0_src_y == 8'd2, "row0 did not advance to source row 2 after line 7");
        check_signal(dut.row1_src_y == 8'd3, "row1 did not load source row 3 after line 7");
        check_output_pixel(11'd0, 10'd8, 1'b0);
        check_output_pixel(11'd3, 10'd11, 1'b1);

        if (errors == 0) begin
            $display("PASS: 4x bilinear reader math, bypass, preload, and rolling row loads verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_vga_reader_bilinear_4x found %0d error(s).", errors);
    end

endmodule
