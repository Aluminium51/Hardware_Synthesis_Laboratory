`timescale 1ns/1ps

// sync_2ff
//
// Purpose:
//   Synchronize one single-bit level signal into a target clock domain.
//
// Clock domain:
//   clk
//
// Inputs:
//   clk     - destination clock domain
//   rst     - active-high synchronous reset for both stages
//   d_async - unsynchronized single-bit input
//
// Outputs:
//   q_sync  - synchronized destination-domain level
//
// Assumption:
//   This block is for independent status/control bits, not multi-bit buses.
module sync_2ff (
    input  wire clk,
    input  wire rst,
    input  wire d_async,
    output wire q_sync
);

    (* ASYNC_REG = "TRUE" *) reg sync_ff0 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg sync_ff1 = 1'b0;

    // Two-stage synchronizer reduces metastability risk before the signal is
    // consumed by destination-domain logic.
    always @(posedge clk) begin
        if (rst) begin
            sync_ff0 <= 1'b0;
            sync_ff1 <= 1'b0;
        end else begin
            sync_ff0 <= d_async;
            sync_ff1 <= sync_ff0;
        end
    end

    // Use the second stage only; the first stage is allowed to settle.
    assign q_sync = sync_ff1;

endmodule
