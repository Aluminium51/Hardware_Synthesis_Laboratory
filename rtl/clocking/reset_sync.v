`timescale 1ns/1ps

// reset_sync
// Purpose: synchronize an active-high reset into one clock domain.
// Clock domain: target domain selected by clk.
// Assumption: reset assertion may be asynchronous; deassertion is synchronized.
module reset_sync (
    input  wire clk,
    input  wire rst_async,
    output wire rst_sync
);

    reg [1:0] sync_ff = 2'b11;

    always @(posedge clk or posedge rst_async) begin
        if (rst_async) begin
            sync_ff <= 2'b11;
        end else begin
            sync_ff <= {sync_ff[0], 1'b0};
        end
    end

    assign rst_sync = sync_ff[1];

endmodule
