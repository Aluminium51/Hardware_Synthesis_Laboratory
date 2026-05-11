`timescale 1ns/1ps

// camera_xclk_mmcm
// Purpose: generate the fixed 50 MHz OV7670 XCLK stream baseline from the 100 MHz board clock.
// Clock domain: clk_100 input; cam_xclk is only driven to the external camera XCLK pin.
// Outputs: fixed 50 MHz XCLK and a short startup lock delay for camera init reset.
// Assumptions: rate_sel is kept for compatibility with older timing probes but is intentionally unused.
module camera_xclk_mmcm (
    input  wire       clk_100,
    input  wire       rst,
    input  wire [1:0] rate_sel,
    output wire       cam_xclk,
    output wire       locked
);

    reg [7:0] lock_count = 8'd0;
    reg       locked_reg = 1'b0;
    reg       xclk_reg = 1'b0;

    always @(posedge clk_100) begin
        if (rst) begin
            lock_count <= 8'd0;
            locked_reg <= 1'b0;
            xclk_reg <= 1'b0;
        end else begin
            xclk_reg <= ~xclk_reg;

            if (!locked_reg) begin
                lock_count <= lock_count + 1'b1;
                if (&lock_count) begin
                    locked_reg <= 1'b1;
                end
            end
        end
    end

    assign cam_xclk = xclk_reg;
    assign locked = locked_reg;

    wire [1:0] unused_rate_sel = rate_sel;

endmodule
