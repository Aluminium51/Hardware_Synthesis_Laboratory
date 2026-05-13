`timescale 1ns/1ps

module tb_ov7670_capture_2x2_avg;

    localparam int SRC_WIDTH = 4;
    localparam int SRC_HEIGHT = 4;
    localparam int DST_WIDTH = 2;
    localparam int DST_HEIGHT = 2;
    localparam int FRAME_PIXELS = DST_WIDTH * DST_HEIGHT;
    localparam int ADDR_WIDTH = 3;

    reg                  pclk = 1'b0;
    reg                  rst = 1'b1;
    reg                  vsync = 1'b0;
    reg                  href = 1'b0;
    reg  [7:0]           cam_d = 8'h00;
    wire                 wr_en;
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [15:0]          wr_data;
    wire                 frame_done;
    wire                 frame_active;
    wire                 dbg_line_seen;
    wire                 dbg_line_ge_width;
    wire                 dbg_line_ge_width_plus_1;
    wire                 dbg_line_ge_width_plus_extra;
    wire                 wr_en_clamped;
    wire [ADDR_WIDTH-1:0] wr_addr_clamped;
    wire [15:0]          wr_data_clamped;
    wire                 frame_done_clamped;
    wire                 frame_active_clamped;
    wire                 dbg_line_seen_clamped;
    wire                 dbg_line_ge_width_clamped;
    wire                 dbg_line_ge_width_plus_1_clamped;
    wire                 dbg_line_ge_width_plus_extra_clamped;

    integer errors;
    integer write_count;
    integer write_count_clamped;
    reg [15:0] image [0:(SRC_WIDTH*SRC_HEIGHT)-1];
    reg [15:0] expected [0:FRAME_PIXELS-1];
    reg [15:0] expected_clamped [0:FRAME_PIXELS-1];
    reg [15:0] observed [0:FRAME_PIXELS-1];
    reg [15:0] observed_clamped [0:FRAME_PIXELS-1];

    ov7670_capture_rgb565_2x2_avg #(
        .SRC_WIDTH         (SRC_WIDTH),
        .SRC_HEIGHT        (SRC_HEIGHT),
        .DST_WIDTH         (DST_WIDTH),
        .DST_HEIGHT        (DST_HEIGHT),
        .DIAG_EXTRA_PIXELS (2),
        .FRAME_PIXELS      (FRAME_PIXELS),
        .ADDR_WIDTH        (ADDR_WIDTH)
    ) dut (
        .pclk                         (pclk),
        .rst                          (rst),
        .vsync                        (vsync),
        .href                         (href),
        .cam_d                        (cam_d),
        .wr_en                        (wr_en),
        .wr_addr                      (wr_addr),
        .wr_data                      (wr_data),
        .frame_done                   (frame_done),
        .frame_active                 (frame_active),
        .dbg_line_seen                (dbg_line_seen),
        .dbg_line_ge_width            (dbg_line_ge_width),
        .dbg_line_ge_width_plus_1     (dbg_line_ge_width_plus_1),
        .dbg_line_ge_width_plus_extra (dbg_line_ge_width_plus_extra)
    );

    ov7670_capture_rgb565_2x2_avg #(
        .SRC_WIDTH            (SRC_WIDTH),
        .SRC_HEIGHT           (SRC_HEIGHT),
        .DST_WIDTH            (DST_WIDTH),
        .DST_HEIGHT           (DST_HEIGHT),
        .RIGHT_CLAMP_DST_COLS (1),
        .DIAG_EXTRA_PIXELS    (2),
        .FRAME_PIXELS         (FRAME_PIXELS),
        .ADDR_WIDTH           (ADDR_WIDTH)
    ) dut_clamped (
        .pclk                         (pclk),
        .rst                          (rst),
        .vsync                        (vsync),
        .href                         (href),
        .cam_d                        (cam_d),
        .wr_en                        (wr_en_clamped),
        .wr_addr                      (wr_addr_clamped),
        .wr_data                      (wr_data_clamped),
        .frame_done                   (frame_done_clamped),
        .frame_active                 (frame_active_clamped),
        .dbg_line_seen                (dbg_line_seen_clamped),
        .dbg_line_ge_width            (dbg_line_ge_width_clamped),
        .dbg_line_ge_width_plus_1     (dbg_line_ge_width_plus_1_clamped),
        .dbg_line_ge_width_plus_extra (dbg_line_ge_width_plus_extra_clamped)
    );

    always #5 pclk = ~pclk;

    function [15:0] pack565;
        input [4:0] r;
        input [5:0] g;
        input [4:0] b;
        begin
            pack565 = {r, g, b};
        end
    endfunction

    function [4:0] avg5;
        input [4:0] a;
        input [4:0] b;
        input [4:0] c;
        input [4:0] d;
        reg [6:0] sum;
        begin
            sum = {2'b00, a} + {2'b00, b} + {2'b00, c} + {2'b00, d} + 7'd2;
            avg5 = sum[6:2];
        end
    endfunction

    function [5:0] avg6;
        input [5:0] a;
        input [5:0] b;
        input [5:0] c;
        input [5:0] d;
        reg [7:0] sum;
        begin
            sum = {2'b00, a} + {2'b00, b} + {2'b00, c} + {2'b00, d} + 8'd2;
            avg6 = sum[7:2];
        end
    endfunction

    function [15:0] avg_rgb565_2x2;
        input [15:0] p00;
        input [15:0] p01;
        input [15:0] p10;
        input [15:0] p11;
        begin
            avg_rgb565_2x2 = {
                avg5(p00[15:11], p01[15:11], p10[15:11], p11[15:11]),
                avg6(p00[10:5],  p01[10:5],  p10[10:5],  p11[10:5]),
                avg5(p00[4:0],   p01[4:0],   p10[4:0],   p11[4:0])
            };
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

    task automatic send_line(input integer row);
        integer x;
        reg [15:0] pixel;
        begin
            @(negedge pclk);
            href = 1'b1;
            for (x = 0; x < SRC_WIDTH; x = x + 1) begin
                pixel = image[(row * SRC_WIDTH) + x];
                cam_d = pixel[15:8];
                @(negedge pclk);
                cam_d = pixel[7:0];
                @(negedge pclk);
            end
            href = 1'b0;
            cam_d = 8'h00;
            repeat (2) @(negedge pclk);
        end
    endtask

    always @(posedge pclk) begin
        #1;
        if (wr_en) begin
            check_signal(wr_addr < FRAME_PIXELS,
                         $sformatf("write address out of range: %0d", wr_addr));
            if (wr_addr < FRAME_PIXELS) begin
                observed[wr_addr] = wr_data;
            end
            write_count = write_count + 1;
        end

        if (wr_en_clamped) begin
            check_signal(wr_addr_clamped < FRAME_PIXELS,
                         $sformatf("clamped write address out of range: %0d", wr_addr_clamped));
            if (wr_addr_clamped < FRAME_PIXELS) begin
                observed_clamped[wr_addr_clamped] = wr_data_clamped;
            end
            write_count_clamped = write_count_clamped + 1;
        end
    end

    integer i;

    initial begin
        // $dumpfile("sim/run/tb_ov7670_capture_2x2_avg.vcd");
        $dumpfile("tb_ov7670_capture_2x2_avg.vcd");
        $dumpvars(0, tb_ov7670_capture_2x2_avg);

        errors = 0;
        write_count = 0;
        write_count_clamped = 0;

        image[0]  = pack565(5'd2,  6'd4,  5'd6);
        image[1]  = pack565(5'd6,  6'd8,  5'd10);
        image[2]  = pack565(5'd10, 6'd12, 5'd14);
        image[3]  = pack565(5'd14, 6'd16, 5'd18);
        image[4]  = pack565(5'd18, 6'd20, 5'd22);
        image[5]  = pack565(5'd22, 6'd24, 5'd26);
        image[6]  = pack565(5'd26, 6'd28, 5'd30);
        image[7]  = pack565(5'd30, 6'd32, 5'd2);
        image[8]  = pack565(5'd4,  6'd36, 5'd8);
        image[9]  = pack565(5'd8,  6'd40, 5'd12);
        image[10] = pack565(5'd12, 6'd44, 5'd16);
        image[11] = pack565(5'd16, 6'd48, 5'd20);
        image[12] = pack565(5'd20, 6'd52, 5'd24);
        image[13] = pack565(5'd24, 6'd56, 5'd28);
        image[14] = pack565(5'd28, 6'd60, 5'd0);
        image[15] = pack565(5'd0,  6'd0,  5'd4);

        expected[0] = avg_rgb565_2x2(image[0],  image[1],  image[4],  image[5]);
        expected[1] = avg_rgb565_2x2(image[2],  image[3],  image[6],  image[7]);
        expected[2] = avg_rgb565_2x2(image[8],  image[9],  image[12], image[13]);
        expected[3] = avg_rgb565_2x2(image[10], image[11], image[14], image[15]);
        expected_clamped[0] = expected[0];
        expected_clamped[1] = expected[0];
        expected_clamped[2] = expected[2];
        expected_clamped[3] = expected[2];

        for (i = 0; i < FRAME_PIXELS; i = i + 1) begin
            observed[i] = 16'hxxxx;
            observed_clamped[i] = 16'hxxxx;
        end

        repeat (4) @(negedge pclk);
        rst = 1'b0;
        repeat (2) @(negedge pclk);

        for (i = 0; i < SRC_HEIGHT; i = i + 1) begin
            send_line(i);
        end

        check_signal(dbg_line_seen === 1'b1,
                     "line diagnostic should report at least one line");
        check_signal(dbg_line_ge_width === 1'b1,
                     "line diagnostic should report exact source-width lines");
        check_signal(dbg_line_ge_width_plus_1 === 1'b0,
                     "line diagnostic should not report source-width-plus-one lines");
        check_signal(dbg_line_ge_width_plus_extra === 1'b0,
                     "line diagnostic should not report source-width-plus-extra lines");
        check_signal(dbg_line_seen_clamped === 1'b1,
                     "clamped line diagnostic should report at least one line");
        check_signal(dbg_line_ge_width_clamped === 1'b1,
                     "clamped line diagnostic should report exact source-width lines");

        @(negedge pclk);
        vsync = 1'b1;
        @(posedge pclk);
        #1;
        check_signal(frame_done === 1'b1, "frame_done should pulse on VSYNC after captured pixels");
        check_signal(frame_done_clamped === 1'b1,
                     "clamped frame_done should pulse on VSYNC after captured pixels");
        @(negedge pclk);
        vsync = 1'b0;

        check_signal(write_count == FRAME_PIXELS,
                     $sformatf("expected %0d averaged writes, got %0d", FRAME_PIXELS, write_count));
        check_signal(write_count_clamped == FRAME_PIXELS,
                     $sformatf("expected %0d clamped averaged writes, got %0d",
                               FRAME_PIXELS, write_count_clamped));

        for (i = 0; i < FRAME_PIXELS; i = i + 1) begin
            check_signal(observed[i] === expected[i],
                         $sformatf("averaged pixel %0d mismatch: expected 0x%04h got 0x%04h",
                                   i, expected[i], observed[i]));
            check_signal(observed_clamped[i] === expected_clamped[i],
                         $sformatf("clamped averaged pixel %0d mismatch: expected 0x%04h got 0x%04h",
                                   i, expected_clamped[i], observed_clamped[i]));
        end

        if (errors == 0) begin
            $display("PASS: OV7670 full-resolution 2x2 averaging capture verified.");
            $finish;
        end

        $fatal(1, "FAIL: tb_ov7670_capture_2x2_avg found %0d error(s).", errors);
    end

endmodule
