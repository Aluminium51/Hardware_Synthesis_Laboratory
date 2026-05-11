`timescale 1ns/1ps

module tb_ov7670_init;

    localparam int STARTUP_DELAY_CLKS = 4;
    localparam int POST_RESET_DELAY_CLKS = 3;
    localparam int FAKE_SCCB_BUSY_CLKS = 3;
    localparam int ROM_COUNT = 173;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        start_init = 1'b0;
    reg [3:0]  profile = 4'b0000;
    reg        sccb_busy = 1'b0;
    reg        sccb_done = 1'b0;
    reg        sccb_ack_error = 1'b0;

    wire       sccb_start;
    wire [7:0] sccb_dev_addr;
    wire [7:0] sccb_reg_addr;
    wire [7:0] sccb_reg_data;
    wire       init_busy;
    wire       init_done;
    wire       init_error;

    integer errors;
    integer cycle_count;
    integer write_count;
    integer active_index;
    integer fail_index;
    integer fake_busy_count;
    integer start_cycle [0:ROM_COUNT-1];
    integer done_cycle [0:ROM_COUNT-1];
    reg [7:0] active_reg_addr;
    reg [7:0] active_reg_data;
    reg       prev_sccb_start;

    reg [7:0] expected_addr [0:ROM_COUNT-1];
    reg [7:0] expected_data [0:ROM_COUNT-1];
    reg [7:0] rom_probe_index;
    wire [7:0] rom_probe_addr;
    wire [7:0] rom_probe_data;
    wire       rom_probe_last;

    ov7670_init #(
        .STARTUP_DELAY_CLKS    (STARTUP_DELAY_CLKS),
        .POST_RESET_DELAY_CLKS (POST_RESET_DELAY_CLKS),
        .OV7670_DEV_ADDR       (8'h42)
    ) dut (
        .clk             (clk),
        .rst             (rst),
        .start_init      (start_init),
        .profile         (profile),
        .sccb_busy       (sccb_busy),
        .sccb_done       (sccb_done),
        .sccb_ack_error  (sccb_ack_error),
        .sccb_start      (sccb_start),
        .sccb_dev_addr   (sccb_dev_addr),
        .sccb_reg_addr   (sccb_reg_addr),
        .sccb_reg_data   (sccb_reg_data),
        .init_busy       (init_busy),
        .init_done       (init_done),
        .init_error      (init_error)
    );

    ov7670_reg_rom rom_probe (
        .index    (rom_probe_index),
        .profile  (profile),
        .reg_addr (rom_probe_addr),
        .reg_data (rom_probe_data),
        .is_last  (rom_probe_last)
    );

    always #5 clk = ~clk;

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t cycle=%0d: %s", $time, cycle_count, message);
            end
        end
    endtask

    task automatic clear_recorded_cycles;
        integer i;
        begin
            for (i = 0; i < ROM_COUNT; i = i + 1) begin
                start_cycle[i] = -1;
                done_cycle[i] = -1;
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            cycle_count     <= 0;
            write_count     <= 0;
            active_index    <= -1;
            fake_busy_count <= 0;
            active_reg_addr <= 8'h00;
            active_reg_data <= 8'h00;
            prev_sccb_start <= 1'b0;
            sccb_busy       <= 1'b0;
            sccb_done       <= 1'b0;
            sccb_ack_error  <= 1'b0;
        end else begin
            cycle_count <= cycle_count + 1;
            sccb_done <= 1'b0;

            check_signal(!(sccb_start && prev_sccb_start),
                         "sccb_start should be a one-cycle pulse");

            if (sccb_busy) begin
                check_signal(!sccb_start,
                             "sccb_start must not be asserted while fake SCCB is busy");
                check_signal(sccb_reg_addr === active_reg_addr,
                             "sccb_reg_addr changed while transaction was busy");
                check_signal(sccb_reg_data === active_reg_data,
                             "sccb_reg_data changed while transaction was busy");

                if (fake_busy_count == 0) begin
                    sccb_busy <= 1'b0;
                    sccb_done <= 1'b1;
                    sccb_ack_error <= (active_index == fail_index);
                    if ((active_index >= 0) && (active_index < ROM_COUNT)) begin
                        done_cycle[active_index] = cycle_count;
                    end
                end else begin
                    fake_busy_count <= fake_busy_count - 1;
                    sccb_ack_error <= 1'b0;
                end
            end else if (sccb_start) begin
                check_signal(write_count < ROM_COUNT,
                             "DUT issued more writes than the ROM contains");
                check_signal(sccb_dev_addr === 8'h42,
                             "sccb_dev_addr should stay at OV7670 write address 0x42");

                if (write_count < ROM_COUNT) begin
                    check_signal(sccb_reg_addr === expected_addr[write_count],
                                 $sformatf("write %0d register address mismatch: expected 0x%02h got 0x%02h",
                                           write_count, expected_addr[write_count], sccb_reg_addr));
                    check_signal(sccb_reg_data === expected_data[write_count],
                                 $sformatf("write %0d register data mismatch: expected 0x%02h got 0x%02h",
                                           write_count, expected_data[write_count], sccb_reg_data));
                    start_cycle[write_count] = cycle_count;
                end

                active_index    <= write_count;
                active_reg_addr <= sccb_reg_addr;
                active_reg_data <= sccb_reg_data;
                write_count     <= write_count + 1;
                sccb_busy       <= 1'b1;
                fake_busy_count <= FAKE_SCCB_BUSY_CLKS - 1;
                sccb_ack_error  <= 1'b0;
            end else begin
                sccb_ack_error <= 1'b0;
            end

            prev_sccb_start <= sccb_start;
        end
    end

    task automatic load_expected(input [3:0] profile_value);
        integer i;
        begin
            profile = profile_value;
            for (i = 0; i < ROM_COUNT; i = i + 1) begin
                rom_probe_index = i[7:0];
                #1;
                expected_addr[i] = rom_probe_addr;
                expected_data[i] = rom_probe_data;
            end
        end
    endtask

    task automatic reset_dut(input integer nack_at, input [3:0] profile_value);
        begin
            rst = 1'b1;
            start_init = 1'b0;
            fail_index = nack_at;
            load_expected(profile_value);
            clear_recorded_cycles();

            repeat (4) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            repeat (1) @(posedge clk);
            #1;

            check_signal(init_busy === 1'b0, "init_busy should be low after reset");
            check_signal(init_done === 1'b0, "init_done should be low after reset");
            check_signal(init_error === 1'b0, "init_error should be low after reset");
            check_signal(sccb_start === 1'b0, "sccb_start should be low after reset");
        end
    endtask

    task automatic pulse_start_init;
        begin
            @(negedge clk);
            start_init = 1'b1;
            @(negedge clk);
            start_init = 1'b0;
        end
    endtask

    task automatic wait_for_terminal_status;
        integer timeout;
        begin
            timeout = 0;
            while ((init_done !== 1'b1) && (init_error !== 1'b1) &&
                   (timeout < (ROM_COUNT * 12))) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            check_signal(timeout < (ROM_COUNT * 12),
                         "timeout waiting for init_done or init_error");
            #1;
        end
    endtask

    task automatic run_success_case;
        integer saved_write_count;
        begin
            $display("INFO: running OV7670 init success case");
            reset_dut(-1, 4'b0000);

            repeat (STARTUP_DELAY_CLKS + 3) @(posedge clk);
            #1;
            check_signal(write_count == 0, "no SCCB writes should occur before start_init");
            check_signal(init_busy === 1'b0, "init_busy should stay low before start_init");
            check_signal(init_done === 1'b0, "init_done should stay low before initialization");
            check_signal(init_error === 1'b0, "init_error should stay low before initialization");

            pulse_start_init();
            wait_for_terminal_status();

            check_signal(write_count == ROM_COUNT,
                         $sformatf("success should issue %0d writes, got %0d", ROM_COUNT, write_count));
            check_signal(init_done === 1'b1, "success should latch init_done");
            check_signal(init_error === 1'b0, "success should not latch init_error");
            check_signal(init_busy === 1'b0, "init_busy should drop after success");
            check_signal(start_cycle[0] >= 0, "first ROM entry should be issued");
            check_signal(start_cycle[1] >= 0, "second ROM entry should be issued");
            check_signal((start_cycle[1] - done_cycle[0]) >= POST_RESET_DELAY_CLKS,
                         "FSM should wait POST_RESET_DELAY_CLKS after COM7 soft reset");

            saved_write_count = write_count;
            pulse_start_init();
            repeat (20) @(posedge clk);
            #1;
            check_signal(write_count == saved_write_count,
                         "repeated start_init after done should not restart initialization");
            check_signal(init_done === 1'b1, "init_done should remain sticky after repeated start");
            check_signal(init_error === 1'b0, "init_error should remain low after repeated start");
        end
    endtask

    task automatic run_failure_case;
        integer fail_at;
        begin
            fail_at = 4;
            $display("INFO: running OV7670 init failure case at entry %0d", fail_at);
            reset_dut(fail_at, 4'b0000);

            pulse_start_init();
            wait_for_terminal_status();

            check_signal(write_count == (fail_at + 1),
                         $sformatf("failure should stop after failed entry: expected %0d writes got %0d",
                                   fail_at + 1, write_count));
            check_signal(init_done === 1'b0, "failure should not assert init_done");
            check_signal(init_error === 1'b1, "failure should latch init_error");
            check_signal(init_busy === 1'b0, "init_busy should drop after error");
            check_signal(dut.rom_index == fail_at,
                         "rom_index should remain on the failed entry");

            repeat (30) @(posedge clk);
            #1;
            check_signal(write_count == (fail_at + 1),
                         "DUT should not issue further writes after init_error");
            check_signal(init_error === 1'b1, "init_error should remain sticky");
        end
    endtask

    task automatic run_rom_boundary_case;
        begin
            $display("INFO: checking OV7670 register ROM boundary behavior");
            load_expected(4'b0000);

            rom_probe_index = 8'd165;
            #1;
            check_signal(rom_probe_addr === expected_addr[165],
                         "ROM entry 165 address mismatch");
            check_signal(rom_probe_data === expected_data[165],
                         "ROM entry 165 data mismatch");
            check_signal(rom_probe_last === 1'b0,
                         "ROM entry 165 should not be marked last");

            rom_probe_index = 8'd172;
            #1;
            check_signal(rom_probe_addr === expected_addr[172],
                         "final ROM entry address mismatch");
            check_signal(rom_probe_data === expected_data[172],
                         "final ROM entry data mismatch");
            check_signal(rom_probe_last === 1'b1,
                         "final ROM entry should be marked last");

            rom_probe_index = 8'hff;
            #1;
            check_signal(rom_probe_addr === expected_addr[172],
                         "invalid ROM index should return final entry address");
            check_signal(rom_probe_data === expected_data[172],
                         "invalid ROM index should return final entry data");
            check_signal(rom_probe_last === 1'b1,
                         "invalid ROM index should return is_last high");
        end
    endtask

    task automatic run_profile_case(
        input [3:0] profile_value,
        input [7:0] expected_com8,
        input [7:0] expected_com9,
        input [7:0] expected_aew,
        input [7:0] expected_aeb,
        input [7:0] expected_dnsth,
        input [7:0] expected_clkrc,
        input [7:0] expected_com17,
        input string label
    );
        begin
            $display("INFO: checking OV7670 profile %s", label);
            load_expected(profile_value);

            check_signal(expected_addr[166] === 8'h13,
                         $sformatf("%s profile entry 166 should be COM8", label));
            check_signal(expected_data[166] === expected_com8,
                         $sformatf("%s COM8 expected 0x%02h got 0x%02h",
                                   label, expected_com8, expected_data[166]));
            check_signal(expected_addr[167] === 8'h14,
                         $sformatf("%s profile entry 167 should be COM9", label));
            check_signal(expected_data[167] === expected_com9,
                         $sformatf("%s COM9 expected 0x%02h got 0x%02h",
                                   label, expected_com9, expected_data[167]));
            check_signal(expected_addr[168] === 8'h24,
                         $sformatf("%s profile entry 168 should be AEW", label));
            check_signal(expected_data[168] === expected_aew,
                         $sformatf("%s AEW expected 0x%02h got 0x%02h",
                                   label, expected_aew, expected_data[168]));
            check_signal(expected_addr[169] === 8'h25,
                         $sformatf("%s profile entry 169 should be AEB", label));
            check_signal(expected_data[169] === expected_aeb,
                         $sformatf("%s AEB expected 0x%02h got 0x%02h",
                                   label, expected_aeb, expected_data[169]));
            check_signal(expected_addr[170] === 8'h4C,
                         $sformatf("%s profile entry 170 should be DNSTH", label));
            check_signal(expected_data[170] === expected_dnsth,
                         $sformatf("%s DNSTH expected 0x%02h got 0x%02h",
                                   label, expected_dnsth, expected_data[170]));
            check_signal(expected_addr[171] === 8'h11,
                         $sformatf("%s profile entry 171 should be CLKRC", label));
            check_signal(expected_data[171] === expected_clkrc,
                         $sformatf("%s CLKRC expected 0x%02h got 0x%02h",
                                   label, expected_clkrc, expected_data[171]));
            check_signal(expected_addr[172] === 8'h42,
                         $sformatf("%s profile entry 172 should be COM17", label));
            check_signal(expected_data[172] === expected_com17,
                         $sformatf("%s COM17 expected 0x%02h got 0x%02h",
                                   label, expected_com17, expected_data[172]));
        end
    endtask

    task automatic run_scaling_profile_case(
        input [3:0] profile_value,
        input [7:0] expected_com3,
        input [7:0] expected_com14,
        input [7:0] expected_xsc,
        input [7:0] expected_ysc,
        input [7:0] expected_dcwctr,
        input [7:0] expected_pclk_div,
        input [7:0] expected_pclk_delay,
        input string label
    );
        begin
            $display("INFO: checking OV7670 scaling profile %s", label);
            load_expected(profile_value);

            check_signal(expected_addr[13] === 8'h0C,
                         $sformatf("%s entry 13 should be COM3", label));
            check_signal(expected_data[13] === expected_com3,
                         $sformatf("%s COM3 expected 0x%02h got 0x%02h",
                                   label, expected_com3, expected_data[13]));
            check_signal(expected_addr[14] === 8'h3E,
                         $sformatf("%s entry 14 should be COM14", label));
            check_signal(expected_data[14] === expected_com14,
                         $sformatf("%s COM14 expected 0x%02h got 0x%02h",
                                   label, expected_com14, expected_data[14]));
            check_signal(expected_addr[15] === 8'h70,
                         $sformatf("%s entry 15 should be SCALING_XSC", label));
            check_signal(expected_data[15] === expected_xsc,
                         $sformatf("%s SCALING_XSC expected 0x%02h got 0x%02h",
                                   label, expected_xsc, expected_data[15]));
            check_signal(expected_addr[16] === 8'h71,
                         $sformatf("%s entry 16 should be SCALING_YSC", label));
            check_signal(expected_data[16] === expected_ysc,
                         $sformatf("%s SCALING_YSC expected 0x%02h got 0x%02h",
                                   label, expected_ysc, expected_data[16]));
            check_signal(expected_addr[17] === 8'h72,
                         $sformatf("%s entry 17 should be SCALING_DCWCTR", label));
            check_signal(expected_data[17] === expected_dcwctr,
                         $sformatf("%s SCALING_DCWCTR expected 0x%02h got 0x%02h",
                                   label, expected_dcwctr, expected_data[17]));
            check_signal(expected_addr[18] === 8'h73,
                         $sformatf("%s entry 18 should be SCALING_PCLK_DIV", label));
            check_signal(expected_data[18] === expected_pclk_div,
                         $sformatf("%s SCALING_PCLK_DIV expected 0x%02h got 0x%02h",
                                   label, expected_pclk_div, expected_data[18]));
            check_signal(expected_addr[19] === 8'hA2,
                         $sformatf("%s entry 19 should be SCALING_PCLK_DELAY", label));
            check_signal(expected_data[19] === expected_pclk_delay,
                         $sformatf("%s SCALING_PCLK_DELAY expected 0x%02h got 0x%02h",
                                   label, expected_pclk_delay, expected_data[19]));
        end
    endtask

    task automatic run_window_shift_case;
        begin
            $display("INFO: checking OV7670 window shift");
            load_expected(4'b0000);

            check_signal(expected_addr[7] === 8'h32,
                         "entry 7 should be HREF low-bit packing");
            check_signal(expected_data[7] === 8'h89,
                         "HREF low-bit packing should add the 19th source-pixel shift");
            check_signal(expected_addr[8] === 8'h17,
                         "entry 8 should be HSTART");
            check_signal(expected_data[8] === 8'h16,
                         "HSTART should shift right by 19 source pixels");
            check_signal(expected_addr[9] === 8'h18,
                         "entry 9 should be HSTOP");
            check_signal(expected_data[9] === 8'h04,
                         "HSTOP should shift right by 19 source pixels");
            check_signal(expected_addr[10] === 8'h19,
                         "entry 10 should be VSTART");
            check_signal(expected_data[10] === 8'h04,
                         "VSTART high bits should shift up by two visible window steps");
            check_signal(expected_addr[11] === 8'h1A,
                         "entry 11 should be VSTOP");
            check_signal(expected_data[11] === 8'h7C,
                         "VSTOP high bits should shift with VSTART to preserve frame height");
            check_signal(expected_addr[12] === 8'h03,
                         "entry 12 should be VREF low-bit packing");
            check_signal(expected_data[12] === 8'h0A,
                         "VREF low-bit packing should stay at the known-good base value");
        end
    endtask

    task automatic run_full_vga_profile_case(
        input [3:0] profile_value,
        input [7:0] expected_href,
        input [7:0] expected_hstart,
        input [7:0] expected_hstop,
        input string label
    );
        begin
            $display("INFO: checking OV7670 full-VGA FPGA-average profile %s", label);
            load_expected(profile_value);

            check_signal(expected_addr[1] === 8'h12,
                         "entry 1 should be COM7");
            check_signal(expected_data[1] === 8'h04,
                         "full-VGA profile should request RGB output without QVGA mode");
            check_signal(expected_addr[7] === 8'h32,
                         "full-VGA entry 7 should be HREF low-bit packing");
            check_signal(expected_data[7] === expected_href,
                         $sformatf("%s full-VGA HREF expected 0x%02h got 0x%02h",
                                   label, expected_href, expected_data[7]));
            check_signal(expected_addr[8] === 8'h17,
                         "full-VGA entry 8 should be HSTART");
            check_signal(expected_data[8] === expected_hstart,
                         $sformatf("%s full-VGA HSTART expected 0x%02h got 0x%02h",
                                   label, expected_hstart, expected_data[8]));
            check_signal(expected_addr[9] === 8'h18,
                         "full-VGA entry 9 should be HSTOP");
            check_signal(expected_data[9] === expected_hstop,
                         $sformatf("%s full-VGA HSTOP expected 0x%02h got 0x%02h",
                                   label, expected_hstop, expected_data[9]));
            check_signal(expected_addr[10] === 8'h19,
                         "full-VGA entry 10 should be VSTART");
            check_signal(expected_data[10] === 8'h04,
                         "full-VGA VSTART should use the tuned edge-skip window");
            check_signal(expected_addr[11] === 8'h1A,
                         "full-VGA entry 11 should be VSTOP");
            check_signal(expected_data[11] === 8'h7C,
                         "full-VGA VSTOP should use the tuned edge-skip window");
            check_signal(expected_addr[12] === 8'h03,
                         "full-VGA entry 12 should be VREF");
            check_signal(expected_data[12] === 8'h0A,
                         "full-VGA VREF should keep the known-good low-bit packing");
        end
    endtask

    task automatic run_noise_tuning_profile_case(
        input [3:0] profile_value,
        input [7:0] expected_satctr,
        input [7:0] expected_com16,
        input string label
    );
        begin
            $display("INFO: checking OV7670 noise tuning profile %s", label);
            load_expected(profile_value);

            check_signal(expected_addr[125] === 8'hC9,
                         $sformatf("%s entry 125 should be SATCTR", label));
            check_signal(expected_data[125] === expected_satctr,
                         $sformatf("%s SATCTR expected 0x%02h got 0x%02h",
                                   label, expected_satctr, expected_data[125]));
            check_signal(expected_addr[126] === 8'h41,
                         $sformatf("%s entry 126 should be COM16", label));
            check_signal(expected_data[126] === expected_com16,
                         $sformatf("%s COM16 expected 0x%02h got 0x%02h",
                                   label, expected_com16, expected_data[126]));
        end
    endtask

    initial begin
        $dumpfile("sim/run/tb_ov7670_init.vcd");
        $dumpvars(0, tb_ov7670_init);

        errors = 0;
        fail_index = -1;
        rom_probe_index = 8'd0;
        clear_recorded_cycles();

        run_profile_case(4'b0000, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "live auto");
        run_profile_case(4'b0001, 8'hA7, 8'h00, 8'h60, 8'h50, 8'h0C, 8'h80, 8'h00,
                         "live low-noise");
        run_profile_case(4'b0010, 8'hA7, 8'h00, 8'h50, 8'h40, 8'h0C, 8'h01, 8'h00,
                         "low-speed diagnostic");
        run_profile_case(4'b0011, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h08,
                         "color bars");
        run_profile_case(4'b0100, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "live auto averaged QVGA");
        run_profile_case(4'b1000, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "full-VGA average baseline noise profile");
        run_profile_case(4'b1001, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "full-VGA average COM16 edge-auto disabled");
        run_profile_case(4'b1010, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "full-VGA average lower saturation");
        run_profile_case(4'b1011, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "full-VGA average stronger saturation reduction");
        run_profile_case(4'b1100, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "stream full-VGA alias baseline");
        run_profile_case(4'b1101, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "stream full-VGA alias COM16 edge-auto disabled");
        run_profile_case(4'b1110, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "stream full-VGA alias lower saturation");
        run_profile_case(4'b1111, 8'hE7, 8'h28, 8'h75, 8'h63, 8'h00, 8'h80, 8'h00,
                         "stream full-VGA alias stronger saturation reduction");
        run_scaling_profile_case(4'b0000, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "live auto");
        run_scaling_profile_case(4'b0001, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "live low-noise");
        run_scaling_profile_case(4'b0010, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "low-speed diagnostic");
        run_scaling_profile_case(4'b0100, 8'h04, 8'h19, 8'h3A, 8'h35, 8'hDD, 8'hF1, 8'h02,
                                 "averaged QVGA diagnostic");
        run_scaling_profile_case(4'b0011, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "color bars");
        run_scaling_profile_case(4'b1000, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "full-VGA FPGA average baseline");
        run_scaling_profile_case(4'b1001, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "full-VGA FPGA average COM16 edge-auto disabled");
        run_scaling_profile_case(4'b1010, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "full-VGA FPGA average lower saturation");
        run_scaling_profile_case(4'b1011, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "full-VGA FPGA average stronger saturation reduction");
        run_scaling_profile_case(4'b1100, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "stream full-VGA alias baseline");
        run_scaling_profile_case(4'b1101, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "stream full-VGA alias COM16 edge-auto disabled");
        run_scaling_profile_case(4'b1110, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "stream full-VGA alias lower saturation");
        run_scaling_profile_case(4'b1111, 8'h00, 8'h00, 8'h00, 8'h00, 8'h11, 8'h00, 8'h02,
                                 "stream full-VGA alias stronger saturation reduction");
        run_window_shift_case();
        run_full_vga_profile_case(4'b1000, 8'hB6, 8'h14, 8'h02, "default 8-pixel shift");
        run_full_vga_profile_case(4'b1001, 8'hB6, 8'h14, 8'h02, "COM16 edge-auto disabled");
        run_full_vga_profile_case(4'b1010, 8'hB6, 8'h14, 8'h02, "lower saturation");
        run_full_vga_profile_case(4'b1011, 8'hB6, 8'h14, 8'h02, "stronger saturation reduction");
        run_full_vga_profile_case(4'b1100, 8'hB6, 8'h14, 8'h02, "stream full-VGA alias baseline");
        run_full_vga_profile_case(4'b1101, 8'hB6, 8'h14, 8'h02, "stream full-VGA alias COM16 edge-auto disabled");
        run_full_vga_profile_case(4'b1110, 8'hB6, 8'h14, 8'h02, "stream full-VGA alias lower saturation");
        run_full_vga_profile_case(4'b1111, 8'hB6, 8'h14, 8'h02, "stream full-VGA alias stronger saturation reduction");
        run_noise_tuning_profile_case(4'b1000, 8'hF0, 8'h38, "baseline");
        run_noise_tuning_profile_case(4'b1001, 8'hF0, 8'h18, "COM16 edge-auto disabled");
        run_noise_tuning_profile_case(4'b1010, 8'hC0, 8'h18, "lower saturation");
        run_noise_tuning_profile_case(4'b1011, 8'hA0, 8'h18, "stronger saturation reduction");
        run_rom_boundary_case();
        run_success_case();
        run_failure_case();

        if (errors == 0) begin
            $display("PASS: OV7670 init ROM sequencing, startup gating, post-reset wait, SCCB failure handling, and sticky status verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_ov7670_init found %0d error(s).", errors);
    end

endmodule
