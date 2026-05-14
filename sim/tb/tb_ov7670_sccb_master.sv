`timescale 1ns/1ps

module tb_ov7670_sccb_master;

    localparam int SCCB_HALF_PERIOD_CLKS = 3;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        start = 1'b0;
    reg [7:0]  dev_addr = 8'h00;
    reg [7:0]  reg_addr = 8'h00;
    reg [7:0]  reg_data = 8'h00;

    wire       busy;
    wire       done;
    wire       ack_error;
    wire       sioc;
    wire       siod_oe;
    wire       siod_out;
    wire       siod_in;
    wire       siod_line;

    integer errors;
    integer ack_count;
    integer nack_index;
    integer stop_sioc_rises;
    reg     stop_count_enable;

    wire target_ack_low =
        busy && !siod_oe && ((nack_index < 0) || (ack_count != nack_index));

    assign siod_line = siod_oe ? siod_out : (target_ack_low ? 1'b0 : 1'b1);
    assign siod_in = siod_line;

    ov7670_sccb_master #(
        .SCCB_HALF_PERIOD_CLKS(SCCB_HALF_PERIOD_CLKS)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .dev_addr  (dev_addr),
        .reg_addr  (reg_addr),
        .reg_data  (reg_data),
        .siod_in   (siod_in),
        .busy      (busy),
        .done      (done),
        .ack_error (ack_error),
        .sioc      (sioc),
        .siod_oe   (siod_oe),
        .siod_out  (siod_out)
    );

    always #5 clk = ~clk;

    always @(posedge sioc) begin
        if (stop_count_enable) begin
            stop_sioc_rises++;
        end
    end

    task automatic check_signal(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t: %s", $time, message);
            end
        end
    endtask

    task automatic reset_dut;
        begin
            rst = 1'b1;
            start = 1'b0;
            dev_addr = 8'h00;
            reg_addr = 8'h00;
            reg_data = 8'h00;
            ack_count = 0;
            nack_index = -1;
            stop_sioc_rises = 0;
            stop_count_enable = 1'b0;

            repeat (4) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            repeat (2) @(posedge clk);
            #1;

            check_signal(busy === 1'b0, "busy should be low after reset");
            check_signal(done === 1'b0, "done should be low after reset");
            check_signal(ack_error === 1'b0, "ack_error should be low after reset");
            check_signal(sioc === 1'b1, "sioc should idle high after reset");
            check_signal(siod_oe === 1'b0, "siod should be released after reset");
            check_signal(siod_line === 1'b1, "siod line should idle high after reset");
        end
    endtask

    task automatic start_transaction(
        input [7:0] dev_value,
        input [7:0] reg_value,
        input [7:0] data_value,
        input integer nack_at
    );
        begin
            ack_count = 0;
            nack_index = nack_at;

            @(negedge clk);
            dev_addr = dev_value;
            reg_addr = reg_value;
            reg_data = data_value;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            @(posedge clk);
            #1;
            check_signal(busy === 1'b1, "busy should assert after start");
            check_signal(done === 1'b0, "done should not assert at start");
            check_signal(ack_error === 1'b0, "ack_error should clear at start");
        end
    endtask

    task automatic expect_start_condition(input string label);
        reg saw_start;
        begin
            saw_start = 1'b0;

            while (!saw_start) begin
                @(negedge siod_line);
                #1;

                if (sioc === 1'b1) begin
                    saw_start = 1'b1;
                end
            end

            check_signal(siod_oe === 1'b1,
                         $sformatf("%s start should be driven by FPGA", label));
        end
    endtask

    task automatic read_byte(output [7:0] value, input string label);
        integer bit_num;
        begin
            value = 8'h00;

            for (bit_num = 7; bit_num >= 0; bit_num = bit_num - 1) begin
                @(posedge sioc);
                #1;
                check_signal(siod_oe === 1'b1,
                             $sformatf("%s bit %0d should be FPGA-driven",
                                       label, bit_num));
                check_signal(siod_line === siod_out,
                             $sformatf("%s bit %0d line should match siod_out",
                                       label, bit_num));
                value[bit_num] = siod_line;
            end
        end
    endtask

    task automatic read_ack(input bit expect_nack, input string label);
        begin
            wait (siod_oe === 1'b0);
            #1;
            check_signal(sioc === 1'b0,
                         $sformatf("%s ACK phase should begin with SIOC low",
                                   label));
            check_signal(siod_line === (expect_nack ? 1'b1 : 1'b0),
                         $sformatf("%s ACK low phase line level mismatch",
                                   label));

            @(posedge sioc);
            #1;
            check_signal(siod_oe === 1'b0,
                         $sformatf("%s ACK phase should release SIOD", label));
            check_signal(siod_line === (expect_nack ? 1'b1 : 1'b0),
                         $sformatf("%s ACK high phase line level mismatch",
                                   label));

            @(negedge sioc);
            #1;
            ack_count++;
        end
    endtask

    task automatic expect_stop_condition(
        input integer expected_sioc_rises,
        input string label
    );
        reg saw_stop;
        begin
            saw_stop = 1'b0;
            stop_sioc_rises = 0;
            stop_count_enable = 1'b1;

            while (!saw_stop) begin
                @(posedge siod_line);
                #1;

                if (sioc === 1'b1) begin
                    saw_stop = 1'b1;
                end
            end

            stop_count_enable = 1'b0;

            check_signal(stop_sioc_rises == expected_sioc_rises,
                         $sformatf("%s STOP should follow the expected SIOC sequence: expected %0d rises got %0d",
                                   label, expected_sioc_rises,
                                   stop_sioc_rises));
            check_signal(siod_oe === 1'b1,
                         $sformatf("%s STOP condition should be FPGA-driven",
                                   label));
        end
    endtask

    task automatic wait_for_done(input bit expected_ack_error, input string label);
        begin
            wait (done === 1'b1);
            #1;

            check_signal(busy === 1'b0,
                         $sformatf("%s busy should be low with done", label));
            check_signal(ack_error === expected_ack_error,
                         $sformatf("%s ack_error mismatch at done", label));
            check_signal(sioc === 1'b1,
                         $sformatf("%s SIOC should be high at done", label));
            check_signal(siod_oe === 1'b0,
                         $sformatf("%s SIOD should be released at done", label));

            @(posedge clk);
            #1;
            check_signal(done === 1'b0,
                         $sformatf("%s done should be a one-cycle pulse",
                                   label));

            @(posedge clk);
            #1;
            check_signal(busy === 1'b0,
                         $sformatf("%s should remain idle after completion",
                                   label));
            check_signal(ack_error === 1'b0,
                         $sformatf("%s ack_error should clear in idle", label));
            check_signal(sioc === 1'b1,
                         $sformatf("%s SIOC should idle high", label));
            check_signal(siod_oe === 1'b0,
                         $sformatf("%s SIOD should idle released", label));
        end
    endtask

    task automatic run_success_case;
        reg [7:0] observed;
        begin
            $display("INFO: running SCCB ACK-success transaction");

            start_transaction(8'h42, 8'h12, 8'ha5, -1);
            expect_start_condition("success");

            read_byte(observed, "success dev_addr");
            check_signal(observed == 8'h42,
                         $sformatf("success dev_addr expected 0x42 got 0x%02h",
                                   observed));
            read_ack(1'b0, "success dev_addr");

            read_byte(observed, "success reg_addr");
            check_signal(observed == 8'h12,
                         $sformatf("success reg_addr expected 0x12 got 0x%02h",
                                   observed));
            read_ack(1'b0, "success reg_addr");

            read_byte(observed, "success reg_data");
            check_signal(observed == 8'ha5,
                         $sformatf("success reg_data expected 0xa5 got 0x%02h",
                                   observed));
            read_ack(1'b0, "success reg_data");

            expect_stop_condition(1, "success");
            wait_for_done(1'b0, "success");
        end
    endtask

    task automatic run_nack_case;
        reg [7:0] observed;
        begin
            $display("INFO: running SCCB NACK transaction");

            start_transaction(8'h42, 8'h34, 8'h5a, 1);
            expect_start_condition("nack");

            read_byte(observed, "nack dev_addr");
            check_signal(observed == 8'h42,
                         $sformatf("nack dev_addr expected 0x42 got 0x%02h",
                                   observed));
            read_ack(1'b0, "nack dev_addr");

            read_byte(observed, "nack reg_addr");
            check_signal(observed == 8'h34,
                         $sformatf("nack reg_addr expected 0x34 got 0x%02h",
                                   observed));
            read_ack(1'b1, "nack reg_addr");

            expect_stop_condition(1, "nack");
            wait_for_done(1'b1, "nack");
        end
    endtask

    initial begin
        // $dumpfile("sim/run/tb_ov7670_sccb_master.vcd");
        $dumpfile("tb_ov7670_sccb_master.vcd");
        $dumpvars(0, tb_ov7670_sccb_master);

        errors = 0;
        reset_dut();

        run_success_case();
        run_nack_case();

        if (errors == 0) begin
            $display("PASS: SCCB master start, byte order, ACK success, NACK handling, STOP, and handshake verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_ov7670_sccb_master found %0d error(s).", errors);
    end

endmodule
