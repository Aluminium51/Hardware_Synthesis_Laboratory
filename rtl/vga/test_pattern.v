`timescale 1ns/1ps

// test_pattern
// Purpose: generate a visible RGB444 color-bar pattern for VGA bring-up.
// Clock domain: combinational logic used on the VGA readout path.
// Inputs: current VGA coordinate and active-video flag.
// Assumption: callers drive RGB to black when active_video is low.
module test_pattern (
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        active_video,
    output reg  [11:0] rgb444
);

    always @(*) begin
        if (!active_video) begin
            rgb444 = 12'h000;
        end else if (x < 10'd80) begin
            rgb444 = 12'hfff;
        end else if (x < 10'd160) begin
            rgb444 = 12'hff0;
        end else if (x < 10'd240) begin
            rgb444 = 12'h0ff;
        end else if (x < 10'd320) begin
            rgb444 = 12'h0f0;
        end else if (x < 10'd400) begin
            rgb444 = 12'hf0f;
        end else if (x < 10'd480) begin
            rgb444 = 12'hf00;
        end else if (x < 10'd560) begin
            rgb444 = 12'h00f;
        end else begin
            rgb444 = (y[4]) ? 12'h888 : 12'h444;
        end
    end

endmodule
