`timescale 1ns/1ps

module tb_vga_timing_1280x960;

    localparam int H_ACTIVE     = 1280;
    localparam int H_FRONT      = 96;
    localparam int H_SYNC       = 112;
    localparam int H_BACK       = 312;
    localparam int H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam int H_SYNC_START = H_ACTIVE + H_FRONT;
    localparam int H_SYNC_END   = H_SYNC_START + H_SYNC;

    localparam int V_ACTIVE     = 960;
    localparam int V_FRONT      = 1;
    localparam int V_SYNC       = 3;
    localparam int V_BACK       = 36;
    localparam int V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
    localparam int V_SYNC_START = V_ACTIVE + V_FRONT;
    localparam int V_SYNC_END   = V_SYNC_START + V_SYNC;

    localparam int FRAME_PIXELS  = H_TOTAL * V_TOTAL;
    localparam int ACTIVE_PIXELS = H_ACTIVE * V_ACTIVE;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire [10:0] vga_x;
    wire [9:0]  vga_y;
    wire        active_video;
    wire        hsync;
    wire        vsync;
    wire [10:0] h_count;
    wire [9:0]  v_count;

    int exp_x;
    int exp_y;
    int pixel_index;
    int active_count;
    int hsync_count;
    int vsync_line_count;
    int errors;

    vga_timing_1280x960 dut (
        .clk          (clk),
        .rst          (rst),
        .vga_x        (vga_x),
        .vga_y        (vga_y),
        .active_video (active_video),
        .hsync        (hsync),
        .vsync        (vsync),
        .h_count      (h_count),
        .v_count      (v_count)
    );

    always #5 clk = ~clk;

    function automatic bit exp_active_video(input int h, input int v);
        exp_active_video = (h < H_ACTIVE) && (v < V_ACTIVE);
    endfunction

    function automatic bit exp_hsync(input int h);
        exp_hsync = (h >= H_SYNC_START) && (h < H_SYNC_END);
    endfunction

    function automatic bit exp_vsync(input int v);
        exp_vsync = (v >= V_SYNC_START) && (v < V_SYNC_END);
    endfunction

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR at h=%0d v=%0d time=%0t: %s", h_count, v_count, $time, message);
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

    initial begin
        exp_x = 0;
        exp_y = 0;
        active_count = 0;
        hsync_count = 0;
        vsync_line_count = 0;
        errors = 0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        for (pixel_index = 0; pixel_index < FRAME_PIXELS; pixel_index++) begin
            #1;
            check_signal(h_count == exp_x[10:0], "horizontal counter mismatch");
            check_signal(v_count == exp_y[9:0], "vertical counter mismatch");
            check_signal(vga_x == exp_x[10:0], "visible x mismatch");
            check_signal(vga_y == exp_y[9:0], "visible y mismatch");
            check_signal(active_video == exp_active_video(exp_x, exp_y), "active_video mismatch");
            check_signal(hsync == exp_hsync(exp_x), "hsync mismatch");
            check_signal(vsync == exp_vsync(exp_y), "vsync mismatch");

            if (exp_active_video(exp_x, exp_y)) begin
                active_count++;
            end
            if (exp_hsync(exp_x)) begin
                hsync_count++;
            end
            if ((exp_x == 0) && exp_vsync(exp_y)) begin
                vsync_line_count++;
            end

            @(posedge clk);
            advance_expected();
            @(negedge clk);
        end

        #1;
        check_signal(h_count == 11'd0, "horizontal counter did not wrap at frame end");
        check_signal(v_count == 10'd0, "vertical counter did not wrap at frame end");
        check_signal(active_count == ACTIVE_PIXELS, "active pixel count does not match 1280x960");
        check_signal(hsync_count == H_SYNC * V_TOTAL, "hsync pulse width/count mismatch");
        check_signal(vsync_line_count == V_SYNC, "vsync pulse line count mismatch");

        if (errors == 0) begin
            $display("PASS: 1280x960 timing counters, sync windows, and active region verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_vga_timing_1280x960 found %0d error(s).", errors);
    end

endmodule
