`timescale 1ns/1ps

// sync_2ff
// Purpose: synchronize a single-bit level signal into a target clock domain.
// Clock domain: target domain selected by clk.
// Ports: async input, active-high synchronous reset, synchronized output.
// Assumption: this is for status/control bits, not multi-bit data buses.
module sync_2ff (
    input  wire clk,
    input  wire rst,
    input  wire d_async,
    output wire q_sync
);

    (* ASYNC_REG = "TRUE" *) reg sync_ff0 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg sync_ff1 = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            sync_ff0 <= 1'b0;
            sync_ff1 <= 1'b0;
        end else begin
            sync_ff0 <= d_async;
            sync_ff1 <= sync_ff0;
        end
    end

    assign q_sync = sync_ff1;

endmodule
