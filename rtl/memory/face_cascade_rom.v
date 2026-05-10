`timescale 1ns/1ps

// face_cascade_rom
// Behavioral ROM stub for face-detection cascade parameters.
// Replace the contents with a Vivado Block Memory Generator ROM when you
// generate the real Haar cascade weights from OpenCV XML.
module face_cascade_rom (
    input  wire        clk,
    input  wire [7:0]  addr,
    output reg  [31:0] data
);

    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 32'd0;
        end

        // Eight stages, each with one feature. The thresholds below are set so
        // the placeholder ROM does not produce false positives.
        mem[8'd1]  = {16'd0, 8'd1, 8'd1};        // stage 0: 1 feature, vote threshold 1
        mem[8'd2]  = {16'sh7FFF, 16'd0};         // feature threshold
        mem[8'd3]  = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd4]  = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd5]  = {16'd0, 8'd1, 8'd1};
        mem[8'd6]  = {16'sh7FFF, 16'd0};
        mem[8'd7]  = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd8]  = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd9]  = {16'd0, 8'd1, 8'd1};
        mem[8'd10] = {16'sh7FFF, 16'd0};
        mem[8'd11] = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd12] = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd13] = {16'd0, 8'd1, 8'd1};
        mem[8'd14] = {16'sh7FFF, 16'd0};
        mem[8'd15] = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd16] = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd17] = {16'd0, 8'd1, 8'd1};
        mem[8'd18] = {16'sh7FFF, 16'd0};
        mem[8'd19] = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd20] = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd21] = {16'd0, 8'd1, 8'd1};
        mem[8'd22] = {16'sh7FFF, 16'd0};
        mem[8'd23] = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd24] = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd25] = {16'd0, 8'd1, 8'd1};
        mem[8'd26] = {16'sh7FFF, 16'd0};
        mem[8'd27] = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd28] = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};

        mem[8'd29] = {16'd0, 8'd1, 8'd1};
        mem[8'd30] = {16'sh7FFF, 16'd0};
        mem[8'd31] = {5'd0, 5'd0, 5'd24, 5'd12, 8'sd1, 4'd0};
        mem[8'd32] = {5'd0, 5'd12, 5'd24, 5'd12, -8'sd1, 4'd0};
    end

    always @(posedge clk) begin
        data <= mem[addr];
    end

endmodule
