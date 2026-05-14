`timescale 1ns/1ps

// vga_timing_1280x960
// Purpose: generate standard 1280x960 @ 60 Hz VGA timing.
// Clock domain: 108 MHz VGA pixel clock, one output pixel per clk.
// Outputs: visible coordinates, full counters, active-video, and positive syncs.
// Assumption: clk is the 108 MHz selected VGA/read clock in 4x mode.
module vga_timing_1280x960 (
    input  wire        clk,
    input  wire        rst,
    output wire [10:0] vga_x,
    output wire [9:0]  vga_y,
    output wire        active_video,
    output wire        hsync,
    output wire        vsync,
    output wire [10:0] h_count,
    output wire [9:0]  v_count
);

    localparam [10:0] H_ACTIVE     = 11'd1280;
    localparam [10:0] H_FRONT      = 11'd96;
    localparam [10:0] H_SYNC       = 11'd112;
    localparam [10:0] H_BACK       = 11'd312;
    localparam [10:0] H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam [10:0] H_SYNC_START = H_ACTIVE + H_FRONT;
    localparam [10:0] H_SYNC_END   = H_SYNC_START + H_SYNC;

    localparam [9:0] V_ACTIVE     = 10'd960;
    localparam [9:0] V_FRONT      = 10'd1;
    localparam [9:0] V_SYNC       = 10'd3;
    localparam [9:0] V_BACK       = 10'd36;
    localparam [9:0] V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;
    localparam [9:0] V_SYNC_START = V_ACTIVE + V_FRONT;
    localparam [9:0] V_SYNC_END   = V_SYNC_START + V_SYNC;

    reg [10:0] h_count_reg = 11'd0;
    reg [9:0]  v_count_reg = 10'd0;

    always @(posedge clk) begin
        if (rst) begin
            h_count_reg <= 11'd0;
            v_count_reg <= 10'd0;
        end else if (h_count_reg == H_TOTAL - 11'd1) begin
            h_count_reg <= 11'd0;

            if (v_count_reg == V_TOTAL - 10'd1) begin
                v_count_reg <= 10'd0;
            end else begin
                v_count_reg <= v_count_reg + 1'b1;
            end
        end else begin
            h_count_reg <= h_count_reg + 1'b1;
        end
    end

    assign h_count = h_count_reg;
    assign v_count = v_count_reg;
    assign vga_x = h_count_reg;
    assign vga_y = v_count_reg;

    assign active_video = (h_count_reg < H_ACTIVE) && (v_count_reg < V_ACTIVE);
    assign hsync = (h_count_reg >= H_SYNC_START) && (h_count_reg < H_SYNC_END);
    assign vsync = (v_count_reg >= V_SYNC_START) && (v_count_reg < V_SYNC_END);

endmodule
