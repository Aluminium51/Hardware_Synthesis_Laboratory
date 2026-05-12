`timescale 1ns/1ps

// haarcascade_rom
// Purpose: BRAM-backed ROM for Haar cascade words.
// Clock domain: camera processing clock.
// Notes: synchronous read with 1-cycle latency when ren is asserted.
module haarcascade_rom #(
    parameter integer ROM_WORDS = 24471,
    parameter MEM_FILE = "haarcascade_frontalface_q8.mem"
) (
    input  wire        clk,
    input  wire        ren,
    input  wire [31:0] addr,
    output reg  [31:0] data
);

    (* ram_style = "block" *) reg [31:0] mem [0:ROM_WORDS-1];

    initial begin
        $readmemh(MEM_FILE, mem);
    end

    always @(posedge clk) begin
        if (ren) begin
            if (addr < ROM_WORDS)
                data <= mem[addr];
            else
                data <= 32'd0;
        end
    end

endmodule
