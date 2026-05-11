`timescale 1ns/1ps

// ov7670_capture_rgb565_linefifo
// Purpose: capture full-resolution OV7670 RGB565 pixels into a 4-bank line ring.
// Clock domain: camera pixel clock, pclk.
// Ports: camera sync/data inputs and write-side line-buffer control outputs.
// Assumptions: RGB565 bytes arrive MSB first; VSYNC is an active-high frame boundary.
module ov7670_capture_rgb565_linefifo #(
    parameter integer LINE_PIXELS = 640,
    parameter integer LINE_HEIGHT  = 480,
    parameter integer BANK_COUNT   = 4,
    parameter integer ADDR_WIDTH    = 10,
    parameter integer BANK_SEL_WIDTH = 2,
    parameter integer PTR_WIDTH     = 3
) (
    input  wire                     pclk,
    input  wire                     rst,
    input  wire                     vsync,
    input  wire                     href,
    input  wire [7:0]               cam_d,
    input  wire [PTR_WIDTH-1:0]     rd_gray_sync,
    output reg  [PTR_WIDTH-1:0]     wr_gray,
    output reg  [BANK_SEL_WIDTH-1:0] wr_bank,
    output reg  [ADDR_WIDTH-1:0]    wr_addr,
    output reg  [15:0]              wr_data,
    output reg                      wr_en,
    output reg                      frame_done,
    output reg                      frame_active,
    output reg                      overflow,
    output reg                      frame_drop,
    output reg  [35:0]              bank_line_y,
    output reg  [3:0]               bank_frame_start,
    output reg                      dbg_line_seen,
    output reg                      dbg_line_ge_width,
    output reg                      dbg_line_ge_width_plus_1,
    output reg                      dbg_line_ge_width_plus_extra
);

    localparam integer LINE_PIXELS_PLUS_1 = LINE_PIXELS + 1;
    localparam integer LINE_PIXELS_PLUS_EXTRA = LINE_PIXELS + 8;

    reg       vsync_d = 1'b0;
    reg       href_d = 1'b0;
    reg       byte_phase = 1'b0;
    reg [7:0] first_byte = 8'h00;
    reg [ADDR_WIDTH-1:0] line_x = {ADDR_WIDTH{1'b0}};
    reg [8:0] line_y = 9'd0;
    reg       line_active = 1'b0;
    reg       line_drop = 1'b0;
    reg       frame_has_pixel = 1'b0;
    reg       next_line_frame_start = 1'b0;
    reg [PTR_WIDTH-1:0] wr_bin = {PTR_WIDTH{1'b0}};

    function [PTR_WIDTH-1:0] bin2gray;
        input [PTR_WIDTH-1:0] value;
        begin
            bin2gray = (value >> 1) ^ value;
        end
    endfunction

    function [PTR_WIDTH-1:0] gray2bin;
        input [PTR_WIDTH-1:0] value;
        integer i;
        begin
            gray2bin[PTR_WIDTH-1] = value[PTR_WIDTH-1];
            for (i = PTR_WIDTH - 2; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ value[i];
            end
        end
    endfunction

    wire [PTR_WIDTH-1:0] wr_bin_next = wr_bin + 1'b1;
    wire [PTR_WIDTH-1:0] wr_gray_next = bin2gray(wr_bin_next);

    wire full = (wr_gray_next == {~rd_gray_sync[PTR_WIDTH-1:PTR_WIDTH-2],
                                  rd_gray_sync[PTR_WIDTH-3:0]});
    wire line_start = href && !href_d;
    wire line_end   = !href && href_d;
    wire vsync_rise = vsync && !vsync_d;

    always @(posedge pclk) begin
        if (rst) begin
            vsync_d      <= 1'b0;
            href_d       <= 1'b0;
            byte_phase   <= 1'b0;
            first_byte   <= 8'h00;
            line_x       <= {ADDR_WIDTH{1'b0}};
            line_y       <= 9'd0;
            line_active  <= 1'b0;
            line_drop    <= 1'b0;
            frame_has_pixel <= 1'b0;
            next_line_frame_start <= 1'b0;
            wr_bin       <= {PTR_WIDTH{1'b0}};
            wr_gray      <= {PTR_WIDTH{1'b0}};
            wr_bank      <= {BANK_SEL_WIDTH{1'b0}};
            wr_addr      <= {ADDR_WIDTH{1'b0}};
            wr_data      <= 16'h0000;
            wr_en        <= 1'b0;
            frame_done   <= 1'b0;
            frame_active <= 1'b0;
            overflow     <= 1'b0;
            frame_drop   <= 1'b0;
            bank_line_y   <= 36'd0;
            bank_frame_start <= 4'b0000;
            dbg_line_seen <= 1'b0;
            dbg_line_ge_width <= 1'b0;
            dbg_line_ge_width_plus_1 <= 1'b0;
            dbg_line_ge_width_plus_extra <= 1'b0;
        end else begin
            vsync_d    <= vsync;
            href_d     <= href;
            wr_en      <= 1'b0;
            frame_done <= 1'b0;
            frame_drop <= 1'b0;

            if (vsync) begin
                byte_phase  <= 1'b0;
                first_byte  <= 8'h00;
                line_x      <= {ADDR_WIDTH{1'b0}};
                line_y      <= 9'd0;
                line_active <= 1'b0;
                line_drop   <= 1'b0;

                if (vsync_rise) begin
                    frame_done     <= frame_has_pixel;
                    frame_has_pixel <= 1'b0;
                    frame_active   <= 1'b0;
                    next_line_frame_start <= 1'b1;
                    overflow       <= 1'b0;
                    dbg_line_seen  <= 1'b0;
                    dbg_line_ge_width <= 1'b0;
                    dbg_line_ge_width_plus_1 <= 1'b0;
                    dbg_line_ge_width_plus_extra <= 1'b0;
                end
            end else begin
                if (line_start) begin
                    line_active <= 1'b1;
                    line_drop   <= full;
                    line_x      <= {ADDR_WIDTH{1'b0}};
                    byte_phase  <= 1'b0;
                    first_byte  <= 8'h00;
                    wr_bank     <= wr_bin[BANK_SEL_WIDTH-1:0];
                    frame_active <= 1'b1;
                    if (full) begin
                        overflow <= 1'b1;
                    end
                end

                if (href) begin
                    if (!byte_phase) begin
                        first_byte <= cam_d;
                        byte_phase <= 1'b1;
                    end else begin
                        byte_phase <= 1'b0;

                        if (!line_drop) begin
                            if (line_x < LINE_PIXELS) begin
                                wr_en   <= 1'b1;
                                wr_addr <= line_x;
                                wr_data <= {first_byte, cam_d};
                                frame_has_pixel <= 1'b1;
                            end else begin
                                overflow <= 1'b1;
                            end

                            if (line_x != {ADDR_WIDTH{1'b1}}) begin
                                line_x <= line_x + 1'b1;
                            end
                        end
                    end
                end

                if (line_end && line_active) begin
                    line_active <= 1'b0;
                    byte_phase  <= 1'b0;
                    first_byte  <= 8'h00;

                    if (!line_drop) begin
                        dbg_line_seen <= 1'b1;
                        if (line_x >= LINE_PIXELS) begin
                            dbg_line_ge_width <= 1'b1;
                        end
                        if (line_x >= LINE_PIXELS_PLUS_1) begin
                            dbg_line_ge_width_plus_1 <= 1'b1;
                        end
                        if (line_x >= LINE_PIXELS_PLUS_EXTRA) begin
                            dbg_line_ge_width_plus_extra <= 1'b1;
                        end

                        case (wr_bin[BANK_SEL_WIDTH-1:0])
                            2'd0: begin
                                bank_line_y[8:0] <= line_y;
                                bank_frame_start[0] <= next_line_frame_start;
                            end
                            2'd1: begin
                                bank_line_y[17:9] <= line_y;
                                bank_frame_start[1] <= next_line_frame_start;
                            end
                            2'd2: begin
                                bank_line_y[26:18] <= line_y;
                                bank_frame_start[2] <= next_line_frame_start;
                            end
                            default: begin
                                bank_line_y[35:27] <= line_y;
                                bank_frame_start[3] <= next_line_frame_start;
                            end
                        endcase
                        next_line_frame_start <= 1'b0;
                        wr_bin  <= wr_bin_next;
                        wr_gray <= wr_gray_next;
                        wr_bank <= wr_bin_next[BANK_SEL_WIDTH-1:0];
                    end else begin
                        frame_drop <= 1'b1;
                    end

                    if (line_y != 9'd479) begin
                        line_y <= line_y + 1'b1;
                    end
                end
            end
        end
    end

endmodule
