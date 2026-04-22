`timescale 1ns/1ps

module tb_ov7670_capture;

    localparam int FRAME_PIXELS = 4;
    localparam int ADDR_WIDTH = 17;
    localparam int MAX_EXPECTED_WRITES = 32;

    reg                  pclk = 1'b0;
    reg                  rst = 1'b1;
    reg                  vsync = 1'b0;
    reg                  href = 1'b0;
    reg [7:0]            cam_d = 8'h00;

    wire                 wr_en;
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [11:0]          wr_data;
    wire                 frame_done;
    wire                 frame_active;

    integer errors;
    integer expected_count;
    integer observed_count;
    reg [ADDR_WIDTH-1:0] expected_addr [0:MAX_EXPECTED_WRITES-1];
    reg [11:0] expected_data [0:MAX_EXPECTED_WRITES-1];

    reg monitor_valid;
    reg prev_wr_en;
    reg [ADDR_WIDTH-1:0] prev_wr_addr;

    ov7670_capture_rgb565 #(
        .FRAME_PIXELS (FRAME_PIXELS),
        .ADDR_WIDTH   (ADDR_WIDTH)
    ) dut (
        .pclk         (pclk),
        .rst          (rst),
        .vsync        (vsync),
        .href         (href),
        .cam_d        (cam_d),
        .wr_en        (wr_en),
        .wr_addr      (wr_addr),
        .wr_data      (wr_data),
        .frame_done   (frame_done),
        .frame_active (frame_active)
    );

    always #5 pclk = ~pclk;

    function automatic [11:0] rgb565_to_rgb444(input [15:0] rgb565);
        begin
            rgb565_to_rgb444 = {rgb565[15:12], rgb565[10:7], rgb565[4:1]};
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

    task automatic queue_write(
        input [ADDR_WIDTH-1:0] addr,
        input [11:0] data
    );
        begin
            check_signal(expected_count < MAX_EXPECTED_WRITES,
                         "testbench expected-write queue overflow");

            expected_addr[expected_count] = addr;
            expected_data[expected_count] = data;
            expected_count = expected_count + 1;
        end
    endtask

    always @(posedge pclk) begin
        #1;

        if (rst) begin
            monitor_valid = 1'b0;
            prev_wr_en = 1'b0;
            prev_wr_addr = wr_addr;
        end else begin
            check_signal(!(wr_en && vsync),
                         "wr_en must be low on cycles sampled with vsync high");
            check_signal(!(wr_en && prev_wr_en),
                         "wr_en should be a one-pclk pulse");

            if (monitor_valid && !wr_en && !vsync) begin
                check_signal(wr_addr === prev_wr_addr,
                             "wr_addr should hold when no write occurs");
            end

            if (wr_en) begin
                check_signal(observed_count < expected_count,
                             "DUT produced an unexpected write");

                if (observed_count < expected_count) begin
                    check_signal(wr_addr === expected_addr[observed_count],
                                 $sformatf("write %0d address expected %0d got %0d",
                                           observed_count,
                                           expected_addr[observed_count],
                                           wr_addr));
                    check_signal(wr_data === expected_data[observed_count],
                                 $sformatf("write %0d data expected 0x%03h got 0x%03h",
                                           observed_count,
                                           expected_data[observed_count],
                                           wr_data));
                end

                observed_count = observed_count + 1;
            end

            monitor_valid = 1'b1;
            prev_wr_en = wr_en;
            prev_wr_addr = wr_addr;
        end
    end

    task automatic clear_scoreboard;
        begin
            expected_count = 0;
            observed_count = 0;
            monitor_valid = 1'b0;
            prev_wr_en = 1'b0;
            prev_wr_addr = {ADDR_WIDTH{1'b0}};
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge pclk);
            rst = 1'b1;
            vsync = 1'b0;
            href = 1'b0;
            cam_d = 8'h00;
            clear_scoreboard();

            repeat (3) @(posedge pclk);
            #2;
            check_signal(wr_en === 1'b0, "wr_en should reset low");
            check_signal(wr_addr === {ADDR_WIDTH{1'b0}},
                         "wr_addr should reset to zero");
            check_signal(wr_data === 12'h000, "wr_data should reset to zero");
            check_signal(frame_done === 1'b0,
                         "frame_done should reset low");
            check_signal(frame_active === 1'b0,
                         "frame_active should reset low");

            @(negedge pclk);
            rst = 1'b0;
            repeat (1) @(posedge pclk);
            #2;
            check_signal(wr_en === 1'b0,
                         "wr_en should stay low after reset release");
            check_signal(frame_done === 1'b0,
                         "frame_done should stay low after reset release");
            check_signal(frame_active === 1'b0,
                         "frame_active should stay low before capture starts");
        end
    endtask

    task automatic drive_byte(input [7:0] value);
        begin
            @(negedge pclk);
            vsync = 1'b0;
            href = 1'b1;
            cam_d = value;
            @(posedge pclk);
            #2;
        end
    endtask

    task automatic drive_pixel(input [15:0] rgb565);
        begin
            drive_byte(rgb565[15:8]);
            drive_byte(rgb565[7:0]);
        end
    endtask

    task automatic drive_expected_pixel(
        input [ADDR_WIDTH-1:0] addr,
        input [15:0] rgb565
    );
        begin
            queue_write(addr, rgb565_to_rgb444(rgb565));
            drive_pixel(rgb565);
        end
    endtask

    task automatic end_line;
        begin
            @(negedge pclk);
            vsync = 1'b0;
            href = 1'b0;
            cam_d = 8'h00;
            @(posedge pclk);
            #2;
        end
    endtask

    task automatic idle_cycles(input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) begin
                end_line();
            end
        end
    endtask

    task automatic pulse_vsync(
        input bit href_value,
        input [7:0] data_value,
        input bit expect_done,
        input string label
    );
        begin
            @(negedge pclk);
            vsync = 1'b1;
            href = href_value;
            cam_d = data_value;
            @(posedge pclk);
            #2;

            check_signal(wr_en === 1'b0,
                         $sformatf("%s wr_en should be low during vsync",
                                   label));
            check_signal(frame_done === expect_done,
                         $sformatf("%s frame_done mismatch", label));
            check_signal(frame_active === 1'b0,
                         $sformatf("%s frame_active should clear on vsync",
                                   label));
            check_signal(wr_addr === {ADDR_WIDTH{1'b0}},
                         $sformatf("%s wr_addr should reset on vsync",
                                   label));

            @(negedge pclk);
            vsync = 1'b0;
            href = 1'b0;
            cam_d = 8'h00;
            @(posedge pclk);
            #2;

            check_signal(frame_done === 1'b0,
                         $sformatf("%s frame_done should be one pclk",
                                   label));
            check_signal(wr_en === 1'b0,
                         $sformatf("%s wr_en should remain low after vsync",
                                   label));
        end
    endtask

    task automatic expect_all_writes(input string label);
        begin
            idle_cycles(1);
            check_signal(observed_count == expected_count,
                         $sformatf("%s observed %0d write(s), expected %0d",
                                   label, observed_count, expected_count));
        end
    endtask

    task automatic run_short_line_case;
        begin
            $display("INFO: running short valid line case");
            reset_dut();

            queue_write(17'd0, rgb565_to_rgb444(16'hf800));
            drive_byte(8'hf8);
            check_signal(frame_active === 1'b1,
                         "frame_active should assert after first valid byte");
            check_signal(observed_count == 0,
                         "first byte alone should not produce a write");
            drive_byte(8'h00);

            drive_expected_pixel(17'd1, 16'h07e0);
            drive_expected_pixel(17'd2, 16'h001f);
            end_line();

            expect_all_writes("short valid line");
        end
    endtask

    task automatic run_line_gap_case;
        integer before_gap_count;
        begin
            $display("INFO: running line gap and partial-byte clear case");
            reset_dut();

            drive_expected_pixel(17'd0, 16'ha55a);
            drive_byte(8'h12);
            end_line();

            before_gap_count = observed_count;
            idle_cycles(3);
            check_signal(observed_count == before_gap_count,
                         "line gap should not produce writes");

            drive_expected_pixel(17'd1, 16'h3456);
            end_line();

            expect_all_writes("line gap");
        end
    endtask

    task automatic run_frame_boundary_case;
        begin
            $display("INFO: running frame boundary reset case");
            reset_dut();

            drive_expected_pixel(17'd0, 16'h0ff0);
            drive_byte(8'hc3);
            pulse_vsync(1'b1, 8'h3c, 1'b1, "non-empty frame boundary");

            drive_expected_pixel(17'd0, 16'h1234);
            end_line();

            expect_all_writes("frame boundary reset");
        end
    endtask

    task automatic run_incomplete_pair_case;
        begin
            $display("INFO: running incomplete byte-pair case");
            reset_dut();

            drive_byte(8'hde);
            end_line();
            check_signal(observed_count == 0,
                         "incomplete line-end byte should not write");

            pulse_vsync(1'b0, 8'h00, 1'b0, "empty frame boundary");
            drive_expected_pixel(17'd0, 16'h07e0);
            end_line();

            expect_all_writes("incomplete byte pair");
        end
    endtask

    task automatic run_address_cap_case;
        begin
            $display("INFO: running address cap case");
            reset_dut();

            drive_expected_pixel(17'd0, 16'h0000);
            drive_expected_pixel(17'd1, 16'hffff);
            drive_expected_pixel(17'd2, 16'hf81f);
            drive_expected_pixel(17'd3, 16'h07e0);

            drive_pixel(16'h001f);
            drive_pixel(16'haaaa);
            end_line();

            expect_all_writes("address cap");
            check_signal(wr_addr === 17'd3,
                         "wr_addr should hold at final accepted address");

            pulse_vsync(1'b0, 8'h00, 1'b1, "full frame boundary");
        end
    endtask

    initial begin
        $dumpfile("sim/run/tb_ov7670_capture.vcd");
        $dumpvars(0, tb_ov7670_capture);

        errors = 0;
        clear_scoreboard();

        run_short_line_case();
        run_line_gap_case();
        run_frame_boundary_case();
        run_incomplete_pair_case();
        run_address_cap_case();

        if (errors == 0) begin
            $display("PASS: OV7670 RGB565 capture byte assembly, RGB444 conversion, frame control, and address cap verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_ov7670_capture found %0d error(s).", errors);
    end

endmodule
