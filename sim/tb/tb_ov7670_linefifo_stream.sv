`timescale 1ns/1ps

module tb_ov7670_linefifo_stream;

    localparam int LINE_PIXELS = 8;
    localparam int BANK_COUNT = 4;
    localparam int ADDR_WIDTH = 3;
    localparam int PTR_WIDTH = 3;
    localparam int BANK_SEL_WIDTH = 2;
    localparam int TEST_LINES = 3;

    reg pclk = 1'b0;
    reg clk_100 = 1'b0;
    reg rst = 1'b1;
    reg vsync = 1'b1;
    reg href = 1'b0;
    reg [7:0] cam_d = 8'h00;

    reg pixel_ce = 1'b0;
    reg [9:0] vga_x = 10'd0;
    reg [9:0] vga_y = 10'd0;
    reg hsync_in = 1'b1;
    reg vsync_in = 1'b1;
    reg active_video_in = 1'b0;
    reg frame_sync = 1'b0;

    wire [PTR_WIDTH-1:0] wr_gray;
    wire [BANK_SEL_WIDTH-1:0] wr_bank;
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [15:0] wr_data;
    wire wr_en;
    wire frame_done;
    wire frame_active;
    wire overflow;
    wire frame_drop;
    wire [35:0] bank_line_y;
    wire [3:0] bank_frame_start;
    wire dbg_line_seen;
    wire dbg_line_ge_width;
    wire dbg_line_ge_width_plus_1;
    wire dbg_line_ge_width_plus_extra;

    wire [PTR_WIDTH-1:0] rd_gray;
    wire [PTR_WIDTH-1:0] wr_gray_sync;
    wire [PTR_WIDTH-1:0] rd_gray_sync;
    wire [BANK_SEL_WIDTH-1:0] rd_bank;
    wire [ADDR_WIDTH-1:0] rd_addr;
    wire rd_en;
    wire hsync_out;
    wire vsync_out;
    wire active_video_out;
    wire [15:0] rgb565_out;
    wire underflow;
    wire line_repeat_event;
    wire line_drop_event;
    wire frame_wrap_event;
    wire seam_active_event;
    wire vblank_repeat_event;
    wire vblank_drop_event;
    wire frame_resync_event;
    wire [PTR_WIDTH-1:0] lines_available_dbg;
    wire stream_ready_dbg;

    wire [15:0] bank0_rd_data;
    wire [15:0] bank1_rd_data;
    wire [15:0] bank2_rd_data;
    wire [15:0] bank3_rd_data;

    wire bank0_wr_en = wr_en && (wr_bank == 2'd0);
    wire bank1_wr_en = wr_en && (wr_bank == 2'd1);
    wire bank2_wr_en = wr_en && (wr_bank == 2'd2);
    wire bank3_wr_en = wr_en && (wr_bank == 2'd3);
    wire bank0_rd_en = rd_en && (rd_bank == 2'd0);
    wire bank1_rd_en = rd_en && (rd_bank == 2'd1);
    wire bank2_rd_en = rd_en && (rd_bank == 2'd2);
    wire bank3_rd_en = rd_en && (rd_bank == 2'd3);

    assign wr_gray_sync = wr_gray;
    assign rd_gray_sync = rd_gray;

    line_buffer_bank #(
        .DATA_WIDTH (16),
        .LINE_PIXELS (LINE_PIXELS),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_bank0 (
        .wr_clk  (pclk),
        .wr_en   (bank0_wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_clk  (clk_100),
        .rd_en   (bank0_rd_en),
        .rd_addr (rd_addr),
        .rd_data (bank0_rd_data)
    );

    line_buffer_bank #(
        .DATA_WIDTH (16),
        .LINE_PIXELS (LINE_PIXELS),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_bank1 (
        .wr_clk  (pclk),
        .wr_en   (bank1_wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_clk  (clk_100),
        .rd_en   (bank1_rd_en),
        .rd_addr (rd_addr),
        .rd_data (bank1_rd_data)
    );

    line_buffer_bank #(
        .DATA_WIDTH (16),
        .LINE_PIXELS (LINE_PIXELS),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_bank2 (
        .wr_clk  (pclk),
        .wr_en   (bank2_wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_clk  (clk_100),
        .rd_en   (bank2_rd_en),
        .rd_addr (rd_addr),
        .rd_data (bank2_rd_data)
    );

    line_buffer_bank #(
        .DATA_WIDTH (16),
        .LINE_PIXELS (LINE_PIXELS),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_bank3 (
        .wr_clk  (pclk),
        .wr_en   (bank3_wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_clk  (clk_100),
        .rd_en   (bank3_rd_en),
        .rd_addr (rd_addr),
        .rd_data (bank3_rd_data)
    );

    wire [15:0] bank_rd_data =
        (rd_bank == 2'd0) ? bank0_rd_data :
        (rd_bank == 2'd1) ? bank1_rd_data :
        (rd_bank == 2'd2) ? bank2_rd_data :
                            bank3_rd_data;

    ov7670_capture_rgb565_linefifo #(
        .LINE_PIXELS     (LINE_PIXELS),
        .LINE_HEIGHT     (TEST_LINES),
        .BANK_COUNT      (BANK_COUNT),
        .ADDR_WIDTH      (ADDR_WIDTH),
        .BANK_SEL_WIDTH  (BANK_SEL_WIDTH),
        .PTR_WIDTH       (PTR_WIDTH)
    ) dut_capture (
        .pclk                     (pclk),
        .rst                      (rst),
        .vsync                    (vsync),
        .href                     (href),
        .cam_d                    (cam_d),
        .rd_gray_sync             (rd_gray_sync),
        .wr_gray                  (wr_gray),
        .wr_bank                  (wr_bank),
        .wr_addr                  (wr_addr),
        .wr_data                  (wr_data),
        .wr_en                    (wr_en),
        .frame_done               (frame_done),
        .frame_active             (frame_active),
        .overflow                 (overflow),
        .frame_drop               (frame_drop),
        .bank_line_y              (bank_line_y),
        .bank_frame_start         (bank_frame_start),
        .dbg_line_seen            (dbg_line_seen),
        .dbg_line_ge_width        (dbg_line_ge_width),
        .dbg_line_ge_width_plus_1 (dbg_line_ge_width_plus_1),
        .dbg_line_ge_width_plus_extra (dbg_line_ge_width_plus_extra)
    );

    vga_reader_linefifo #(
        .LINE_PIXELS     (LINE_PIXELS),
        .BANK_COUNT      (BANK_COUNT),
        .BANK_SEL_WIDTH  (BANK_SEL_WIDTH),
        .PTR_WIDTH       (PTR_WIDTH),
        .ADDR_WIDTH      (ADDR_WIDTH)
    ) dut_reader (
        .clk_100          (clk_100),
        .pixel_ce         (pixel_ce),
        .rst_vga          (rst),
        .vga_x            (vga_x),
        .vga_y            (vga_y),
        .hsync_in         (hsync_in),
        .vsync_in         (vsync_in),
        .active_video_in  (active_video_in),
        .frame_sync       (frame_sync),
        .wr_gray_sync     (wr_gray_sync),
        .bank_line_y      (bank_line_y),
        .bank_frame_start (bank_frame_start),
        .rd_data          (bank_rd_data),
        .rd_gray          (rd_gray),
        .rd_bank          (rd_bank),
        .rd_addr          (rd_addr),
        .rd_en            (rd_en),
        .hsync_out        (hsync_out),
        .vsync_out        (vsync_out),
        .active_video_out (active_video_out),
        .rgb565_out       (rgb565_out),
        .underflow        (underflow),
        .line_repeat_event (line_repeat_event),
        .line_drop_event   (line_drop_event),
        .frame_wrap_event  (frame_wrap_event),
        .seam_active_event (seam_active_event),
        .vblank_repeat_event (vblank_repeat_event),
        .vblank_drop_event (vblank_drop_event),
        .frame_resync_event (frame_resync_event),
        .lines_available_dbg (lines_available_dbg),
        .stream_ready_dbg (stream_ready_dbg)
    );

    integer errors = 0;
    integer cam_line = 0;
    integer cam_pixel = 0;
    integer vga_line = 0;
    integer vga_step = 0;
    integer observed_wr_lines = 0;
    integer observed_rd_lines = 0;
    integer current_wr_bank = -1;
    integer current_rd_bank = -1;
    integer frame_done_seen = 0;
    integer wr_pulses = 0;
    integer rd_active_lines = 0;
    reg [PTR_WIDTH-1:0] wr_gray_before_vsync = {PTR_WIDTH{1'b0}};
    reg active_video_out_d = 1'b0;
    reg scan_enable = 1'b0;
    reg frame_resync_seen = 1'b0;
    reg frame_sync_hold = 1'b0;

    always #5 clk_100 = ~clk_100;
    always #5 pclk = ~pclk;

    task automatic check(input bit condition, input string message);
        begin
            if (!condition) begin
                errors++;
                $display("ERROR time=%0t: %s", $time, message);
            end
        end
    endtask

    task automatic drive_camera_byte(input [7:0] value);
        begin
            @(negedge pclk);
            cam_d = value;
            @(posedge pclk);
        end
    endtask

    task automatic drive_pixel(input [15:0] value);
        begin
            drive_camera_byte(value[15:8]);
            drive_camera_byte(value[7:0]);
        end
    endtask

    task automatic drive_line(input integer line_idx);
        integer px;
        reg [15:0] pixel;
        begin
            href = 1'b1;
            for (px = 0; px < LINE_PIXELS; px = px + 1) begin
                pixel = {line_idx[3:0], px[3:0], (line_idx[3:0] ^ px[3:0]), 4'h1};
                drive_pixel(pixel);
            end
            href = 1'b0;
            repeat (2) @(posedge pclk);
        end
    endtask

    always @(posedge pclk) begin
        if (rst) begin
            cam_line <= 0;
            cam_pixel <= 0;
            current_wr_bank <= -1;
            frame_done_seen <= 0;
        end else begin
            if (frame_done) begin
                frame_done_seen <= 1;
            end
            if (wr_en && current_wr_bank < 0) begin
                current_wr_bank <= wr_bank;
            end
            if (wr_en) begin
                wr_pulses <= wr_pulses + 1;
            end
            if (wr_en) begin
                cam_pixel <= cam_pixel + 1;
            end
            if (!href && cam_pixel != 0) begin
                observed_wr_lines <= observed_wr_lines + 1;
                current_wr_bank <= -1;
                cam_pixel <= 0;
                cam_line <= cam_line + 1;
            end
        end
    end

    always @(posedge clk_100) begin
        if (rst) begin
            frame_resync_seen <= 1'b0;
        end else if (frame_resync_event) begin
            frame_resync_seen <= 1'b1;
        end
    end

    always @(posedge clk_100) begin
        if (rst) begin
            pixel_ce <= 1'b0;
            vga_line <= 0;
            vga_step <= 0;
            current_rd_bank <= -1;
            active_video_in <= 1'b0;
            active_video_out_d <= 1'b0;
            rd_active_lines <= 0;
            frame_sync <= 1'b0;
            frame_sync_hold <= 1'b0;
        end else begin
            pixel_ce <= 1'b1;
            if (!frame_sync_hold) begin
                frame_sync <= 1'b0;
            end
            active_video_out_d <= active_video_out;
            if (active_video_out && !active_video_out_d) begin
                rd_active_lines <= rd_active_lines + 1;
            end

            if (!scan_enable) begin
                active_video_in <= 1'b0;
                vga_step <= 0;
            end else begin
                if (active_video_in && current_rd_bank < 0) begin
                    current_rd_bank <= rd_bank;
                end
                if (active_video_in) begin
                    vga_step <= vga_step + 1;
                end else if (vga_step != 0) begin
                    observed_rd_lines <= observed_rd_lines + 1;
                    current_rd_bank <= -1;
                    vga_step <= 0;
                    vga_line <= vga_line + 1;
                end

                if (vga_step < LINE_PIXELS) begin
                    active_video_in <= 1'b1;
                    vga_x <= vga_step[9:0];
                end else begin
                    active_video_in <= 1'b0;
                    vga_x <= 10'd0;
                end
                vga_y <= vga_line[9:0];
                hsync_in <= 1'b1;
                vsync_in <= 1'b1;

                if (vga_step == LINE_PIXELS + 2) begin
                    vga_step <= 0;
                end
            end
        end
    end

    initial begin
        $dumpfile("sim/run/tb_ov7670_linefifo_stream.vcd");
        $dumpvars(0, tb_ov7670_linefifo_stream);

        repeat (4) @(posedge pclk);
        rst = 1'b0;
        vsync = 1'b0;

        drive_line(0);
        drive_line(1);
        drive_line(2);

        scan_enable = 1'b1;
        repeat (LINE_PIXELS + 4) @(posedge clk_100);
        scan_enable = 1'b0;

        wr_gray_before_vsync = wr_gray;
        repeat (20) @(posedge pclk);
        vsync = 1'b1;
        repeat (2) @(posedge pclk);
        vsync = 1'b0;
        repeat (10) @(posedge clk_100);

        check(wr_pulses > 0, "expected at least one camera write pulse");
        check(dbg_line_seen != 0, "expected at least one completed camera line");
        check(rd_active_lines > 0, "expected reader to output at least one active line after prefill");
        check(rd_gray != {PTR_WIDTH{1'b0}}, "expected reader pointer to advance after consuming a line");
        check(wr_gray == wr_gray_before_vsync, "camera VSYNC should not reset the continuous line FIFO write pointer");
        check(!underflow, "reader should not underflow after three-line prefill");

        check(stream_ready_dbg, "reader should still be marked ready after prefill");
        drive_line(3);
        drive_line(4);
        check(lines_available_dbg >= 3'd2, "expected at least two buffered lines before resync pulse");

        @(negedge clk_100);
        frame_sync_hold = 1'b1;
        frame_sync = 1'b1;
        vga_x = 10'd0;
        vga_y = 10'd480;
        active_video_in = 1'b0;
        repeat (2) @(posedge clk_100);
        frame_sync_hold = 1'b0;
        frame_sync = 1'b0;
        repeat (20) @(posedge clk_100);
        check(frame_resync_seen != 1'b0, "expected frame resync pulse on vblank after camera frame start");

        if (errors == 0) begin
            $display("PASS: OV7670 line-ring stream smoke test");
        end else begin
            $display("FAIL: OV7670 line-ring stream smoke test with %0d error(s)", errors);
        end

        $finish;
    end

endmodule
