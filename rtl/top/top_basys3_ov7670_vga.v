`timescale 1ns/1ps

// top_basys3_ov7670_vga
// Purpose: TASK-001 VGA-only bring-up top for Basys 3.
// Clock domain: clk_100, with a 25 MHz pixel clock-enable for VGA timing.
// Outputs: VGA sync/RGB pins and simple LED debug.
// Assumption: 25 MHz pixel rate is acceptable for first monitor lock.
module top_basys3_ov7670_vga (
    input  wire        clk_100,
    input  wire        btnC,
    output wire        Hsync,
    output wire        Vsync,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire [3:0]  led
);

    wire rst_vga;

    reset_sync u_reset_sync (
        .clk       (clk_100),
        .rst_async (btnC),
        .rst_sync  (rst_vga)
    );

    reg [1:0] pixel_div = 2'd0;

    always @(posedge clk_100) begin
        if (rst_vga) begin
            pixel_div <= 2'd0;
        end else begin
            pixel_div <= pixel_div + 1'b1;
        end
    end

    wire pixel_ce = (pixel_div == 2'd3);

    wire       hsync_timing;
    wire       vsync_timing;
    wire       active_video;
    wire [9:0] x;
    wire [9:0] y;

    vga_timing_640x480 u_vga_timing (
        .clk_100      (clk_100),
        .pixel_ce     (pixel_ce),
        .rst_vga      (rst_vga),
        .hsync        (hsync_timing),
        .vsync        (vsync_timing),
        .active_video (active_video),
        .x            (x),
        .y            (y)
    );

    wire [11:0] pattern_rgb444;

    test_pattern u_test_pattern (
        .x            (x),
        .y            (y),
        .active_video (active_video && !rst_vga),
        .rgb444       (pattern_rgb444)
    );

    reg [25:0] heartbeat = 26'd0;

    always @(posedge clk_100) begin
        if (rst_vga) begin
            heartbeat <= 26'd0;
        end else begin
            heartbeat <= heartbeat + 1'b1;
        end
    end

    assign Hsync = hsync_timing;
    assign Vsync = vsync_timing;

    assign vgaRed   = pattern_rgb444[11:8];
    assign vgaGreen = pattern_rgb444[7:4];
    assign vgaBlue  = pattern_rgb444[3:0];

    assign led = {2'b00, rst_vga, heartbeat[25]};

endmodule
