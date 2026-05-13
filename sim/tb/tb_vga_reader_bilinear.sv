`timescale 1ns/1ps

module tb_vga_reader_bilinear;

    localparam int LATENCY = 5;

    reg clk_100 = 1'b0;
    reg pixel_ce = 1'b0;
    reg rst_vga = 1'b1;

    reg [9:0]  vga_x = 10'd0;
    reg [9:0]  vga_y = 10'd0;
    reg        hsync_in = 1'b1;
    reg        vsync_in = 1'b1;
    reg        active_video_in = 1'b0;
    reg [15:0] rd_data = 16'h0000;
    reg        enable_bilinear = 1'b0;

    wire [16:0] rd_addr;
    wire        hsync_out;
    wire        vsync_out;
    wire        active_video_out;
    wire [15:0] rgb565_out;

    reg [LATENCY:0] exp_hsync_pipe = {LATENCY+1{1'b1}};
    reg [LATENCY:0] exp_vsync_pipe = {LATENCY+1{1'b1}};
    reg [LATENCY:0] exp_active_pipe = {LATENCY+1{1'b0}};
    reg [LATENCY:0] exp_valid_pipe = {LATENCY+1{1'b0}};
    reg [15:0] exp_rgb_pipe [0:LATENCY];

    int errors;

    vga_reader_bilinear dut (
        .clk_100          (clk_100),
        .pixel_ce         (pixel_ce),
        .rst_vga          (rst_vga),
        .vga_x            (vga_x),
        .vga_y            (vga_y),
        .hsync_in         (hsync_in),
        .vsync_in         (vsync_in),
        .active_video_in  (active_video_in),
        .rd_data          (rd_data),
        .enable_bilinear  (enable_bilinear),
        .rd_addr          (rd_addr),
        .hsync_out        (hsync_out),
        .vsync_out        (vsync_out),
        .active_video_out (active_video_out),
        .rgb565_out       (rgb565_out)
    );

    always #5 clk_100 = ~clk_100;

    function automatic [16:0] fb_addr(input [8:0] x, input [7:0] y);
        begin
            fb_addr = {1'b0, y, 8'b0} + {3'b000, y, 6'b0} + {8'b00000000, x};
        end
    endfunction

    function automatic [15:0] mem_word(input [16:0] addr);
        begin
            mem_word = addr[0] ? 16'h001f : 16'hf800;
        end
    endfunction

    function automatic [8:0] clamp_x(input [9:0] x);
        begin
            clamp_x = (x[9:1] > 9'd319) ? 9'd319 : x[9:1];
        end
    endfunction

    function automatic [7:0] clamp_y(input [9:0] y);
        begin
            clamp_y = (y[8:1] > 8'd239) ? 8'd239 : y[8:1];
        end
    endfunction

    function automatic [15:0] bilinear_rgb(
        input [9:0] x_value,
        input [9:0] y_value,
        input       active_value,
        input       enable_value
    );
        reg [8:0] src_x;
        reg [7:0] src_y;
        reg [8:0] src_x1;
        reg [7:0] src_y1;
        reg [15:0] p00;
        reg [15:0] p10;
        reg [15:0] p01;
        reg [15:0] p11;
        reg [4:0] r00;
        reg [5:0] g00;
        reg [4:0] b00;
        reg [4:0] r10;
        reg [5:0] g10;
        reg [4:0] b10;
        reg [4:0] r01;
        reg [5:0] g01;
        reg [4:0] b01;
        reg [4:0] r11;
        reg [5:0] g11;
        reg [4:0] b11;
        reg [4:0] r_out;
        reg [5:0] g_out;
        reg [4:0] b_out;
        reg [6:0] r_sum2;
        reg [7:0] g_sum2;
        reg [6:0] b_sum2;
        reg [6:0] r_sum4;
        reg [7:0] g_sum4;
        reg [6:0] b_sum4;
        begin
            if (!active_value) begin
                bilinear_rgb = 16'h0000;
            end else begin
                src_x = clamp_x(x_value);
                src_y = clamp_y(y_value);
                src_x1 = (src_x == 9'd319) ? 9'd319 : (src_x + 1'b1);
                src_y1 = (src_y == 8'd239) ? 8'd239 : (src_y + 1'b1);

                p00 = mem_word(fb_addr(src_x, src_y));
                p10 = mem_word(fb_addr(src_x1, src_y));
                p01 = mem_word(fb_addr(src_x, src_y1));
                p11 = mem_word(fb_addr(src_x1, src_y1));

                r00 = p00[15:11]; g00 = p00[10:5]; b00 = p00[4:0];
                r10 = p10[15:11]; g10 = p10[10:5]; b10 = p10[4:0];
                r01 = p01[15:11]; g01 = p01[10:5]; b01 = p01[4:0];
                r11 = p11[15:11]; g11 = p11[10:5]; b11 = p11[4:0];

                if (!enable_value) begin
                    bilinear_rgb = p00;
                end else begin
                    r_out = r00;
                    g_out = g00;
                    b_out = b00;

                    if (x_value[0] && !y_value[0]) begin
                        r_sum2 = r00 + r10;
                        g_sum2 = g00 + g10;
                        b_sum2 = b00 + b10;
                        r_out = r_sum2[6:1];
                        g_out = g_sum2[7:1];
                        b_out = b_sum2[6:1];
                    end else if (!x_value[0] && y_value[0]) begin
                        r_sum2 = r00 + r01;
                        g_sum2 = g00 + g01;
                        b_sum2 = b00 + b01;
                        r_out = r_sum2[6:1];
                        g_out = g_sum2[7:1];
                        b_out = b_sum2[6:1];
                    end else if (x_value[0] && y_value[0]) begin
                        r_sum4 = r00 + r10 + r01 + r11;
                        g_sum4 = g00 + g10 + g01 + g11;
                        b_sum4 = b00 + b10 + b01 + b11;
                        r_out = r_sum4[6:2];
                        g_out = g_sum4[7:2];
                        b_out = b_sum4[6:2];
                    end

                    bilinear_rgb = {r_out, g_out, b_out};
                end
            end
        end
    endfunction

    always @(posedge clk_100) begin
        rd_data <= mem_word(rd_addr);
    end

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t: %s", $time, message);
            end
        end
    endtask

    task automatic present_pixel(
        input [9:0]  x_value,
        input [9:0]  y_value,
        input        active_value,
        input        hsync_value,
        input        vsync_value
    );
        begin
            @(negedge clk_100);
            vga_x = x_value;
            vga_y = y_value;
            active_video_in = active_value;
            hsync_in = hsync_value;
            vsync_in = vsync_value;
            pixel_ce = 1'b1;

            @(posedge clk_100);
            pixel_ce = 1'b0;

            repeat (3) @(posedge clk_100);
        end
    endtask

    integer i;

    always @(posedge clk_100) begin
        if (rst_vga) begin
            exp_hsync_pipe <= {LATENCY+1{1'b1}};
            exp_vsync_pipe <= {LATENCY+1{1'b1}};
            exp_active_pipe <= {LATENCY+1{1'b0}};
            exp_valid_pipe <= {LATENCY+1{1'b0}};
            for (i = 0; i <= LATENCY; i = i + 1) begin
                exp_rgb_pipe[i] <= 16'h0000;
            end
        end else begin
            if (pixel_ce) begin
                exp_hsync_pipe[0] <= hsync_in;
                exp_vsync_pipe[0] <= vsync_in;
                exp_active_pipe[0] <= active_video_in;
                exp_rgb_pipe[0] <= bilinear_rgb(vga_x, vga_y, active_video_in, enable_bilinear);
                exp_valid_pipe[0] <= 1'b1;
            end else begin
                exp_valid_pipe[0] <= 1'b0;
            end

            for (i = 1; i <= LATENCY; i = i + 1) begin
                exp_hsync_pipe[i] <= exp_hsync_pipe[i-1];
                exp_vsync_pipe[i] <= exp_vsync_pipe[i-1];
                exp_active_pipe[i] <= exp_active_pipe[i-1];
                exp_rgb_pipe[i] <= exp_rgb_pipe[i-1];
                exp_valid_pipe[i] <= exp_valid_pipe[i-1];
            end
        end
    end

    always @(posedge clk_100) begin
        if (!rst_vga && exp_valid_pipe[LATENCY]) begin
            check_signal(hsync_out === exp_hsync_pipe[LATENCY],
                         "hsync_out misaligned with pipeline");
            check_signal(vsync_out === exp_vsync_pipe[LATENCY],
                         "vsync_out misaligned with pipeline");
            check_signal(active_video_out === exp_active_pipe[LATENCY],
                         "active_video_out misaligned with pipeline");
            check_signal(rgb565_out === exp_rgb_pipe[LATENCY],
                         $sformatf("rgb mismatch exp=0x%04h got=0x%04h",
                                   exp_rgb_pipe[LATENCY], rgb565_out));
        end
    end

    initial begin
        $dumpfile("tb_vga_reader_bilinear.vcd");
        $dumpvars(0, tb_vga_reader_bilinear);
        
        errors = 0;

        repeat (4) @(posedge clk_100);
        rst_vga = 1'b0;

        enable_bilinear = 1'b0;
        present_pixel(10'd0, 10'd0, 1'b1, 1'b1, 1'b1);
        present_pixel(10'd1, 10'd0, 1'b1, 1'b0, 1'b1);
        present_pixel(10'd2, 10'd0, 1'b1, 1'b1, 1'b0);
        present_pixel(10'd3, 10'd1, 1'b1, 1'b1, 1'b1);
        present_pixel(10'd639, 10'd479, 1'b1, 1'b0, 1'b0);
        present_pixel(10'd700, 10'd500, 1'b0, 1'b1, 1'b1);

        enable_bilinear = 1'b1;
        present_pixel(10'd0, 10'd0, 1'b1, 1'b1, 1'b1);
        present_pixel(10'd1, 10'd0, 1'b1, 1'b0, 1'b1);
        present_pixel(10'd0, 10'd1, 1'b1, 1'b1, 1'b0);
        present_pixel(10'd1, 10'd1, 1'b1, 1'b1, 1'b1);
        present_pixel(10'd2, 10'd2, 1'b1, 1'b0, 1'b0);
        present_pixel(10'd639, 10'd479, 1'b1, 1'b1, 1'b1);
        present_pixel(10'd640, 10'd0, 1'b0, 1'b0, 1'b1);

        repeat (LATENCY + 4) @(posedge clk_100);

        if (errors == 0) begin
            $display("PASS: bilinear reader pipeline, bypass, and alignment verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_vga_reader_bilinear found %0d error(s).", errors);
    end

endmodule
