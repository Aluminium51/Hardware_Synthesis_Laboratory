`timescale 1ns/1ps

// face_detect
// Streaming 24x24 face-detection engine with:
// - grayscale conversion from RGB565
// - 24-row line buffer ring for 320-pixel rows
// - local 24x24 integral image snapshot
// - ROM-driven FSM for a compact Haar-cascade style evaluator
//
// ROM word format (32-bit, compact scaffold):
//   addr 0   : unused / header
//   stage hdr: [15:8] = feature_count, [7:0] = stage_vote_threshold
//   feature hdr: [31:16] = weak_threshold (signed 16-bit)
//   rect word : [31:27] x, [26:22] y, [21:17] w, [16:12] h, [11:4] weight, [3:0] reserved
// Each feature uses two rectangle words.
module face_detect (
    input  wire        clk,
    input  wire        rst,
    input  wire        pixel_valid,
    input  wire [9:0]  px_x,
    input  wire [9:0]  px_y,
    input  wire [15:0] rgb565_in,
    output reg         face_found,
    output reg [9:0]   face_x,
    output reg [9:0]   face_y,
    output reg [7:0]   rom_addr,
    input  wire [31:0] rom_data
);

    localparam integer WINDOW_SIZE = 24;
    localparam integer LINE_WIDTH   = 320;
    localparam integer LINE_DEPTH   = 24;
    localparam integer STAGE_COUNT  = 8;

    localparam [2:0] S_IDLE        = 3'd0;
    localparam [2:0] S_STAGE_HDR   = 3'd1;
    localparam [2:0] S_FEAT_HDR    = 3'd2;
    localparam [2:0] S_RECT1       = 3'd3;
    localparam [2:0] S_RECT2       = 3'd4;
    localparam [2:0] S_STAGE_CHECK = 3'd5;

    reg [2:0] state = S_IDLE;
    reg       busy = 1'b0;

    reg [7:0]  stage_idx = 8'd0;
    reg [7:0]  feature_idx = 8'd0;
    reg [7:0]  stage_feature_count = 8'd0;
    reg [7:0]  stage_vote_threshold = 8'd0;
    reg [7:0]  stage_score = 8'd0;
    reg signed [15:0] feature_weak_threshold = 16'sd0;
    reg [31:0] rect1_word = 32'd0;

    reg [4:0] row_ptr = 5'd23;
    reg [9:0] cand_x = 10'd0;
    reg [9:0] cand_y = 10'd0;

    reg [7:0] linebuf [0:LINE_DEPTH-1][0:LINE_WIDTH-1];
    reg [19:0] win_ii  [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
    reg [19:0] cand_ii [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];

    integer r;
    integer c;
    integer src_x;
    integer src_row;
    integer x2;
    integer y2;
    integer temp_row;
    integer temp_col;
    integer accum_x;
    integer accum_y;

    wire line_start = pixel_valid && (px_x == 10'd0);
    wire [4:0] next_row_ptr = (row_ptr == 5'd23) ? 5'd0 : (row_ptr + 5'd1);
    wire [4:0] write_row_ptr = line_start ? next_row_ptr : row_ptr;
    wire       window_valid = pixel_valid && (px_x >= 10'd23) && (px_y >= 10'd23);
    wire [7:0] grayscale_y = (({3'b000, rgb565_in[15:11]} >> 2)
                           +  ({2'b00,  rgb565_in[10:5]}  >> 1)
                           +  ({3'b000, rgb565_in[4:0]}   >> 3));

    function [4:0] ring_sub;
        input [4:0] base;
        input [4:0] delta;
        begin
            if (base >= delta) begin
                ring_sub = base - delta;
            end else begin
                ring_sub = base + 5'd24 - delta;
            end
        end
    endfunction

    function signed [31:0] scale_by_weight;
        input signed [31:0] value;
        input [7:0] weight;
        reg [7:0] abs_weight;
        integer k;
        reg signed [31:0] accum;
        begin
            abs_weight = weight[7] ? (~weight + 8'd1) : weight;
            accum = 32'sd0;
            for (k = 0; k < 8; k = k + 1) begin
                if (abs_weight[k]) begin
                    accum = accum + (value <<< k);
                end
            end
            scale_by_weight = weight[7] ? -accum : accum;
        end
    endfunction

    function signed [31:0] rect_sum;
        input [31:0] rect_word;
        integer rx;
        integer ry;
        integer rw;
        integer rh;
        integer rx2;
        integer ry2;
        reg signed [31:0] sum;
        begin
            rx = rect_word[31:27];
            ry = rect_word[26:22];
            rw = rect_word[21:17];
            rh = rect_word[16:12];

            if ((rw == 0) || (rh == 0)) begin
                rect_sum = 32'sd0;
            end else begin
                rx2 = rx + rw - 1;
                ry2 = ry + rh - 1;

                if ((rx2 >= WINDOW_SIZE) || (ry2 >= WINDOW_SIZE)) begin
                    rect_sum = 32'sd0;
                end else begin
                    sum = $signed(cand_ii[ry2][rx2]);

                    if (rx > 0) begin
                        sum = sum - $signed(cand_ii[ry2][rx - 1]);
                    end
                    if (ry > 0) begin
                        sum = sum - $signed(cand_ii[ry - 1][rx2]);
                    end
                    if ((rx > 0) && (ry > 0)) begin
                        sum = sum + $signed(cand_ii[ry - 1][rx - 1]);
                    end

                    rect_sum = sum;
                end
            end
        end
    endfunction

    function signed [31:0] feature_response;
        input [31:0] feature_rect_a;
        input [31:0] feature_rect_b;
        reg signed [31:0] rect_a_scaled;
        reg signed [31:0] rect_b_scaled;
        begin
            rect_a_scaled = scale_by_weight(rect_sum(feature_rect_a), feature_rect_a[11:4]);
            rect_b_scaled = scale_by_weight(rect_sum(feature_rect_b), feature_rect_b[11:4]);
            feature_response = rect_a_scaled + rect_b_scaled;
        end
    endfunction

    always @* begin
        for (r = 0; r < WINDOW_SIZE; r = r + 1) begin
            for (c = 0; c < WINDOW_SIZE; c = c + 1) begin
                win_ii[r][c] = 20'd0;
            end
        end

        if (window_valid) begin
            for (r = 0; r < WINDOW_SIZE; r = r + 1) begin
                for (c = 0; c < WINDOW_SIZE; c = c + 1) begin
                    temp_row = ring_sub(row_ptr, 5'd23 - r);
                    src_x = px_x - (WINDOW_SIZE - 1 - c);

                    if ((r == WINDOW_SIZE - 1) && (c == WINDOW_SIZE - 1)) begin
                        win_ii[r][c] = 20'd0 + grayscale_y;
                    end else begin
                        // Build a 24x24 integral image over the current window.
                        // The line buffers hold the last 24 rows; the window is the
                        // 24x24 trailing block ending at (px_x, px_y).
                        if ((r == 0) && (c == 0)) begin
                            win_ii[r][c] = linebuf[temp_row][src_x];
                        end else if (r == 0) begin
                            win_ii[r][c] = linebuf[temp_row][src_x] + win_ii[r][c - 1];
                        end else if (c == 0) begin
                            win_ii[r][c] = linebuf[temp_row][src_x] + win_ii[r - 1][c];
                        end else begin
                            win_ii[r][c] = linebuf[temp_row][src_x]
                                         + win_ii[r - 1][c]
                                         + win_ii[r][c - 1]
                                         - win_ii[r - 1][c - 1];
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            row_ptr <= 5'd23;
            busy <= 1'b0;
            state <= S_IDLE;
            rom_addr <= 8'd1;
            stage_idx <= 8'd0;
            feature_idx <= 8'd0;
            stage_feature_count <= 8'd0;
            stage_vote_threshold <= 8'd0;
            stage_score <= 8'd0;
            feature_weak_threshold <= 16'sd0;
            rect1_word <= 32'd0;
            cand_x <= 10'd0;
            cand_y <= 10'd0;
            face_found <= 1'b0;
            face_x <= 10'd0;
            face_y <= 10'd0;
        end else begin
            face_found <= 1'b0;

            if (pixel_valid) begin
                if (line_start) begin
                    row_ptr <= next_row_ptr;
                end
                linebuf[write_row_ptr][px_x] <= grayscale_y;
            end

            if (window_valid && !busy) begin
                for (r = 0; r < WINDOW_SIZE; r = r + 1) begin
                    for (c = 0; c < WINDOW_SIZE; c = c + 1) begin
                        cand_ii[r][c] <= win_ii[r][c];
                    end
                end

                cand_x <= px_x - 10'd23;
                cand_y <= px_y - 10'd23;

                busy <= 1'b1;
                state <= S_STAGE_HDR;
                stage_idx <= 8'd0;
                feature_idx <= 8'd0;
                stage_score <= 8'd0;
                rom_addr <= 8'd1;
            end else begin
                case (state)
                    S_IDLE: begin
                        busy <= busy;
                    end

                    S_STAGE_HDR: begin
                        stage_feature_count <= rom_data[15:8];
                        stage_vote_threshold <= rom_data[7:0];
                        stage_score <= 8'd0;
                        feature_idx <= 8'd0;
                        rom_addr <= rom_addr + 8'd1;

                        if (rom_data[15:8] == 8'd0) begin
                            state <= S_STAGE_CHECK;
                        end else begin
                            state <= S_FEAT_HDR;
                        end
                    end

                    S_FEAT_HDR: begin
                        feature_weak_threshold <= rom_data[31:16];
                        rom_addr <= rom_addr + 8'd1;
                        state <= S_RECT1;
                    end

                    S_RECT1: begin
                        rect1_word <= rom_data;
                        rom_addr <= rom_addr + 8'd1;
                        state <= S_RECT2;
                    end

                    S_RECT2: begin
                        if (feature_response(rect1_word, rom_data) >= $signed(feature_weak_threshold)) begin
                            stage_score <= stage_score + 8'd1;
                        end

                        rom_addr <= rom_addr + 8'd1;

                        if ((feature_idx + 8'd1) < stage_feature_count) begin
                            feature_idx <= feature_idx + 8'd1;
                            state <= S_FEAT_HDR;
                        end else begin
                            state <= S_STAGE_CHECK;
                        end
                    end

                    S_STAGE_CHECK: begin
                        if (stage_score >= stage_vote_threshold) begin
                            if ((stage_idx + 8'd1) < STAGE_COUNT) begin
                                stage_idx <= stage_idx + 8'd1;
                                stage_score <= 8'd0;
                                feature_idx <= 8'd0;
                                state <= S_STAGE_HDR;
                            end else begin
                                face_found <= 1'b1;
                                face_x <= cand_x;
                                face_y <= cand_y;
                                busy <= 1'b0;
                                state <= S_IDLE;
                            end
                        end else begin
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end
                    end

                    default: begin
                        busy <= 1'b0;
                        state <= S_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
