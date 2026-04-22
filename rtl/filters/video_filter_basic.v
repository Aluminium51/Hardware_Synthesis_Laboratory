`timescale 1ns/1ps

// video_filter_basic
// Purpose: select one RGB444 display filter for VGA readout pixels.
// Clock domain: purely combinational logic on the VGA readout path.
// Inputs: RGB444 pixel, 2-bit mode, and 4-bit threshold.
// Assumption: blanking is controlled outside this module.
module video_filter_basic (
    input  wire [11:0] rgb444_in,
    input  wire [1:0]  mode,
    input  wire [3:0]  threshold,
    output reg  [11:0] rgb444_out
);

    localparam [1:0] MODE_RAW       = 2'b00;
    localparam [1:0] MODE_GRAYSCALE = 2'b01;
    localparam [1:0] MODE_NEGATIVE  = 2'b10;
    localparam [1:0] MODE_THRESHOLD = 2'b11;

    wire [3:0] red4   = rgb444_in[11:8];
    wire [3:0] green4 = rgb444_in[7:4];
    wire [3:0] blue4  = rgb444_in[3:0];

    wire [5:0] gray_sum = {2'b00, red4}
                         + {1'b0, green4, 1'b0}
                         + {2'b00, blue4};
    wire [3:0] gray4 = gray_sum[5:2];

    always @(*) begin
        case (mode)
            MODE_GRAYSCALE: begin
                rgb444_out = {gray4, gray4, gray4};
            end

            MODE_NEGATIVE: begin
                rgb444_out = {~red4, ~green4, ~blue4};
            end

            MODE_THRESHOLD: begin
                rgb444_out = (gray4 >= threshold) ? 12'hfff : 12'h000;
            end

            MODE_RAW: begin
                rgb444_out = rgb444_in;
            end

            default: begin
                rgb444_out = rgb444_in;
            end
        endcase
    end

endmodule
