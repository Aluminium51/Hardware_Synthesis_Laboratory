`timescale 1ns/1ps

module tb_top_vga_mode_select;

    reg clk_100 = 1'b0;
    reg btnC = 1'b1;
    reg btnU = 1'b0;
    reg btnD = 1'b0;
    reg [9:0] sw = 10'd0;
    reg cam_pclk = 1'b0;
    reg cam_vsync = 1'b0;
    reg cam_href = 1'b0;
    reg [7:0] cam_d = 8'h00;

    wire Hsync;
    wire Vsync;
    wire [3:0] vgaRed;
    wire [3:0] vgaGreen;
    wire [3:0] vgaBlue;
    wire cam_xclk;
    wire cam_sioc;
    wire cam_siod;
    wire cam_pwdn;
    wire cam_reset;
    wire [3:0] led;

    int errors;

    top_basys3_ov7670_vga dut (
        .clk_100   (clk_100),
        .btnC      (btnC),
        .btnU      (btnU),
        .btnD      (btnD),
        .sw        (sw),
        .Hsync     (Hsync),
        .Vsync     (Vsync),
        .vgaRed    (vgaRed),
        .vgaGreen  (vgaGreen),
        .vgaBlue   (vgaBlue),
        .cam_xclk  (cam_xclk),
        .cam_pclk  (cam_pclk),
        .cam_vsync (cam_vsync),
        .cam_href  (cam_href),
        .cam_d     (cam_d),
        .cam_sioc  (cam_sioc),
        .cam_siod  (cam_siod),
        .cam_pwdn  (cam_pwdn),
        .cam_reset (cam_reset),
        .led       (led)
    );

    always #5 clk_100 = ~clk_100;
    always #20 cam_pclk = ~cam_pclk;

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t: %s", $time, message);
            end
        end
    endtask

    task automatic apply_reset_with_mode(input bit mode_4x);
        begin
            @(negedge clk_100);
            sw[9] = mode_4x;
            btnC = 1'b1;
            repeat (5) @(posedge clk_100);
            @(negedge clk_100);
            btnC = 1'b0;
            repeat (8) @(posedge clk_100);
        end
    endtask

    initial begin
        errors = 0;

        apply_reset_with_mode(1'b0);
        check_signal(dut.mode_4x_latched == 1'b0, "sw[9]=0 during reset did not select 2x mode");
        check_signal(dut.enable_2x == 1'b1, "enable_2x should be high in 2x mode");
        check_signal(dut.enable_4x == 1'b0, "enable_4x should be low in 2x mode");

        @(negedge clk_100);
        sw[9] = 1'b1;
        repeat (8) @(posedge clk_100);
        check_signal(dut.mode_4x_latched == 1'b0, "sw[9] changed mode without reset");

        apply_reset_with_mode(1'b1);
        check_signal(dut.mode_4x_latched == 1'b1, "sw[9]=1 during reset did not select 4x mode");
        check_signal(dut.enable_2x == 1'b0, "enable_2x should be low in 4x mode");
        check_signal(dut.enable_4x == 1'b1, "enable_4x should be high in 4x mode");

        @(negedge clk_100);
        sw[9] = 1'b0;
        repeat (8) @(posedge clk_100);
        check_signal(dut.mode_4x_latched == 1'b1, "sw[9] cleared mode without reset");

        apply_reset_with_mode(1'b0);
        check_signal(dut.mode_4x_latched == 1'b0, "second reset did not return to 2x mode");

        if (errors == 0) begin
            $display("PASS: reset-time VGA mode selection verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_top_vga_mode_select found %0d error(s).", errors);
    end

endmodule
