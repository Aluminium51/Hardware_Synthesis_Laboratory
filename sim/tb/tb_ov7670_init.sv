`timescale 1ns/1ps

module tb_ov7670_init;

    localparam int STARTUP_DELAY_CLKS = 4;
    localparam int POST_RESET_DELAY_CLKS = 3;
    localparam int FAKE_SCCB_BUSY_CLKS = 3;
    localparam int ROM_COUNT = 167;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        start_init = 1'b0;
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

    task automatic reset_dut(input integer nack_at);
        begin
            rst = 1'b1;
            start_init = 1'b0;
            fail_index = nack_at;
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
            reset_dut(-1);

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
            reset_dut(fail_at);

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

            rom_probe_index = 8'd165;
            #1;
            check_signal(rom_probe_addr === expected_addr[165],
                         "ROM entry 165 address mismatch");
            check_signal(rom_probe_data === expected_data[165],
                         "ROM entry 165 data mismatch");
            check_signal(rom_probe_last === 1'b0,
                         "ROM entry 165 should not be marked last");

            rom_probe_index = 8'd166;
            #1;
            check_signal(rom_probe_addr === expected_addr[166],
                         "final ROM entry address mismatch");
            check_signal(rom_probe_data === expected_data[166],
                         "final ROM entry data mismatch");
            check_signal(rom_probe_last === 1'b1,
                         "final ROM entry should be marked last");

            rom_probe_index = 8'hff;
            #1;
            check_signal(rom_probe_addr === expected_addr[166],
                         "invalid ROM index should return final entry address");
            check_signal(rom_probe_data === expected_data[166],
                         "invalid ROM index should return final entry data");
            check_signal(rom_probe_last === 1'b1,
                         "invalid ROM index should return is_last high");
        end
    endtask

    initial begin
        integer i;

        $dumpfile("sim/run/tb_ov7670_init.vcd");
        $dumpvars(0, tb_ov7670_init);

        errors = 0;
        fail_index = -1;
        rom_probe_index = 8'd0;
        clear_recorded_cycles();

        for (i = 0; i < ROM_COUNT; i = i + 1) begin
            rom_probe_index = i[7:0];
            #1;
            expected_addr[i] = rom_probe_addr;
            expected_data[i] = rom_probe_data;
        end

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
