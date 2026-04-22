`timescale 1ns/1ps

module tb_video_filter_basic;

    localparam [1:0] MODE_RAW       = 2'b00;
    localparam [1:0] MODE_GRAYSCALE = 2'b01;
    localparam [1:0] MODE_NEGATIVE  = 2'b10;
    localparam [1:0] MODE_THRESHOLD = 2'b11;

    reg [11:0] rgb444_in = 12'h000;
    reg [1:0]  mode = MODE_RAW;
    reg [3:0]  threshold = 4'h0;

    wire [11:0] rgb444_out;

    int errors;

    video_filter_basic dut (
        .rgb444_in  (rgb444_in),
        .mode       (mode),
        .threshold  (threshold),
        .rgb444_out (rgb444_out)
    );

    function automatic [3:0] expected_gray4(input [11:0] rgb);
        reg [5:0] gray_sum;
        begin
            gray_sum = {2'b00, rgb[11:8]}
                     + {1'b0, rgb[7:4], 1'b0}
                     + {2'b00, rgb[3:0]};
            expected_gray4 = gray_sum[5:2];
        end
    endfunction

    function automatic [11:0] expected_negative(input [11:0] rgb);
        begin
            expected_negative = {~rgb[11:8], ~rgb[7:4], ~rgb[3:0]};
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
        input [11:0] pixel,
        input [1:0]  mode_value,
        input [3:0]  threshold_value,
        input [11:0] expected,
        input string label
    );
        begin
            rgb444_in = pixel;
            mode = mode_value;
            threshold = threshold_value;
            #1;

            check_signal(rgb444_out === expected,
                         $sformatf("%s expected 0x%03h got 0x%03h",
                                   label, expected, rgb444_out));
        end
    endtask

    task automatic check_threshold(
        input [11:0] pixel,
        input [3:0]  threshold_value,
        input [11:0] expected,
        input string label
    );
        begin
            check_output(pixel, MODE_THRESHOLD, threshold_value, expected, label);
            check_signal((rgb444_out === 12'h000) || (rgb444_out === 12'hfff),
                         $sformatf("%s threshold output was not black or white",
                                   label));
        end
    endtask

    initial begin
        $dumpfile("sim/run/tb_video_filter_basic.vcd");
        $dumpvars(0, tb_video_filter_basic);

        errors = 0;

        check_output(12'habc, MODE_RAW, 4'h7, 12'habc,
                     "raw passthrough");
        check_output(12'h6a2, MODE_GRAYSCALE, 4'h0,
                     {3{expected_gray4(12'h6a2)}},
                     "grayscale weighted gray4");
        check_output(12'h3a5, MODE_NEGATIVE, 4'h0,
                     expected_negative(12'h3a5),
                     "negative channel inversion");
        check_threshold(12'h888, 4'h8, 12'hfff,
                        "threshold equal is white");
        check_threshold(12'h888, 4'h9, 12'h000,
                        "threshold below is black");

        rgb444_in = 12'h678;
        threshold = expected_gray4(12'h678);

        mode = MODE_RAW;
        #1;
        check_signal(rgb444_out === 12'h678,
                     "mode switch raw on shared input");

        mode = MODE_GRAYSCALE;
        #1;
        check_signal(rgb444_out === {3{expected_gray4(12'h678)}},
                     "mode switch grayscale on shared input");

        mode = MODE_NEGATIVE;
        #1;
        check_signal(rgb444_out === expected_negative(12'h678),
                     "mode switch negative on shared input");

        mode = MODE_THRESHOLD;
        #1;
        check_signal(rgb444_out === 12'hfff,
                     "mode switch threshold on shared input");

        mode = 2'bxx;
        #1;
        check_signal(rgb444_out === 12'h678,
                     "unknown mode should default to raw passthrough");

        if (errors == 0) begin
            $display("PASS: basic RGB444 filter modes and threshold gray4 comparison verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_video_filter_basic found %0d error(s).", errors);
    end

endmodule
