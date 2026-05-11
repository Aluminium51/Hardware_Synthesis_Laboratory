`timescale 1ns/1ps

// vga_reader_linefifo
// Purpose: map 640x480 VGA coordinates to one of the line-ring banks and stream RGB565 pixels.
// Clock domain: clk_100, advanced only on pixel_ce.
// Outputs: selected bank index, per-line framebuffer address, delayed sync/control/RGB.
// Assumption: rd_data is valid one pixel_ce step after rd_addr is presented.
module vga_reader_linefifo #(
    parameter integer LINE_PIXELS = 640,
    parameter integer BANK_COUNT   = 4,
    parameter integer BANK_SEL_WIDTH = 2,
    parameter integer PTR_WIDTH     = 3,
    parameter integer ADDR_WIDTH    = 10,
    parameter integer MIN_PREFILL_LINES = 2
) (
    input  wire                     clk_100,
    input  wire                     pixel_ce,
    input  wire                     rst_vga,
    input  wire [9:0]               vga_x,
    input  wire [9:0]               vga_y,
    input  wire                     hsync_in,
    input  wire                     vsync_in,
    input  wire                     active_video_in,
    input  wire                     frame_sync,
    input  wire [PTR_WIDTH-1:0]     wr_gray_sync,
    input  wire [35:0]              bank_line_y,
    input  wire [3:0]               bank_frame_start,
    input  wire [15:0]              rd_data,
    output reg  [PTR_WIDTH-1:0]     rd_gray,
    output reg  [BANK_SEL_WIDTH-1:0] rd_bank,
    output reg  [ADDR_WIDTH-1:0]    rd_addr,
    output reg                      rd_en,
    output reg                      hsync_out,
    output reg                      vsync_out,
    output reg                      active_video_out,
    output reg  [15:0]              rgb565_out,
    output reg                      underflow,
    output reg                      line_repeat_event,
    output reg                      line_drop_event,
    output reg                      frame_wrap_event,
    output reg                      seam_active_event,
    output reg                      vblank_repeat_event,
    output reg                      vblank_drop_event,
    output reg                      frame_resync_event,
    output wire [PTR_WIDTH-1:0]     lines_available_dbg,
    output wire                     stream_ready_dbg
);

    reg active_video_pipe = 1'b0;
    reg hsync_pipe = 1'b1;
    reg vsync_pipe = 1'b1;
    reg [PTR_WIDTH-1:0] rd_bin = {PTR_WIDTH{1'b0}};
    reg line_has_bank = 1'b0;
    reg line_repeat_hold = 1'b0;
    reg line_drop_after = 1'b0;
    reg vblank_repeat_pending = 1'b0;
    reg frame_realign_pending = 1'b0;
    reg displayed_line_valid = 1'b0;
    reg [8:0] last_displayed_line_y = 9'd0;
    reg stream_ready = 1'b0;
    localparam [PTR_WIDTH-1:0] MIN_PREFILL_VALUE = MIN_PREFILL_LINES;
    localparam [PTR_WIDTH-1:0] LOW_WATER_VALUE = {{(PTR_WIDTH-1){1'b0}}, 1'b1};
    localparam [PTR_WIDTH-1:0] HIGH_WATER_VALUE = BANK_COUNT - 1;

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

    wire [PTR_WIDTH-1:0] wr_bin_sync = gray2bin(wr_gray_sync);
    wire [PTR_WIDTH-1:0] lines_available = wr_bin_sync - rd_bin;
    wire empty = (lines_available == {PTR_WIDTH{1'b0}});
    wire line_begin = active_video_in && !active_video_pipe;
    wire line_end   = !active_video_in && active_video_pipe;
    wire enough_prefill = (lines_available >= MIN_PREFILL_VALUE);
    wire have_line  = stream_ready ? !empty : enough_prefill;
    wire should_repeat_line = stream_ready && vblank_repeat_pending;
    wire should_drop_line = 1'b0;
    wire vblank_line_tick = !active_video_in && (vga_y >= 10'd480) && (vga_x == 10'd0);
    wire [BANK_SEL_WIDTH-1:0] next_rd_bank = rd_bin[BANK_SEL_WIDTH-1:0];
    reg [8:0] next_line_y;
    reg       next_frame_start;
    assign lines_available_dbg = lines_available;
    assign stream_ready_dbg = stream_ready;

    always @* begin
        case (next_rd_bank)
            2'd0: begin
                next_line_y = bank_line_y[8:0];
                next_frame_start = bank_frame_start[0];
            end
            2'd1: begin
                next_line_y = bank_line_y[17:9];
                next_frame_start = bank_frame_start[1];
            end
            2'd2: begin
                next_line_y = bank_line_y[26:18];
                next_frame_start = bank_frame_start[2];
            end
            default: begin
                next_line_y = bank_line_y[35:27];
                next_frame_start = bank_frame_start[3];
            end
        endcase
    end

    always @(posedge clk_100) begin
        if (rst_vga) begin
            active_video_pipe <= 1'b0;
            hsync_pipe        <= 1'b1;
            vsync_pipe        <= 1'b1;
            hsync_out         <= 1'b1;
            vsync_out         <= 1'b1;
            active_video_out  <= 1'b0;
            rgb565_out        <= 16'h0000;
            rd_bin            <= {PTR_WIDTH{1'b0}};
            rd_gray           <= {PTR_WIDTH{1'b0}};
            rd_bank           <= {BANK_SEL_WIDTH{1'b0}};
            rd_addr           <= {ADDR_WIDTH{1'b0}};
            rd_en             <= 1'b0;
            line_has_bank     <= 1'b0;
            line_repeat_hold  <= 1'b0;
            line_drop_after   <= 1'b0;
            vblank_repeat_pending <= 1'b0;
            displayed_line_valid <= 1'b0;
            last_displayed_line_y <= 9'd0;
            stream_ready      <= 1'b0;
            underflow         <= 1'b0;
            line_repeat_event <= 1'b0;
            line_drop_event   <= 1'b0;
            frame_wrap_event  <= 1'b0;
            seam_active_event <= 1'b0;
            vblank_repeat_event <= 1'b0;
            vblank_drop_event <= 1'b0;
            frame_resync_event <= 1'b0;
        end else if (pixel_ce) begin
            rd_en             <= 1'b0;
            line_repeat_event <= 1'b0;
            line_drop_event   <= 1'b0;
            frame_wrap_event  <= 1'b0;
            seam_active_event <= 1'b0;
            vblank_repeat_event <= 1'b0;
            vblank_drop_event <= 1'b0;
            frame_resync_event <= 1'b0;

            if (frame_sync && !stream_ready) begin
                line_has_bank    <= 1'b0;
                line_repeat_hold <= 1'b0;
                line_drop_after  <= 1'b0;
                frame_realign_pending <= 1'b0;
            end else if (frame_sync && stream_ready) begin
                frame_realign_pending <= 1'b1;
                if (vblank_line_tick && (lines_available >= MIN_PREFILL_VALUE)) begin
                    rd_bin  <= wr_bin_sync - MIN_PREFILL_VALUE;
                    rd_gray <= bin2gray(wr_bin_sync - MIN_PREFILL_VALUE);
                    line_has_bank    <= 1'b0;
                    line_repeat_hold <= 1'b0;
                    line_drop_after  <= 1'b0;
                    vblank_repeat_pending <= 1'b0;
                    displayed_line_valid <= 1'b0;
                    frame_realign_pending <= 1'b0;
                    frame_resync_event <= 1'b1;
                end
            end else if (vblank_line_tick && stream_ready) begin
                if (frame_realign_pending && (lines_available >= MIN_PREFILL_VALUE)) begin
                    rd_bin  <= wr_bin_sync - MIN_PREFILL_VALUE;
                    rd_gray <= bin2gray(wr_bin_sync - MIN_PREFILL_VALUE);
                    line_has_bank    <= 1'b0;
                    line_repeat_hold <= 1'b0;
                    line_drop_after  <= 1'b0;
                    vblank_repeat_pending <= 1'b0;
                    displayed_line_valid <= 1'b0;
                    frame_realign_pending <= 1'b0;
                    frame_resync_event <= 1'b1;
                end else if (lines_available >= HIGH_WATER_VALUE) begin
                    rd_bin  <= rd_bin + 1'b1;
                    rd_gray <= bin2gray(rd_bin + 1'b1);
                    line_drop_event <= 1'b1;
                    vblank_drop_event <= 1'b1;
                end else if (lines_available <= LOW_WATER_VALUE) begin
                    vblank_repeat_pending <= 1'b1;
                    line_repeat_event <= 1'b1;
                    vblank_repeat_event <= 1'b1;
                end
            end else if (line_begin) begin
                line_has_bank    <= have_line;
                line_repeat_hold <= have_line && should_repeat_line;
                line_drop_after  <= have_line && !should_repeat_line && should_drop_line;
                rd_bank          <= rd_bin[BANK_SEL_WIDTH-1:0];
                if (have_line) begin
                    stream_ready <= 1'b1;
                    if (displayed_line_valid && next_frame_start) begin
                        frame_wrap_event <= 1'b1;
                        seam_active_event <= 1'b1;
                    end
                    last_displayed_line_y <= next_line_y;
                    displayed_line_valid <= 1'b1;
                    if (vblank_repeat_pending) begin
                        vblank_repeat_pending <= 1'b0;
                    end
                end else begin
                    underflow <= 1'b1;
                    stream_ready <= 1'b0;
                    displayed_line_valid <= 1'b0;
                end
            end

            if (active_video_in && (line_has_bank || (line_begin && have_line))) begin
                rd_en   <= 1'b1;
                rd_addr <= vga_x[ADDR_WIDTH-1:0];
            end else begin
                rd_addr <= {ADDR_WIDTH{1'b0}};
            end

            hsync_pipe        <= hsync_in;
            vsync_pipe        <= vsync_in;
            active_video_pipe <= active_video_in;
            hsync_out         <= hsync_pipe;
            vsync_out         <= vsync_pipe;
            active_video_out  <= active_video_pipe && line_has_bank;
            rgb565_out        <= (active_video_pipe && line_has_bank) ? rd_data : 16'h0000;

            if (line_end) begin
                if (line_has_bank) begin
                    if (line_repeat_hold) begin
                        line_repeat_event <= 1'b1;
                    end else if (line_drop_after) begin
                        rd_bin         <= rd_bin + 2'd2;
                        rd_gray        <= bin2gray(rd_bin + 2'd2);
                        line_drop_event <= 1'b1;
                    end else begin
                        rd_bin  <= rd_bin + 1'b1;
                        rd_gray <= bin2gray(rd_bin + 1'b1);
                    end
                end
                line_has_bank    <= 1'b0;
                line_repeat_hold <= 1'b0;
                line_drop_after  <= 1'b0;
            end
        end
    end

endmodule
