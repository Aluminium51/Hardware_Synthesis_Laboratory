`timescale 1ns/1ps

module tb_sliding_window_24;

    localparam int IMAGE_WIDTH = 24;
    localparam int IMAGE_HEIGHT = 24;
    localparam int WINDOW = 24;
    localparam int DATA_WIDTH = 8;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg px_valid = 1'b0;
    reg line_start = 1'b0;
    reg frame_start = 1'b0;
    reg [7:0] px_in = 8'h00;

    wire window_valid;
    wire [9:0] window_x;
    wire [8:0] window_y;
    wire [(WINDOW*WINDOW*DATA_WIDTH)-1:0] window_data;

    int x;
    int y;
    int errors;
    bit seen_valid;
    reg [9:0] seen_x;
    reg [8:0] seen_y;
    reg [(WINDOW*WINDOW*DATA_WIDTH)-1:0] seen_data;

    sliding_window_24 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .WINDOW(WINDOW)
    ) dut (
        .clk(clk),
        .rst(rst),
        .px_valid(px_valid),
        .line_start(line_start),
        .frame_start(frame_start),
        .px_in(px_in),
        .window_valid(window_valid),
        .window_x(window_x),
        .window_y(window_y),
        .window_data(window_data)
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

    function automatic [7:0] get_window_px(input int row, input int col);
        int idx;
        begin
            idx = ((row*WINDOW + col + 1)*DATA_WIDTH)-1;
            get_window_px = window_data[idx -: DATA_WIDTH];
        end
    endfunction

    always @(posedge clk) begin
        if (window_valid) begin
            seen_valid <= 1'b1;
            seen_x <= window_x;
            seen_y <= window_y;
            seen_data <= window_data;
        end
    end

    initial begin
        errors = 0;
        seen_valid = 1'b0;
        seen_x = 10'd0;
        seen_y = 9'd0;
        seen_data = '0;

        repeat (3) @(posedge clk);
        rst <= 1'b0;

        // Feed one full 24x24 frame with deterministic pixel values: p = y*24 + x.
        for (y = 0; y < IMAGE_HEIGHT; y++) begin
            for (x = 0; x < IMAGE_WIDTH; x++) begin
                @(negedge clk);
                px_valid <= 1'b1;
                line_start <= (x == 0);
                frame_start <= (x == 0 && y == 0);
                px_in <= (y*IMAGE_WIDTH + x) & 8'hFF;
                @(posedge clk);
                #1;
            end
        end

        @(negedge clk);
        px_valid <= 1'b0;
        line_start <= 1'b0;
        frame_start <= 1'b0;
        px_in <= 8'h00;

        repeat (2) @(posedge clk);

        check(seen_valid == 1'b1, "window_valid should assert during the first full 24x24 frame");
        check(seen_x == 10'd0, "first full window_x should be 0");
        check(seen_y == 9'd0, "first full window_y should be 0");

        // Expect top-left pixel = 0 and bottom-right pixel = 24*24-1 (mod 256)
        check(seen_data[((0*WINDOW + 0 + 1)*DATA_WIDTH)-1 -: DATA_WIDTH] == 8'd0, "window top-left mismatch");
        check(seen_data[((23*WINDOW + 23 + 1)*DATA_WIDTH)-1 -: DATA_WIDTH] == 8'd63, "window bottom-right mismatch (575 mod 256 = 63)");

        if (errors == 0) begin
            $display("PASS: tb_sliding_window_24");
            $finish;
        end

        $fatal(1, "FAIL: tb_sliding_window_24 errors=%0d", errors);
    end

endmodule
