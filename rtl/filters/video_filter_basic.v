`timescale 1ns/1ps

// video_filter_basic
// Purpose: select one RGB565 display filter for VGA readout pixels.
// Clock domain: purely combinational logic on the VGA readout path.
// Inputs: RGB565 pixel, 2-bit mode, and 4-bit threshold.
// Assumption: blanking is controlled outside this module.
module video_filter_basic (
    input  wire [15:0] rgb565_in,
    input  wire [1:0]  mode,
    input  wire [3:0]  threshold,
    output reg  [15:0] rgb565_out
);

    localparam [1:0] MODE_RAW       = 2'b00;
    localparam [1:0] MODE_GRAYSCALE = 2'b01;
    localparam [1:0] MODE_NEGATIVE  = 2'b10;
    localparam [1:0] MODE_THRESHOLD = 2'b11;

    wire [4:0] red5   = rgb565_in[15:11];
    wire [5:0] green6 = rgb565_in[10:5];
    wire [4:0] blue5  = rgb565_in[4:0];

    wire [5:0] red6  = {red5, red5[4]};
    wire [5:0] blue6 = {blue5, blue5[4]};
    wire [7:0] gray_sum = {2'b00, red6}
                         + {1'b0, green6, 1'b0}
                         + {2'b00, blue6};
    wire [5:0] gray6 = gray_sum[7:2];
    wire [5:0] threshold6 = {threshold, threshold[3:2]};

    always @(*) begin
        case (mode)
            MODE_GRAYSCALE: begin
                rgb565_out = {gray6[5:1], gray6, gray6[5:1]};
            end

            MODE_NEGATIVE: begin
                rgb565_out = {~red5, ~green6, ~blue5};
            end

            MODE_THRESHOLD: begin
                rgb565_out = (gray6 >= threshold6) ? 16'hffff : 16'h0000;
            end

            MODE_RAW: begin
                rgb565_out = rgb565_in;
            end

            default: begin
                rgb565_out = rgb565_in;
            end
        endcase
    end

endmodule
