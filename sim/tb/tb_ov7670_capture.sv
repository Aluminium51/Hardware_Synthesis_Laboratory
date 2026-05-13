`timescale 1ns/1ps

module tb_ov7670_capture;

    localparam int FRAME_WIDTH = 3;
    localparam int FRAME_HEIGHT = 2;
    localparam int FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
    localparam int ADDR_WIDTH = 17;
    localparam int MAX_EXPECTED_WRITES = 32;

    reg                  pclk = 1'b0;
    reg                  rst = 1'b1;
    reg                  vsync = 1'b0;
    reg                  href = 1'b0;
    reg [7:0]            cam_d = 8'h00;

    wire                 wr_en;
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [15:0]          wr_data;
    wire                 frame_done;
    wire                 frame_active;
    wire                 dbg_line_seen;
    wire                 dbg_line_ge_width;
    wire                 dbg_line_ge_width_plus_1;
    wire                 dbg_line_ge_width_plus_extra;

    wire                 skip_wr_en;
    wire [ADDR_WIDTH-1:0] skip_wr_addr;
    wire [15:0]          skip_wr_data;
    wire                 skip_frame_done;
    wire                 skip_frame_active;

    wire                 skip8_wr_en;
    wire [ADDR_WIDTH-1:0] skip8_wr_addr;
    wire [15:0]          skip8_wr_data;
    wire                 skip8_frame_done;
    wire                 skip8_frame_active;

    integer errors;
    integer expected_count;
    integer observed_count;
    reg [ADDR_WIDTH-1:0] expected_addr [0:MAX_EXPECTED_WRITES-1];
    reg [15:0] expected_data [0:MAX_EXPECTED_WRITES-1];

    reg monitor_valid;
    reg prev_wr_en;
    reg [ADDR_WIDTH-1:0] prev_wr_addr;

    ov7670_capture_rgb565 #(
        .FRAME_WIDTH  (FRAME_WIDTH),
        .FRAME_HEIGHT (FRAME_HEIGHT),
        .SKIP_LEFT_PIXELS (0),
        .SKIP_TOP_LINES   (0),
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
        .frame_active (frame_active),
        .dbg_line_seen (dbg_line_seen),
        .dbg_line_ge_width (dbg_line_ge_width),
        .dbg_line_ge_width_plus_1 (dbg_line_ge_width_plus_1),
        .dbg_line_ge_width_plus_extra (dbg_line_ge_width_plus_extra)
    );

    ov7670_capture_rgb565 #(
        .FRAME_WIDTH      (FRAME_WIDTH),
        .FRAME_HEIGHT     (FRAME_HEIGHT),
        .SKIP_LEFT_PIXELS (2),
        .SKIP_TOP_LINES   (0),
        .FRAME_PIXELS     (FRAME_PIXELS),
        .ADDR_WIDTH       (ADDR_WIDTH)
    ) skip_dut (
        .pclk         (pclk),
        .rst          (rst),
        .vsync        (vsync),
        .href         (href),
        .cam_d        (cam_d),
        .wr_en        (skip_wr_en),
        .wr_addr      (skip_wr_addr),
        .wr_data      (skip_wr_data),
        .frame_done   (skip_frame_done),
        .frame_active (skip_frame_active)
    );

    ov7670_capture_rgb565 #(
        .FRAME_WIDTH      (4),
        .FRAME_HEIGHT     (2),
        .SKIP_LEFT_PIXELS (8),
        .SKIP_TOP_LINES   (0),
        .FRAME_PIXELS     (8),
        .ADDR_WIDTH       (ADDR_WIDTH)
    ) skip8_dut (
        .pclk         (pclk),
        .rst          (rst),
        .vsync        (vsync),
        .href         (href),
        .cam_d        (cam_d),
        .wr_en        (skip8_wr_en),
        .wr_addr      (skip8_wr_addr),
        .wr_data      (skip8_wr_data),
        .frame_done   (skip8_frame_done),
        .frame_active (skip8_frame_active)
    );

    always #5 pclk = ~pclk;

    function automatic [15:0] stored_pixel(input [15:0] rgb565);
        begin
            stored_pixel = rgb565;
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
        input [15:0] data
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
                                 $sformatf("write %0d data expected 0x%04h got 0x%04h",
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
            check_signal(wr_data === 16'h0000, "wr_data should reset to zero");
            check_signal(frame_done === 1'b0,
                         "frame_done should reset low");
            check_signal(frame_active === 1'b0,
                         "frame_active should reset low");
            check_signal(dbg_line_seen === 1'b0,
                         "dbg_line_seen should reset low");
            check_signal(dbg_line_ge_width === 1'b0,
                         "dbg_line_ge_width should reset low");
            check_signal(dbg_line_ge_width_plus_1 === 1'b0,
                         "dbg_line_ge_width_plus_1 should reset low");
            check_signal(dbg_line_ge_width_plus_extra === 1'b0,
                         "dbg_line_ge_width_plus_extra should reset low");

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
            check_signal(dbg_line_seen === 1'b0,
                         "dbg_line_seen should stay low before capture starts");
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
            queue_write(addr, stored_pixel(rgb565));
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
            check_signal(dbg_line_seen === 1'b0,
                         $sformatf("%s dbg_line_seen should clear on vsync",
                                   label));
            check_signal(dbg_line_ge_width === 1'b0,
                         $sformatf("%s dbg_line_ge_width should clear on vsync",
                                   label));
            check_signal(dbg_line_ge_width_plus_1 === 1'b0,
                         $sformatf("%s dbg_line_ge_width_plus_1 should clear on vsync",
                                   label));
            check_signal(dbg_line_ge_width_plus_extra === 1'b0,
                         $sformatf("%s dbg_line_ge_width_plus_extra should clear on vsync",
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

            queue_write(17'd0, stored_pixel(16'hf800));
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

            drive_expected_pixel(17'd3, 16'h3456);
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

    task automatic run_short_line_row_address_case;
        begin
            $display("INFO: running short-line row-address case");
            reset_dut();

            drive_expected_pixel(17'd0, 16'h1111);
            end_line();
            drive_expected_pixel(17'd3, 16'h2222);
            end_line();

            expect_all_writes("short-line row address");
            check_signal(wr_addr === 17'd3,
                         "second short line should start at next framebuffer row");
        end
    endtask

    task automatic run_left_skip_address_case;
        integer skip_observed;
        begin
            $display("INFO: running left-skip address case");
            reset_dut();

            skip_observed = 0;
            queue_write(17'd0, stored_pixel(16'haaaa));
            queue_write(17'd1, stored_pixel(16'hbbbb));
            queue_write(17'd2, stored_pixel(16'h1234));

            drive_pixel(16'haaaa);
            check_signal(skip_wr_en === 1'b0,
                         "skip DUT should suppress first skipped pixel");
            drive_pixel(16'hbbbb);
            check_signal(skip_wr_en === 1'b0,
                         "skip DUT should suppress second skipped pixel");
            drive_pixel(16'h1234);
            if (skip_wr_en) begin
                skip_observed = skip_observed + 1;
            end
            check_signal(skip_wr_en === 1'b1,
                         "skip DUT should write first post-skip pixel");
            check_signal(skip_wr_addr === 17'd0,
                         "skip DUT first post-skip pixel should map to address 0");
            check_signal(skip_wr_data === stored_pixel(16'h1234),
                         "skip DUT first post-skip pixel data mismatch");
            drive_pixel(16'h5678);
            if (skip_wr_en) begin
                skip_observed = skip_observed + 1;
            end
            check_signal(skip_wr_en === 1'b1,
                         "skip DUT should write second post-skip pixel");
            check_signal(skip_wr_addr === 17'd1,
                         "skip DUT second post-skip pixel should map to address 1");
            check_signal(skip_wr_data === stored_pixel(16'h5678),
                         "skip DUT second post-skip pixel data mismatch");

            end_line();

            expect_all_writes("left-skip address");
            check_signal(skip_observed == 2,
                         "skip DUT should produce exactly two observed writes");
        end
    endtask

    task automatic run_left_skip8_two_line_case;
        integer line;
        integer x_pos;
        integer skip8_observed;
        reg [15:0] pixel_value;
        reg [ADDR_WIDTH-1:0] expected_skip8_addr;
        begin
            $display("INFO: running 8-pixel left-skip two-line alignment case");
            reset_dut();

            skip8_observed = 0;

            for (line = 0; line < 2; line = line + 1) begin
                for (x_pos = 0; x_pos < 12; x_pos = x_pos + 1) begin
                    pixel_value = 16'h8000 + (line * 16) + x_pos;

                    if (x_pos < FRAME_WIDTH) begin
                        queue_write((line * FRAME_WIDTH) + x_pos,
                                    stored_pixel(pixel_value));
                    end

                    drive_pixel(pixel_value);

                    if ((x_pos < 8) || (x_pos >= 12)) begin
                        check_signal(skip8_wr_en === 1'b0,
                                     "skip8 DUT should suppress pixels outside the cropped window");
                    end else begin
                        expected_skip8_addr = (line * 4) + (x_pos - 8);

                        if (skip8_wr_en) begin
                            skip8_observed = skip8_observed + 1;
                        end

                        check_signal(skip8_wr_en === 1'b1,
                                     "skip8 DUT should write each post-skip in-window pixel");
                        check_signal(skip8_wr_addr === expected_skip8_addr,
                                     $sformatf("skip8 address expected %0d got %0d",
                                               expected_skip8_addr,
                                               skip8_wr_addr));
                        check_signal(skip8_wr_data === stored_pixel(pixel_value),
                                     $sformatf("skip8 data expected 0x%04h got 0x%04h",
                                               stored_pixel(pixel_value),
                                               skip8_wr_data));
                    end
                end

                end_line();
            end

            expect_all_writes("8-pixel left-skip two-line alignment");
            check_signal(skip8_observed == 8,
                         "skip8 DUT should produce exactly eight cropped-frame writes");
            check_signal(skip8_wr_addr === 17'd7,
                         "skip8 final write should be row 1 column 3, proving no row drift");
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
            end_line();
            drive_expected_pixel(17'd3, 16'h07e0);
            drive_expected_pixel(17'd4, 16'h001f);
            drive_expected_pixel(17'd5, 16'haaaa);
            drive_pixel(16'h5555);
            end_line();

            expect_all_writes("address cap");
            check_signal(wr_addr === 17'd5,
                         "wr_addr should hold at final accepted address");

            pulse_vsync(1'b0, 8'h00, 1'b1, "full frame boundary");
        end
    endtask

    task automatic run_overwide_line_case;
        begin
            $display("INFO: running over-wide line suppression case");
            reset_dut();

            drive_expected_pixel(17'd0, 16'h1001);
            drive_expected_pixel(17'd1, 16'h2002);
            drive_expected_pixel(17'd2, 16'h3003);
            drive_pixel(16'h4004);
            drive_pixel(16'h5005);
            end_line();

            expect_all_writes("over-wide line");
            check_signal(wr_addr === 17'd2,
                         "over-wide line should hold at final in-bounds write");
        end
    endtask

    task automatic run_overtall_frame_case;
        begin
            $display("INFO: running over-tall frame suppression case");
            reset_dut();

            drive_expected_pixel(17'd0, 16'h1111);
            end_line();
            drive_expected_pixel(17'd3, 16'h2222);
            end_line();
            drive_pixel(16'h3333);
            end_line();

            expect_all_writes("over-tall frame");
            check_signal(wr_addr === 17'd3,
                         "over-tall frame should hold at final in-bounds write");
        end
    endtask

    task automatic drive_diag_line(input integer pixel_count);
        integer pixel_index;
        reg [15:0] pixel_value;
        begin
            for (pixel_index = 0; pixel_index < pixel_count; pixel_index = pixel_index + 1) begin
                pixel_value = 16'h4000 + pixel_index[15:0];

                if (pixel_index < FRAME_WIDTH) begin
                    queue_write(pixel_index[ADDR_WIDTH-1:0], stored_pixel(pixel_value));
                end

                drive_pixel(pixel_value);
            end

            end_line();
            expect_all_writes($sformatf("diag line %0d pixels", pixel_count));
        end
    endtask

    task automatic run_line_length_debug_case;
        begin
            $display("INFO: running line-length debug flag case");

            reset_dut();
            drive_diag_line(FRAME_WIDTH - 1);
            check_signal(dbg_line_seen === 1'b1,
                         "short debug line should set dbg_line_seen");
            check_signal(dbg_line_ge_width === 1'b0,
                         "short debug line should not set dbg_line_ge_width");
            check_signal(dbg_line_ge_width_plus_1 === 1'b0,
                         "short debug line should not set dbg_line_ge_width_plus_1");
            check_signal(dbg_line_ge_width_plus_extra === 1'b0,
                         "short debug line should not set dbg_line_ge_width_plus_extra");

            reset_dut();
            drive_diag_line(FRAME_WIDTH);
            check_signal(dbg_line_seen === 1'b1,
                         "exact-width debug line should set dbg_line_seen");
            check_signal(dbg_line_ge_width === 1'b1,
                         "exact-width debug line should set dbg_line_ge_width");
            check_signal(dbg_line_ge_width_plus_1 === 1'b0,
                         "exact-width debug line should not set dbg_line_ge_width_plus_1");
            check_signal(dbg_line_ge_width_plus_extra === 1'b0,
                         "exact-width debug line should not set dbg_line_ge_width_plus_extra");

            reset_dut();
            drive_diag_line(FRAME_WIDTH + 1);
            check_signal(dbg_line_seen === 1'b1,
                         "width-plus-one debug line should set dbg_line_seen");
            check_signal(dbg_line_ge_width === 1'b1,
                         "width-plus-one debug line should set dbg_line_ge_width");
            check_signal(dbg_line_ge_width_plus_1 === 1'b1,
                         "width-plus-one debug line should set dbg_line_ge_width_plus_1");
            check_signal(dbg_line_ge_width_plus_extra === 1'b0,
                         "width-plus-one debug line should not set dbg_line_ge_width_plus_extra");

            reset_dut();
            drive_diag_line(FRAME_WIDTH + 8);
            check_signal(dbg_line_seen === 1'b1,
                         "width-plus-extra debug line should set dbg_line_seen");
            check_signal(dbg_line_ge_width === 1'b1,
                         "width-plus-extra debug line should set dbg_line_ge_width");
            check_signal(dbg_line_ge_width_plus_1 === 1'b1,
                         "width-plus-extra debug line should set dbg_line_ge_width_plus_1");
            check_signal(dbg_line_ge_width_plus_extra === 1'b1,
                         "width-plus-extra debug line should set dbg_line_ge_width_plus_extra");

            pulse_vsync(1'b0, 8'h00, 1'b1, "debug flag frame boundary");
        end
    endtask

    initial begin
        // $dumpfile("sim/run/tb_ov7670_capture.vcd");
        $dumpfile("tb_ov7670_capture.vcd");
        $dumpvars(0, tb_ov7670_capture);

        errors = 0;
        clear_scoreboard();

        run_short_line_case();
        run_line_gap_case();
        run_frame_boundary_case();
        run_incomplete_pair_case();
        run_short_line_row_address_case();
        run_left_skip_address_case();
        run_left_skip8_two_line_case();
        run_overwide_line_case();
        run_overtall_frame_case();
        run_line_length_debug_case();
        run_address_cap_case();

        if (errors == 0) begin
            $display("PASS: OV7670 RGB565 capture byte assembly, bounded frame control, line diagnostics, and address cap verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_ov7670_capture found %0d error(s).", errors);
    end

endmodule
