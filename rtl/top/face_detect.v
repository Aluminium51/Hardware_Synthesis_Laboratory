// face_detect.v
// Purpose: Haar-cascade stage evaluator using BRAM-backed cascade ROM and integral image reads.
// Clock domain: single processing clock.
// Notes:
// - Fixed-point only (no floating point, no division).
// - Expects ROM layout emitted by scripts/vivado/haarcascade_to_coe.py.

module face_detect #(
    parameter integer IMG_WIDTH   = 320,
    parameter integer SCALE_SHIFT = 8,
    parameter [31:0] ROM_MAGIC    = 32'h48415231
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [9:0]  win_x,
    input  wire [8:0]  win_y,

    // Cascade ROM
    output reg  [31:0] rom_addr,
    output reg         rom_ren,
    input  wire [31:0] rom_data,

    // Integral-image memory
    output reg  [31:0] ii_addr,
    output reg         ii_ren,
    input  wire [17:0] ii_data,
    input  wire        ii_valid,

    output reg         busy,
    output reg         done,
    output reg         face_found
);

localparam [5:0]
    S_IDLE            = 6'd0,
    S_HDR_MAGIC       = 6'd1,
    S_HDR_SCALE       = 6'd2,
    S_HDR_STAGE_COUNT = 6'd3,
    S_STAGE_WEAK_CNT  = 6'd4,
    S_STAGE_THRESH    = 6'd5,
    S_WEAK_THRESH     = 6'd6,
    S_WEAK_LEFT       = 6'd7,
    S_WEAK_RIGHT      = 6'd8,
    S_WEAK_RECT_CNT   = 6'd9,
    S_RECT_PACKED     = 6'd10,
    S_RECT_WEIGHT     = 6'd11,
    S_II_REQ_A        = 6'd12,
    S_II_WAIT_A       = 6'd13,
    S_II_WAIT_B       = 6'd14,
    S_II_WAIT_C       = 6'd15,
    S_II_WAIT_D       = 6'd16,
    S_WEAK_EVAL       = 6'd17,
    S_STAGE_EVAL      = 6'd18,
    S_PASS            = 6'd19,
    S_FAIL            = 6'd20;

reg [5:0] state;

reg [31:0] stage_count;
reg [31:0] stage_idx;
reg [31:0] weak_count;
reg [31:0] weak_idx;
reg [31:0] rect_count;
reg [31:0] rect_idx;

reg signed [31:0] stage_threshold_q;
reg signed [31:0] weak_threshold_q;
reg signed [31:0] weak_left_q;
reg signed [31:0] weak_right_q;
reg signed [31:0] rect_weight_q;

reg [31:0] packed_rect;
reg [7:0] rect_x;
reg [7:0] rect_y;
reg [7:0] rect_w;
reg [7:0] rect_h;

reg [31:0] addr_a;
reg [31:0] addr_b;
reg [31:0] addr_c;
reg [31:0] addr_d;

reg [17:0] ii_a;
reg [17:0] ii_b;
reg [17:0] ii_c;
reg [17:0] ii_d;

reg signed [63:0] stage_acc_q;
reg signed [63:0] weak_sum_q;
reg signed [63:0] weighted_q;
reg signed [33:0] rect_sum;

function [31:0] ii_addr_of;
    input [10:0] x;
    input [9:0]  y;
    begin
        ii_addr_of = y * (IMG_WIDTH + 1) + x;
    end
endfunction

wire [10:0] abs_x  = win_x + rect_x;
wire [9:0]  abs_y  = win_y + rect_y;
wire [10:0] abs_xw = win_x + rect_x + rect_w;
wire [9:0]  abs_yh = win_y + rect_y + rect_h;

always @(posedge clk) begin
    if (rst) begin
        state            <= S_IDLE;
        rom_addr         <= 32'd0;
        rom_ren          <= 1'b0;
        ii_addr          <= 32'd0;
        ii_ren           <= 1'b0;
        busy             <= 1'b0;
        done             <= 1'b0;
        face_found       <= 1'b0;
        stage_count      <= 32'd0;
        stage_idx        <= 32'd0;
        weak_count       <= 32'd0;
        weak_idx         <= 32'd0;
        rect_count       <= 32'd0;
        rect_idx         <= 32'd0;
        stage_acc_q      <= 64'sd0;
        weak_sum_q       <= 64'sd0;
        weighted_q       <= 64'sd0;
    end else begin
        rom_ren <= 1'b0;
        ii_ren  <= 1'b0;
        done    <= 1'b0;

        case (state)
            S_IDLE: begin
                busy       <= 1'b0;
                face_found <= 1'b0;
                if (start) begin
                    busy     <= 1'b1;
                    rom_addr <= 32'd0;
                    rom_ren  <= 1'b1;
                    state    <= S_HDR_MAGIC;
                end
            end

            S_HDR_MAGIC: begin
                if (rom_data != ROM_MAGIC) begin
                    state <= S_FAIL;
                end else begin
                    rom_addr <= rom_addr + 32'd1;
                    rom_ren  <= 1'b1;
                    state    <= S_HDR_SCALE;
                end
            end

            S_HDR_SCALE: begin
                // Scale word is currently informational; runtime scale is SCALE_SHIFT parameter.
                rom_addr <= rom_addr + 32'd1;
                rom_ren  <= 1'b1;
                state    <= S_HDR_STAGE_COUNT;
            end

            S_HDR_STAGE_COUNT: begin
                stage_count <= rom_data;
                stage_idx   <= 32'd0;
                if (rom_data == 32'd0) begin
                    state <= S_FAIL;
                end else begin
                    rom_addr <= rom_addr + 32'd1;
                    rom_ren  <= 1'b1;
                    state    <= S_STAGE_WEAK_CNT;
                end
            end

            S_STAGE_WEAK_CNT: begin
                weak_count <= rom_data;
                weak_idx   <= 32'd0;
                stage_acc_q <= 64'sd0;
                rom_addr   <= rom_addr + 32'd1;
                rom_ren    <= 1'b1;
                state      <= S_STAGE_THRESH;
            end

            S_STAGE_THRESH: begin
                stage_threshold_q <= $signed(rom_data);
                if (weak_count == 32'd0) begin
                    state <= S_STAGE_EVAL;
                end else begin
                    rom_addr <= rom_addr + 32'd1;
                    rom_ren  <= 1'b1;
                    state    <= S_WEAK_THRESH;
                end
            end

            S_WEAK_THRESH: begin
                weak_threshold_q <= $signed(rom_data);
                rom_addr <= rom_addr + 32'd1;
                rom_ren  <= 1'b1;
                state    <= S_WEAK_LEFT;
            end

            S_WEAK_LEFT: begin
                weak_left_q <= $signed(rom_data);
                rom_addr <= rom_addr + 32'd1;
                rom_ren  <= 1'b1;
                state    <= S_WEAK_RIGHT;
            end

            S_WEAK_RIGHT: begin
                weak_right_q <= $signed(rom_data);
                rom_addr <= rom_addr + 32'd1;
                rom_ren  <= 1'b1;
                state    <= S_WEAK_RECT_CNT;
            end

            S_WEAK_RECT_CNT: begin
                rect_count <= rom_data;
                rect_idx   <= 32'd0;
                weak_sum_q <= 64'sd0;
                if (rom_data == 32'd0) begin
                    state <= S_WEAK_EVAL;
                end else begin
                    rom_addr <= rom_addr + 32'd1;
                    rom_ren  <= 1'b1;
                    state    <= S_RECT_PACKED;
                end
            end

            S_RECT_PACKED: begin
                packed_rect <= rom_data;
                rect_x <= rom_data[31:24];
                rect_y <= rom_data[23:16];
                rect_w <= rom_data[15:8];
                rect_h <= rom_data[7:0];

                addr_a <= ii_addr_of(win_x + rom_data[31:24],               win_y + rom_data[23:16]);
                addr_b <= ii_addr_of(win_x + rom_data[31:24] + rom_data[15:8], win_y + rom_data[23:16]);
                addr_c <= ii_addr_of(win_x + rom_data[31:24],               win_y + rom_data[23:16] + rom_data[7:0]);
                addr_d <= ii_addr_of(win_x + rom_data[31:24] + rom_data[15:8], win_y + rom_data[23:16] + rom_data[7:0]);

                rom_addr <= rom_addr + 32'd1;
                rom_ren  <= 1'b1;
                state    <= S_RECT_WEIGHT;
            end

            S_RECT_WEIGHT: begin
                rect_weight_q <= $signed(rom_data);
                state <= S_II_REQ_A;
            end

            S_II_REQ_A: begin
                ii_addr <= addr_a;
                ii_ren  <= 1'b1;
                state   <= S_II_WAIT_A;
            end

            S_II_WAIT_A: begin
                if (ii_valid) begin
                    ii_a   <= ii_data;
                    ii_addr <= addr_b;
                    ii_ren <= 1'b1;
                    state  <= S_II_WAIT_B;
                end
            end

            S_II_WAIT_B: begin
                if (ii_valid) begin
                    ii_b   <= ii_data;
                    ii_addr <= addr_c;
                    ii_ren <= 1'b1;
                    state  <= S_II_WAIT_C;
                end
            end

            S_II_WAIT_C: begin
                if (ii_valid) begin
                    ii_c   <= ii_data;
                    ii_addr <= addr_d;
                    ii_ren <= 1'b1;
                    state  <= S_II_WAIT_D;
                end
            end

            S_II_WAIT_D: begin
                if (ii_valid) begin
                    ii_d <= ii_data;

                    // Sum = A + D - B - C
                    rect_sum  <= $signed({1'b0, ii_a}) + $signed({1'b0, ii_data})
                               - $signed({1'b0, ii_b}) - $signed({1'b0, ii_c});

                    weighted_q <= (($signed({1'b0, ii_a}) + $signed({1'b0, ii_data})
                                 -  $signed({1'b0, ii_b}) - $signed({1'b0, ii_c})) * rect_weight_q) >>> SCALE_SHIFT;

                    weak_sum_q <= weak_sum_q + ((($signed({1'b0, ii_a}) + $signed({1'b0, ii_data})
                                  -  $signed({1'b0, ii_b}) - $signed({1'b0, ii_c})) * rect_weight_q) >>> SCALE_SHIFT);

                    if (rect_idx + 32'd1 < rect_count) begin
                        rect_idx <= rect_idx + 32'd1;
                        rom_addr <= rom_addr + 32'd1;
                        rom_ren  <= 1'b1;
                        state    <= S_RECT_PACKED;
                    end else begin
                        state <= S_WEAK_EVAL;
                    end
                end
            end

            S_WEAK_EVAL: begin
                // If feature sum below threshold, add left leaf value; else add right leaf.
                if (weak_sum_q < weak_threshold_q)
                    stage_acc_q <= stage_acc_q + weak_left_q;
                else
                    stage_acc_q <= stage_acc_q + weak_right_q;

                if (weak_idx + 32'd1 < weak_count) begin
                    weak_idx <= weak_idx + 32'd1;
                    rom_addr <= rom_addr + 32'd1;
                    rom_ren  <= 1'b1;
                    state    <= S_WEAK_THRESH;
                end else begin
                    state    <= S_STAGE_EVAL;
                end
            end

            S_STAGE_EVAL: begin
                if (stage_acc_q < stage_threshold_q) begin
                    state <= S_FAIL;
                end else if (stage_idx + 32'd1 < stage_count) begin
                    stage_idx <= stage_idx + 32'd1;
                    rom_addr  <= rom_addr + 32'd1;
                    rom_ren   <= 1'b1;
                    state     <= S_STAGE_WEAK_CNT;
                end else begin
                    state <= S_PASS;
                end
            end

            S_PASS: begin
                busy       <= 1'b0;
                done       <= 1'b1;
                face_found <= 1'b1;
                state      <= S_IDLE;
            end

            S_FAIL: begin
                busy       <= 1'b0;
                done       <= 1'b1;
                face_found <= 1'b0;
                state      <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
