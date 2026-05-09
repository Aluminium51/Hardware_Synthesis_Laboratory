`timescale 1ns/1ps

module tb_vga_reader_320x240;

    localparam [16:0] MAX_ADDR = 17'd76799;

    reg clk_100 = 1'b0;
    reg pixel_ce = 1'b0;
    reg rst_vga = 1'b1;

    reg [9:0]  vga_x = 10'd0;
    reg [9:0]  vga_y = 10'd0;
    reg        hsync_in = 1'b1;
    reg        vsync_in = 1'b1;
    reg        active_video_in = 1'b0;
    reg [15:0] rd_data = 16'h0000;

    wire [16:0] rd_addr;
    wire        hsync_out;
    wire        vsync_out;
    wire        active_video_out;
    wire [15:0] rgb565_out;

    int errors;

    vga_reader_320x240 dut (
        .clk_100          (clk_100),
        .pixel_ce         (pixel_ce),
        .rst_vga          (rst_vga),
        .vga_x            (vga_x),
        .vga_y            (vga_y),
        .hsync_in         (hsync_in),
        .vsync_in         (vsync_in),
        .active_video_in  (active_video_in),
        .rd_data          (rd_data),
        .rd_addr          (rd_addr),
        .hsync_out        (hsync_out),
        .vsync_out        (vsync_out),
        .active_video_out (active_video_out),
        .rgb565_out       (rgb565_out)
    );

    always #5 clk_100 = ~clk_100;

    function automatic [16:0] expected_addr(
        input [9:0] x_value,
        input [9:0] y_value,
        input       active_value
    );
        reg [8:0] src_x;
        reg [7:0] src_y;
        begin
            if (!active_value) begin
                expected_addr = 17'd0;
            end else begin
                src_x = x_value[9:1];
                src_y = y_value[8:1];
                expected_addr = {1'b0, src_y, 8'b0}
                              + {3'b000, src_y, 6'b0}
                              + {8'b00000000, src_x};
            end
        end
    endfunction

    function automatic [15:0] mem_word(input [16:0] addr);
        begin
            mem_word = {addr[15:0] ^ 16'h5a5a};
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
        input        vsync_value,
        input string label
    );
        reg [16:0] exp_addr;
        begin
            exp_addr = expected_addr(x_value, y_value, active_value);

            @(negedge clk_100);
            vga_x = x_value;
            vga_y = y_value;
            active_video_in = active_value;
            hsync_in = hsync_value;
            vsync_in = vsync_value;
            pixel_ce = 1'b1;

            @(posedge clk_100);
            #1;
            pixel_ce = 1'b0;

            repeat (3) @(posedge clk_100);

            check_signal(rd_addr == exp_addr,
                         $sformatf("%s rd_addr expected %0d got %0d",
                                   label, exp_addr, rd_addr));
            check_signal(rd_addr <= MAX_ADDR,
                         $sformatf("%s rd_addr exceeded framebuffer range: %0d",
                                   label, rd_addr));
        end
    endtask

    task automatic check_output_for_pixel(
        input [9:0]  x_value,
        input [9:0]  y_value,
        input        active_value,
        input        hsync_value,
        input        vsync_value,
        input string label
    );
        reg [16:0] exp_addr;
        reg [15:0] exp_rgb;
        begin
            exp_addr = expected_addr(x_value, y_value, active_value);
            exp_rgb = active_value ? mem_word(exp_addr) : 16'h0000;

            check_signal(active_video_out === active_value,
                         $sformatf("%s active_video_out misaligned", label));
            check_signal(hsync_out === hsync_value,
                         $sformatf("%s hsync_out misaligned", label));
            check_signal(vsync_out === vsync_value,
                         $sformatf("%s vsync_out misaligned", label));
            check_signal(rgb565_out === exp_rgb,
                         $sformatf("%s rgb expected 0x%04h got 0x%04h",
                                   label, exp_rgb, rgb565_out));
        end
    endtask

    initial begin
        errors = 0;

        repeat (3) @(posedge clk_100);
        rst_vga = 1'b0;
        repeat (2) @(posedge clk_100);

        present_pixel(10'd0, 10'd0, 1'b1, 1'b1, 1'b1, "(0,0)");
        check_signal(active_video_out === 1'b0, "pipeline should start blank");
        check_signal(rgb565_out === 16'h0000, "pipeline should start black");

        present_pixel(10'd1, 10'd0, 1'b1, 1'b0, 1'b1, "(1,0)");
        check_output_for_pixel(10'd0, 10'd0, 1'b1, 1'b1, 1'b1,
                               "output for (0,0)");

        present_pixel(10'd2, 10'd0, 1'b1, 1'b1, 1'b0, "(2,0)");
        check_output_for_pixel(10'd1, 10'd0, 1'b1, 1'b0, 1'b1,
                               "output for (1,0)");

        present_pixel(10'd10, 10'd10, 1'b1, 1'b1, 1'b1, "(10,10)");
        check_output_for_pixel(10'd2, 10'd0, 1'b1, 1'b1, 1'b0,
                               "output for (2,0)");

        present_pixel(10'd11, 10'd10, 1'b1, 1'b1, 1'b1, "(11,10)");
        check_output_for_pixel(10'd10, 10'd10, 1'b1, 1'b1, 1'b1,
                               "2x2 output for (10,10)");

        present_pixel(10'd10, 10'd11, 1'b1, 1'b1, 1'b1, "(10,11)");
        check_output_for_pixel(10'd11, 10'd10, 1'b1, 1'b1, 1'b1,
                               "2x2 output for (11,10)");

        present_pixel(10'd11, 10'd11, 1'b1, 1'b1, 1'b1, "(11,11)");
        check_output_for_pixel(10'd10, 10'd11, 1'b1, 1'b1, 1'b1,
                               "2x2 output for (10,11)");

        present_pixel(10'd639, 10'd479, 1'b1, 1'b0, 1'b0, "(639,479)");
        check_output_for_pixel(10'd11, 10'd11, 1'b1, 1'b1, 1'b1,
                               "2x2 output for (11,11)");

        present_pixel(10'd640, 10'd0, 1'b0, 1'b1, 1'b0, "blank x=640");
        check_output_for_pixel(10'd639, 10'd479, 1'b1, 1'b0, 1'b0,
                               "output for (639,479)");

        present_pixel(10'd700, 10'd500, 1'b0, 1'b0, 1'b1, "blank large coord");
        check_output_for_pixel(10'd640, 10'd0, 1'b0, 1'b1, 1'b0,
                               "blank output x=640");

        present_pixel(10'd0, 10'd0, 1'b1, 1'b1, 1'b1, "flush active");
        check_output_for_pixel(10'd700, 10'd500, 1'b0, 1'b0, 1'b1,
                               "blank output large coord");

        if (errors == 0) begin
            $display("PASS: VGA reader address mapping, 2x scaling, blanking, and control alignment verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_vga_reader_320x240 found %0d error(s).", errors);
    end

endmodule
