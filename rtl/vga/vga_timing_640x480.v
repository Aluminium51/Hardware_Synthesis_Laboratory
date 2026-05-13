`timescale 1ns/1ps

// vga_timing_640x480
//
// Purpose:
//   Generate standard 640x480 @ 60 Hz VGA timing.
//
// Clock domain:
//   clk_100, advanced by the 25 MHz pixel_ce strobe.
//
// Inputs:
//   clk_100  - system clock
//   pixel_ce - one-cycle enable for each VGA pixel
//   rst_vga  - active-high reset in the VGA/system domain
//
// Outputs:
//   hsync/vsync  - active-low VGA sync pulses
//   active_video - asserted during the visible 640x480 region
//   x/y          - current raster coordinate
//
// Assumption:
//   pixel_ce is one clk_100 cycle wide and pulses once per output pixel.
module vga_timing_640x480 (
    input  wire       clk_100,
    input  wire       pixel_ce,
    input  wire       rst_vga,
    output wire       hsync,
    output wire       vsync,
    output wire       active_video,
    output wire [9:0] x,
    output wire [9:0] y
);

    localparam H_ACTIVE     = 10'd640;
    localparam H_FRONT      = 10'd16;
    localparam H_SYNC       = 10'd96;
    localparam H_BACK       = 10'd48;
    localparam H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam H_SYNC_START = H_ACTIVE + H_FRONT;
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC;

    localparam V_ACTIVE     = 10'd480;
    localparam V_FRONT      = 10'd10;
    localparam V_SYNC       = 10'd2;
    localparam V_BACK       = 10'd33;
    localparam V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
    localparam V_SYNC_START = V_ACTIVE + V_FRONT;
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC;

    reg [9:0] h_count = 10'd0;
    reg [9:0] v_count = 10'd0;

    // Raster counters advance only on pixel_ce. Horizontal wrap increments the
    // vertical counter; vertical wrap returns to the top-left pixel.
    always @(posedge clk_100) begin
        if (rst_vga) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (pixel_ce && (h_count == H_TOTAL - 10'd1)) begin
            h_count <= 10'd0;

            if (v_count == V_TOTAL - 10'd1) begin
                v_count <= 10'd0;
            end else begin
                v_count <= v_count + 1'b1;
            end
        end else if (pixel_ce) begin
            h_count <= h_count + 1'b1;
        end
    end

    assign x = h_count;
    assign y = v_count;

    // Decode visible area and standard active-low sync windows directly from
    // the current raster count values.
    assign active_video = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign hsync = ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));
    assign vsync = ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));

endmodule
