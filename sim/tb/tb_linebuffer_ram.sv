`timescale 1ns/1ps

module tb_linebuffer_ram;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH = 8;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg wr_en = 1'b0;
    reg [DATA_WIDTH-1:0] din = '0;

    wire [DATA_WIDTH-1:0] dout;
    wire full;

    int i;
    int errors;

    linebuffer_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .din(din),
        .dout(dout),
        .full(full)
    );

    always #5 clk = ~clk;

    task automatic check(input bit cond, input string msg);
        begin
            if (!cond) begin
                errors++;
                $display("ERROR: %s (t=%0t)", msg, $time);
            end
        end
    endtask

    initial begin
        errors = 0;
        repeat (3) @(posedge clk);
        rst <= 1'b0;

        // Fill buffer: full should assert after DEPTH writes.
        for (i = 0; i < DEPTH; i++) begin
            @(negedge clk);
            wr_en <= 1'b1;
            din <= i[7:0];
            @(posedge clk);
            #1;
            check(full == (i == DEPTH-1), $sformatf("full mismatch at fill i=%0d", i));
        end

        // Once full, the output should be the sample from DEPTH cycles ago.
        for (i = DEPTH; i < DEPTH + 6; i++) begin
            @(negedge clk);
            wr_en <= 1'b1;
            din <= i[7:0];
            @(posedge clk);
            #1;
            check(full == 1'b1, "full should stay high after fill");
            check(dout == ((i-DEPTH+1) & 8'hff), $sformatf("dout mismatch for i=%0d", i));
        end

        @(negedge clk);
        wr_en <= 1'b0;
        din <= 8'h00;

        if (errors == 0) begin
            $display("PASS: tb_linebuffer_ram");
            $finish;
        end

        $fatal(1, "FAIL: tb_linebuffer_ram errors=%0d", errors);
    end

endmodule
