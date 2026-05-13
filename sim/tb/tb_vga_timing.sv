`timescale 1ns/1ps

module tb_vga_timing;

    localparam int H_ACTIVE     = 640;
    localparam int H_FRONT      = 16;
    localparam int H_SYNC       = 96;
    localparam int H_BACK       = 48;
    localparam int H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam int H_SYNC_START = H_ACTIVE + H_FRONT;
    localparam int H_SYNC_END   = H_SYNC_START + H_SYNC;

    localparam int V_ACTIVE     = 480;
    localparam int V_FRONT      = 10;
    localparam int V_SYNC       = 2;
    localparam int V_BACK       = 33;
    localparam int V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
    localparam int V_SYNC_START = V_ACTIVE + V_FRONT;
    localparam int V_SYNC_END   = V_SYNC_START + V_SYNC;

    localparam int FRAME_PIXELS  = H_TOTAL * V_TOTAL;
    localparam int ACTIVE_PIXELS = H_ACTIVE * V_ACTIVE;

    reg clk_100  = 1'b0;
    reg pixel_ce = 1'b0;
    reg rst_vga = 1'b1;

    wire       hsync;
    wire       vsync;
    wire       active_video;
    wire [9:0] x;
    wire [9:0] y;

    int exp_x;
    int exp_y;
    int pixel_index;
    int active_count;
    int errors;

    vga_timing_640x480 dut (
        .clk_100      (clk_100),
        .pixel_ce     (pixel_ce),
        .rst_vga      (rst_vga),
        .hsync        (hsync),
        .vsync        (vsync),
        .active_video (active_video),
        .x            (x),
        .y            (y)
    );

    always #5 clk_100 = ~clk_100;

    function automatic bit exp_active_video(input int h, input int v);
        exp_active_video = (h < H_ACTIVE) && (v < V_ACTIVE);
    endfunction

    function automatic bit exp_hsync(input int h);
        exp_hsync = !((h >= H_SYNC_START) && (h < H_SYNC_END));
    endfunction

    function automatic bit exp_vsync(input int v);
        exp_vsync = !((v >= V_SYNC_START) && (v < V_SYNC_END));
    endfunction

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR at x=%0d y=%0d time=%0t: %s", x, y, $time, message);
            end
        end
    endtask

    task automatic advance_expected;
        begin
            if (exp_x == H_TOTAL - 1) begin
                exp_x = 0;

                if (exp_y == V_TOTAL - 1) begin
                    exp_y = 0;
                end else begin
                    exp_y++;
                end
            end else begin
                exp_x++;
            end
        end
    endtask

    task automatic pulse_pixel;
        begin
            pixel_ce = 1'b1;
            @(negedge clk_100);
            pixel_ce = 1'b0;
            advance_expected();
        end
    endtask

    initial begin
        $dumpfile("tb_vga_timing.vcd");
        $dumpvars(0, tb_vga_timing);
        
        exp_x = 0;
        exp_y = 0;
        active_count = 0;
        errors = 0;

        repeat (3) @(posedge clk_100);
        @(negedge clk_100);
        rst_vga = 1'b0;

        for (pixel_index = 0; pixel_index < FRAME_PIXELS; pixel_index++) begin
            @(negedge clk_100);

            check_signal(x == exp_x[9:0], "horizontal counter mismatch");
            check_signal(y == exp_y[9:0], "vertical counter mismatch");
            check_signal(active_video == exp_active_video(exp_x, exp_y),
                         "active_video mismatch");
            check_signal(hsync == exp_hsync(exp_x), "hsync mismatch");
            check_signal(vsync == exp_vsync(exp_y), "vsync mismatch");

            if (exp_active_video(exp_x, exp_y)) begin
                active_count++;
            end

            pulse_pixel();
        end

        @(negedge clk_100);
        check_signal(x == 10'd0, "horizontal counter did not wrap at frame end");
        check_signal(y == 10'd0, "vertical counter did not wrap at frame end");
        check_signal(active_count == ACTIVE_PIXELS,
                     "active pixel count does not match 640x480");

        if (errors == 0) begin
            $display("PASS: VGA timing counters, sync windows, and active region verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_vga_timing found %0d error(s).", errors);
    end

endmodule
