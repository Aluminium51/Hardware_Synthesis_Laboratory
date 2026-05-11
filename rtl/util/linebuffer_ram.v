// Simple line delay buffer using circular RAM.
// After DEPTH writes, each new write returns the sample delayed by DEPTH cycles.
module linebuffer_ram #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 320
) (
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout,
    output reg full
);

    // address width
    localparam AW = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0] ptr;
    reg [AW:0] count;

    always @(posedge clk) begin
        if (rst) begin
            ptr <= {AW{1'b0}};
            count <= 0;
            dout <= 0;
            full <= 0;
        end else begin
            if (wr_en) begin
                // Read the location that will become the oldest sample after this write.
                dout <= mem[(ptr == DEPTH-1) ? {AW{1'b0}} : (ptr + {{AW-1{1'b0}}, 1'b1})];
                mem[ptr] <= din;

                if (count < DEPTH) begin
                    count <= count + {{AW{1'b0}}, 1'b1};
                    if (count == DEPTH-1)
                        full <= 1'b1;
                end

                if (ptr == DEPTH-1)
                    ptr <= {AW{1'b0}};
                else
                    ptr <= ptr + {{AW-1{1'b0}}, 1'b1};
            end
        end
    end

endmodule
