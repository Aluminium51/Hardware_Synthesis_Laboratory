`timescale 1ns/1ps

// top_basys3_ov7670_vga
// Purpose: TASK-002 framebuffer-backed VGA display bring-up for Basys 3.
// Clock domain: clk_100, with a 25 MHz pixel clock-enable for VGA timing.
// Outputs: VGA sync/RGB pins and simple LED debug.
// Assumption: runtime framebuffer fill completes before hardware observation matters.
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

    localparam [16:0] FRAME_LAST_ADDR = 17'd76799;

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

    reg [16:0] fill_addr = 17'd0;
    reg [5:0]  fill_col_in_band = 6'd0;
    reg [4:0]  fill_row_in_grid = 5'd0;
    reg [2:0]  fill_band = 3'd0;
    reg        fill_done = 1'b0;

    wire fill_end_of_band = (fill_col_in_band == 6'd39);
    wire fill_end_of_row  = fill_end_of_band && (fill_band == 3'd7);

    function [11:0] fill_pattern_rgb444;
        input [2:0] band;
        input [5:0] col_in_band;
        input [4:0] row_in_grid;
        begin
            if ((col_in_band == 6'd0) || (row_in_grid == 5'd0)) begin
                fill_pattern_rgb444 = 12'h000;
            end else begin
                case (band)
                    3'd0: fill_pattern_rgb444 = 12'hfff;
                    3'd1: fill_pattern_rgb444 = 12'hff0;
                    3'd2: fill_pattern_rgb444 = 12'h0ff;
                    3'd3: fill_pattern_rgb444 = 12'h0f0;
                    3'd4: fill_pattern_rgb444 = 12'hf0f;
                    3'd5: fill_pattern_rgb444 = 12'hf00;
                    3'd6: fill_pattern_rgb444 = 12'h00f;
                    default: fill_pattern_rgb444 = 12'h888;
                endcase
            end
        end
    endfunction

    wire [11:0] fill_rgb444 = fill_pattern_rgb444(
        fill_band,
        fill_col_in_band,
        fill_row_in_grid
    );

    wire fb_wr_en = !rst_vga && !fill_done;

    always @(posedge clk_100) begin
        if (rst_vga) begin
            fill_addr        <= 17'd0;
            fill_col_in_band <= 6'd0;
            fill_row_in_grid <= 5'd0;
            fill_band        <= 3'd0;
            fill_done        <= 1'b0;
        end else if (!fill_done) begin
            if (fill_addr == FRAME_LAST_ADDR) begin
                fill_done <= 1'b1;
            end else begin
                fill_addr <= fill_addr + 1'b1;
            end

            if (fill_end_of_row) begin
                fill_col_in_band <= 6'd0;
                fill_band        <= 3'd0;

                if (fill_row_in_grid == 5'd29) begin
                    fill_row_in_grid <= 5'd0;
                end else begin
                    fill_row_in_grid <= fill_row_in_grid + 1'b1;
                end
            end else if (fill_end_of_band) begin
                fill_col_in_band <= 6'd0;
                fill_band        <= fill_band + 1'b1;
            end else begin
                fill_col_in_band <= fill_col_in_band + 1'b1;
            end
        end
    end

    wire [16:0] fb_rd_addr;
    wire [11:0] fb_rd_data;

    framebuffer_bram u_framebuffer (
        .wr_clk  (clk_100),
        .wr_en   (fb_wr_en),
        .wr_addr (fill_addr),
        .wr_data (fill_rgb444),
        .rd_clk  (clk_100),
        .rd_addr (fb_rd_addr),
        .rd_data (fb_rd_data)
    );

    wire        hsync_reader;
    wire        vsync_reader;
    wire        active_video_reader;
    wire [11:0] reader_rgb444;

    vga_reader_320x240 u_vga_reader (
        .clk_100          (clk_100),
        .pixel_ce         (pixel_ce),
        .rst_vga          (rst_vga),
        .vga_x            (x),
        .vga_y            (y),
        .hsync_in         (hsync_timing),
        .vsync_in         (vsync_timing),
        .active_video_in  (active_video),
        .rd_data          (fb_rd_data),
        .rd_addr          (fb_rd_addr),
        .hsync_out        (hsync_reader),
        .vsync_out        (vsync_reader),
        .active_video_out (active_video_reader),
        .rgb444_out       (reader_rgb444)
    );

    wire [11:0] display_rgb444 = fill_done ? reader_rgb444 : 12'h000;

    reg [25:0] heartbeat = 26'd0;

    always @(posedge clk_100) begin
        if (rst_vga) begin
            heartbeat <= 26'd0;
        end else begin
            heartbeat <= heartbeat + 1'b1;
        end
    end

    assign Hsync = hsync_reader;
    assign Vsync = vsync_reader;

    assign vgaRed   = display_rgb444[11:8];
    assign vgaGreen = display_rgb444[7:4];
    assign vgaBlue  = display_rgb444[3:0];

    assign led = {1'b0, fill_done, rst_vga, heartbeat[25]};

endmodule
