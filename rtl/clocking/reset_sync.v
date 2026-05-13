`timescale 1ns/1ps

// reset_sync
//
// Purpose:
//   Synchronize an active-high reset into a single target clock domain.
//
// Clock domain:
//   clk
//
// Inputs:
//   clk       - target clock domain
//   rst_async - active-high reset that may assert asynchronously
//
// Outputs:
//   rst_sync  - active-high reset with synchronous deassertion
//
// Assumption:
//   Assertion may be asynchronous; release is delayed through two flip-flops.
module reset_sync (
    input  wire clk,
    input  wire rst_async,
    output wire rst_sync
);

    reg [1:0] sync_ff = 2'b11;

    // Asynchronous assertion gives immediate reset response; the shift register
    // then releases reset cleanly after two target-clock edges.
    always @(posedge clk or posedge rst_async) begin
        if (rst_async) begin
            sync_ff <= 2'b11;
        end else begin
            sync_ff <= {sync_ff[0], 1'b0};
        end
    end

    // The second stage is the domain-local reset distributed to downstream RTL.
    assign rst_sync = sync_ff[1];

endmodule
