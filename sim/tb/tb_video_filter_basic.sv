`timescale 1ns/1ps

module tb_video_filter_basic;

    localparam [1:0] MODE_RAW       = 2'b00;
    localparam [1:0] MODE_GRAYSCALE = 2'b01;
    localparam [1:0] MODE_NEGATIVE  = 2'b10;
    localparam [1:0] MODE_THRESHOLD = 2'b11;

    reg [15:0] rgb565_in = 16'h0000;
    reg [1:0]  mode = MODE_RAW;
    reg [3:0]  threshold = 4'h0;

    wire [15:0] rgb565_out;

    int errors;

    video_filter_basic dut (
        .rgb565_in  (rgb565_in),
        .mode       (mode),
        .threshold  (threshold),
        .rgb565_out (rgb565_out)
    );

    function automatic [5:0] expected_gray6(input [15:0] rgb);
        reg [5:0] red6;
        reg [5:0] blue6;
        reg [7:0] gray_sum;
        begin
            red6 = {rgb[15:11], rgb[15]};
            blue6 = {rgb[4:0], rgb[4]};
            gray_sum = {2'b00, red6}
                     + {1'b0, rgb[10:5], 1'b0}
                     + {2'b00, blue6};
            expected_gray6 = gray_sum[7:2];
        end
    endfunction

    function automatic [15:0] expected_gray565(input [15:0] rgb);
        reg [5:0] gray;
        begin
            gray = expected_gray6(rgb);
            expected_gray565 = {gray[5:1], gray, gray[5:1]};
        end
    endfunction

    function automatic [15:0] expected_negative(input [15:0] rgb);
        begin
            expected_negative = {~rgb[15:11], ~rgb[10:5], ~rgb[4:0]};
        end
    endfunction

    function automatic [5:0] threshold6(input [3:0] threshold4);
        begin
            threshold6 = {threshold4, threshold4[3:2]};
        end
    endfunction

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t: %s", $time, message);
            end
        end
    endtask

    task automatic check_output(
        input [15:0] pixel,
        input [1:0]  mode_value,
        input [3:0]  threshold_value,
        input [15:0] expected,
        input string label
    );
        begin
            rgb565_in = pixel;
            mode = mode_value;
            threshold = threshold_value;
            #1;

            check_signal(rgb565_out === expected,
                         $sformatf("%s expected 0x%04h got 0x%04h",
                                   label, expected, rgb565_out));
        end
    endtask

    task automatic check_threshold(
        input [15:0] pixel,
        input [3:0]  threshold_value,
        input [15:0] expected,
        input string label
    );
        begin
            check_output(pixel, MODE_THRESHOLD, threshold_value, expected, label);
            check_signal((rgb565_out === 16'h0000) || (rgb565_out === 16'hffff),
                         $sformatf("%s threshold output was not black or white",
                                   label));
        end
    endtask

    initial begin
        // $dumpfile("sim/run/tb_video_filter_basic.vcd");
        $dumpfile("tb_video_filter_basic.vcd");
        $dumpvars(0, tb_video_filter_basic);

        errors = 0;

        check_output(16'habcd, MODE_RAW, 4'h7, 16'habcd,
                     "raw passthrough");
        check_output(16'h65a2, MODE_GRAYSCALE, 4'h0,
                     expected_gray565(16'h65a2),
                     "grayscale weighted gray4");
        check_output(16'h3aa5, MODE_NEGATIVE, 4'h0,
                     expected_negative(16'h3aa5),
                     "negative channel inversion");
        check_threshold(16'h8c51, 4'h8, 16'hffff,
                        "threshold equal is white");
        check_threshold(16'h8c51, 4'h9, 16'h0000,
                        "threshold below is black");

        rgb565_in = 16'h6b78;
        threshold = 4'h6;

        mode = MODE_RAW;
        #1;
        check_signal(rgb565_out === 16'h6b78,
                     "mode switch raw on shared input");

        mode = MODE_GRAYSCALE;
        #1;
        check_signal(rgb565_out === expected_gray565(16'h6b78),
                     "mode switch grayscale on shared input");

        mode = MODE_NEGATIVE;
        #1;
        check_signal(rgb565_out === expected_negative(16'h6b78),
                     "mode switch negative on shared input");

        mode = MODE_THRESHOLD;
        #1;
        check_signal(rgb565_out === ((expected_gray6(16'h6b78) >= threshold6(4'h6)) ? 16'hffff : 16'h0000),
                     "mode switch threshold on shared input");

        mode = 2'bxx;
        #1;
        check_signal(rgb565_out === 16'h6b78,
                     "unknown mode should default to raw passthrough");

        if (errors == 0) begin
            $display("PASS: basic RGB565 filter modes and threshold comparison verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_video_filter_basic found %0d error(s).", errors);
    end

endmodule
