`timescale 1ns/1ps

// top_basys3_ov7670_vga_stream
// Purpose: OV7670 full-resolution line-buffer stream experiment for VGA output.
// Clock domains: clk_100 for VGA/control, cam_pclk for camera capture.
// Outputs: VGA sync/RGB, OV7670 control pins, SCCB pins, and debug LEDs.
// Assumptions: XCLK is fixed at the 50 MHz stream baseline; sw[2] enables diagnostics.
module top_basys3_ov7670_vga_stream (
    input  wire        clk_100,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        btnD,
    input  wire [7:0]  sw,
    output wire        Hsync,
    output wire        Vsync,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        cam_xclk,
    input  wire        cam_pclk,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_d,
    output wire        cam_sioc,
    inout  wire        cam_siod,
    output wire        cam_pwdn,
    output wire        cam_reset,
    output wire [3:0]  led
);

    wire rst_sys;

    reset_sync u_reset_sync_sys (
        .clk       (clk_100),
        .rst_async (btnC),
        .rst_sync  (rst_sys)
    );

    wire [7:0] sw_sync;

    genvar sw_i;
    generate
        for (sw_i = 0; sw_i < 8; sw_i = sw_i + 1) begin : gen_sw_sync
            sync_2ff u_sync_sw (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (sw[sw_i]),
                .q_sync  (sw_sync[sw_i])
            );
        end
    endgenerate

    wire       debug_pattern_en = sw_sync[5];
    wire       camera_diag_en = sw_sync[2];
    wire [1:0] filter_mode = sw_sync[1:0];
    reg  [3:0] camera_profile = 4'b1100;
    reg  [1:0] stream_timing_profile = 2'b00;

    // Stream-only build: keep XCLK fixed at the 50 MHz baseline and use
    // sw[4:3] only for live diagnostic page selects when sw[2] is enabled.
    always @(posedge clk_100) begin
        if (rst_sys) begin
            stream_timing_profile <= 2'b00;
            camera_profile <= 4'b1100;
        end
    end

    wire btnU_sync;
    wire btnD_sync;

    sync_2ff u_sync_btnU (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (btnU),
        .q_sync  (btnU_sync)
    );

    sync_2ff u_sync_btnD (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (btnD),
        .q_sync  (btnD_sync)
    );

    localparam integer BTN_DEBOUNCE_BITS = 19;

    reg [BTN_DEBOUNCE_BITS-1:0] btnU_count = {BTN_DEBOUNCE_BITS{1'b0}};
    reg [BTN_DEBOUNCE_BITS-1:0] btnD_count = {BTN_DEBOUNCE_BITS{1'b0}};
    reg                         btnU_state = 1'b0;
    reg                         btnD_state = 1'b0;
    reg                         btnU_state_d = 1'b0;
    reg                         btnD_state_d = 1'b0;
    reg [3:0]                   filter_threshold_reg = 4'h8;

    wire btnU_press = btnU_state && !btnU_state_d;
    wire btnD_press = btnD_state && !btnD_state_d;
    wire [3:0] filter_threshold = filter_threshold_reg;

    reg [1:0] pixel_div = 2'd0;

    always @(posedge clk_100) begin
        if (rst_sys) begin
            pixel_div <= 2'd0;
        end else begin
            pixel_div <= pixel_div + 1'b1;
        end
    end

    wire xclk_locked;
    wire rst_config = rst_sys || !xclk_locked;

    camera_xclk_mmcm u_camera_xclk_mmcm (
        .clk_100  (clk_100),
        .rst      (rst_sys),
        .rate_sel (stream_timing_profile),
        .cam_xclk (cam_xclk),
        .locked   (xclk_locked)
    );

    wire cam_vsync_sys;
    reg  cam_vsync_sys_d = 1'b0;
    reg  cam_frame_start_pending = 1'b0;
    reg [31:0] cam_frame_cycle_count = 32'd0;
    reg [31:0] cam_frame_period = 32'd0;
    reg        cam_frame_seen = 1'b0;

    sync_2ff u_sync_cam_vsync_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (cam_vsync),
        .q_sync  (cam_vsync_sys)
    );

    wire cam_frame_start_sys = cam_vsync_sys_d && !cam_vsync_sys;
    wire cam_frame_sync_sys = cam_frame_start_pending;

    localparam [31:0] VGA_FRAME_CLKS = 32'd1680000;
    localparam [31:0] FRAME_TOL_CLKS = 32'd42000;
    wire cam_too_fast = cam_frame_seen &&
                        (cam_frame_period < (VGA_FRAME_CLKS - FRAME_TOL_CLKS));
    wire cam_too_slow = cam_frame_seen &&
                        (cam_frame_period > (VGA_FRAME_CLKS + FRAME_TOL_CLKS));

    always @(posedge clk_100) begin
        if (rst_sys) begin
            cam_vsync_sys_d <= 1'b0;
            cam_frame_start_pending <= 1'b0;
            cam_frame_cycle_count <= 32'd0;
            cam_frame_period <= 32'd0;
            cam_frame_seen <= 1'b0;
        end else begin
            cam_vsync_sys_d <= cam_vsync_sys;
            cam_frame_cycle_count <= cam_frame_cycle_count + 1'b1;
            if (cam_frame_start_sys) begin
                cam_frame_start_pending <= 1'b1;
                cam_frame_period <= cam_frame_cycle_count;
                cam_frame_cycle_count <= 32'd0;
                cam_frame_seen <= 1'b1;
            end else if (pixel_ce && cam_frame_start_pending) begin
                cam_frame_start_pending <= 1'b0;
            end
        end
    end

    always @(posedge clk_100) begin
        if (rst_sys) begin
            btnU_count <= {BTN_DEBOUNCE_BITS{1'b0}};
            btnD_count <= {BTN_DEBOUNCE_BITS{1'b0}};
            btnU_state <= 1'b0;
            btnD_state <= 1'b0;
            btnU_state_d <= 1'b0;
            btnD_state_d <= 1'b0;
            filter_threshold_reg <= 4'h8;
        end else begin
            btnU_state_d <= btnU_state;
            btnD_state_d <= btnD_state;

            if (btnU_sync == btnU_state) begin
                btnU_count <= {BTN_DEBOUNCE_BITS{1'b0}};
            end else begin
                btnU_count <= btnU_count + 1'b1;
                if (&btnU_count) begin
                    btnU_state <= btnU_sync;
                    btnU_count <= {BTN_DEBOUNCE_BITS{1'b0}};
                end
            end

            if (btnD_sync == btnD_state) begin
                btnD_count <= {BTN_DEBOUNCE_BITS{1'b0}};
            end else begin
                btnD_count <= btnD_count + 1'b1;
                if (&btnD_count) begin
                    btnD_state <= btnD_sync;
                    btnD_count <= {BTN_DEBOUNCE_BITS{1'b0}};
                end
            end

            if (btnU_press && (filter_threshold_reg != 4'hF)) begin
                filter_threshold_reg <= filter_threshold_reg + 1'b1;
            end else if (btnD_press && (filter_threshold_reg != 4'h0)) begin
                filter_threshold_reg <= filter_threshold_reg - 1'b1;
            end
        end
    end

    wire pixel_ce = (pixel_div == 2'd3);
    wire hsync_timing;
    wire vsync_timing;
    wire active_video;
    wire [9:0] x;
    wire [9:0] y;

    vga_timing_640x480 u_vga_timing (
        .clk_100      (clk_100),
        .pixel_ce     (pixel_ce),
        .rst_vga      (rst_sys),
        .hsync        (hsync_timing),
        .vsync        (vsync_timing),
        .active_video (active_video),
        .x            (x),
        .y            (y)
    );

    wire [11:0] pattern_rgb444;

    test_pattern u_test_pattern (
        .x            (x),
        .y            (y),
        .active_video (active_video),
        .rgb444       (pattern_rgb444)
    );

    wire        sccb_start;
    wire [7:0]  sccb_dev_addr;
    wire [7:0]  sccb_reg_addr;
    wire [7:0]  sccb_reg_data;
    wire        sccb_busy;
    wire        sccb_done;
    wire        sccb_ack_error;
    wire        siod_in;
    wire        siod_oe;
    wire        siod_out;
    wire        init_done;
    wire        init_error;

    ov7670_init u_ov7670_init (
        .clk            (clk_100),
        .rst            (rst_config),
        .start_init     (1'b1),
        .profile        (camera_profile),
        .sccb_busy      (sccb_busy),
        .sccb_done      (sccb_done),
        .sccb_ack_error (sccb_ack_error),
        .sccb_start     (sccb_start),
        .sccb_dev_addr  (sccb_dev_addr),
        .sccb_reg_addr  (sccb_reg_addr),
        .sccb_reg_data  (sccb_reg_data),
        .init_busy      (),
        .init_done      (init_done),
        .init_error     (init_error)
    );

    ov7670_sccb_master #(
        .SCCB_HALF_PERIOD_CLKS (5000)
    ) u_ov7670_sccb_master (
        .clk       (clk_100),
        .rst       (rst_config),
        .start     (sccb_start),
        .dev_addr  (sccb_dev_addr),
        .reg_addr  (sccb_reg_addr),
        .reg_data  (sccb_reg_data),
        .siod_in   (siod_in),
        .busy      (sccb_busy),
        .done      (sccb_done),
        .ack_error (sccb_ack_error),
        .sioc      (cam_sioc),
        .siod_oe   (siod_oe),
        .siod_out  (siod_out)
    );

    assign cam_siod = (siod_oe && !siod_out) ? 1'b0 : 1'bz;
    assign siod_in  = cam_siod;

    assign cam_pwdn  = 1'b0;
    assign cam_reset = 1'b1;

    wire rst_cam_button;

    reset_sync u_reset_sync_cam (
        .clk       (cam_pclk),
        .rst_async (btnC),
        .rst_sync  (rst_cam_button)
    );

    wire init_done_cam;

    sync_2ff u_sync_init_done_cam (
        .clk     (cam_pclk),
        .rst     (rst_cam_button),
        .d_async (init_done),
        .q_sync  (init_done_cam)
    );

    wire capture_rst = rst_cam_button || !init_done_cam;

    wire [2:0] stream_wr_gray_cam;
    wire [2:0] stream_wr_gray_sys;
    wire [2:0] stream_rd_gray;
    wire [2:0] stream_rd_gray_cam;
    wire [1:0] stream_wr_bank;
    wire [9:0] stream_wr_addr;
    wire [15:0] stream_wr_data;
    wire        stream_wr_en;
    wire        stream_frame_done;
    wire        stream_overflow;
    wire        stream_frame_drop;
    wire        stream_dbg_line_seen;
    wire        stream_dbg_line_ge_width;
    wire        stream_dbg_line_ge_width_plus_1;
    wire        stream_dbg_line_ge_width_plus_extra;
    wire [35:0] stream_bank_line_y_cam;
    wire [35:0] stream_bank_line_y_sys;
    wire [3:0]  stream_bank_frame_start_cam;
    wire [3:0]  stream_bank_frame_start_sys;
    wire [1:0]  stream_rd_bank;
    wire [9:0]  stream_rd_addr;
    wire        stream_rd_en;
    wire        stream_underflow;
    wire        stream_line_repeat_event;
    wire        stream_line_drop_event;
    wire        stream_frame_wrap_event;
    wire        stream_seam_active_event;
    wire        stream_vblank_repeat_event;
    wire        stream_vblank_drop_event;
    wire        stream_frame_resync_event;
    wire [2:0]  stream_lines_available_sys;
    wire        stream_ready_sys;
    wire [15:0] stream_bank0_rd_data;
    wire [15:0] stream_bank1_rd_data;
    wire [15:0] stream_bank2_rd_data;
    wire [15:0] stream_bank3_rd_data;
    wire [15:0] stream_rd_data =
        (stream_rd_bank == 2'd0) ? stream_bank0_rd_data :
        (stream_rd_bank == 2'd1) ? stream_bank1_rd_data :
        (stream_rd_bank == 2'd2) ? stream_bank2_rd_data :
                                   stream_bank3_rd_data;

    genvar stream_sync_i;
    generate
        for (stream_sync_i = 0; stream_sync_i < 3; stream_sync_i = stream_sync_i + 1) begin : gen_stream_wr_ptr_sync
            sync_2ff u_sync_stream_wr_gray (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (stream_wr_gray_cam[stream_sync_i]),
                .q_sync  (stream_wr_gray_sys[stream_sync_i])
            );
        end
    endgenerate

    generate
        for (stream_sync_i = 0; stream_sync_i < 3; stream_sync_i = stream_sync_i + 1) begin : gen_stream_rd_ptr_sync
            sync_2ff u_sync_stream_rd_gray (
                .clk     (cam_pclk),
                .rst     (capture_rst),
                .d_async (stream_rd_gray[stream_sync_i]),
                .q_sync  (stream_rd_gray_cam[stream_sync_i])
            );
        end
    endgenerate

    generate
        for (stream_sync_i = 0; stream_sync_i < 36; stream_sync_i = stream_sync_i + 1) begin : gen_stream_line_y_sync
            sync_2ff u_sync_stream_line_y (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (stream_bank_line_y_cam[stream_sync_i]),
                .q_sync  (stream_bank_line_y_sys[stream_sync_i])
            );
        end
    endgenerate

    generate
        for (stream_sync_i = 0; stream_sync_i < 4; stream_sync_i = stream_sync_i + 1) begin : gen_stream_frame_start_sync
            sync_2ff u_sync_stream_frame_start (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (stream_bank_frame_start_cam[stream_sync_i]),
                .q_sync  (stream_bank_frame_start_sys[stream_sync_i])
            );
        end
    endgenerate

    ov7670_capture_rgb565_linefifo #(
        .LINE_PIXELS     (640),
        .LINE_HEIGHT     (480),
        .BANK_COUNT      (4),
        .ADDR_WIDTH      (10),
        .BANK_SEL_WIDTH  (2),
        .PTR_WIDTH       (3)
    ) u_ov7670_capture_linefifo (
        .pclk                     (cam_pclk),
        .rst                      (capture_rst),
        .vsync                    (cam_vsync),
        .href                     (cam_href),
        .cam_d                    (cam_d),
        .rd_gray_sync             (stream_rd_gray_cam),
        .wr_gray                  (stream_wr_gray_cam),
        .wr_bank                  (stream_wr_bank),
        .wr_addr                  (stream_wr_addr),
        .wr_data                  (stream_wr_data),
        .wr_en                    (stream_wr_en),
        .frame_done               (stream_frame_done),
        .frame_active             (),
        .overflow                 (stream_overflow),
        .frame_drop               (stream_frame_drop),
        .bank_line_y              (stream_bank_line_y_cam),
        .bank_frame_start         (stream_bank_frame_start_cam),
        .dbg_line_seen            (stream_dbg_line_seen),
        .dbg_line_ge_width        (stream_dbg_line_ge_width),
        .dbg_line_ge_width_plus_1 (stream_dbg_line_ge_width_plus_1),
        .dbg_line_ge_width_plus_extra (stream_dbg_line_ge_width_plus_extra)
    );

    wire stream_bank0_wr_en = stream_wr_en && (stream_wr_bank == 2'd0);
    wire stream_bank1_wr_en = stream_wr_en && (stream_wr_bank == 2'd1);
    wire stream_bank2_wr_en = stream_wr_en && (stream_wr_bank == 2'd2);
    wire stream_bank3_wr_en = stream_wr_en && (stream_wr_bank == 2'd3);
    wire stream_bank0_rd_en = stream_rd_en && (stream_rd_bank == 2'd0);
    wire stream_bank1_rd_en = stream_rd_en && (stream_rd_bank == 2'd1);
    wire stream_bank2_rd_en = stream_rd_en && (stream_rd_bank == 2'd2);
    wire stream_bank3_rd_en = stream_rd_en && (stream_rd_bank == 2'd3);

    line_buffer_bank u_stream_bank0 (
        .wr_clk  (cam_pclk),
        .wr_en   (stream_bank0_wr_en),
        .wr_addr (stream_wr_addr),
        .wr_data (stream_wr_data),
        .rd_clk  (clk_100),
        .rd_en   (stream_bank0_rd_en),
        .rd_addr (stream_rd_addr),
        .rd_data (stream_bank0_rd_data)
    );

    line_buffer_bank u_stream_bank1 (
        .wr_clk  (cam_pclk),
        .wr_en   (stream_bank1_wr_en),
        .wr_addr (stream_wr_addr),
        .wr_data (stream_wr_data),
        .rd_clk  (clk_100),
        .rd_en   (stream_bank1_rd_en),
        .rd_addr (stream_rd_addr),
        .rd_data (stream_bank1_rd_data)
    );

    line_buffer_bank u_stream_bank2 (
        .wr_clk  (cam_pclk),
        .wr_en   (stream_bank2_wr_en),
        .wr_addr (stream_wr_addr),
        .wr_data (stream_wr_data),
        .rd_clk  (clk_100),
        .rd_en   (stream_bank2_rd_en),
        .rd_addr (stream_rd_addr),
        .rd_data (stream_bank2_rd_data)
    );

    line_buffer_bank u_stream_bank3 (
        .wr_clk  (cam_pclk),
        .wr_en   (stream_bank3_wr_en),
        .wr_addr (stream_wr_addr),
        .wr_data (stream_wr_data),
        .rd_clk  (clk_100),
        .rd_en   (stream_bank3_rd_en),
        .rd_addr (stream_rd_addr),
        .rd_data (stream_bank3_rd_data)
    );

    wire        stream_hsync_reader;
    wire        stream_vsync_reader;
    wire        stream_active_video_reader;
    wire [15:0] stream_rgb565_reader;

    vga_reader_linefifo #(
        .LINE_PIXELS       (640),
        .BANK_COUNT        (4),
        .BANK_SEL_WIDTH    (2),
        .PTR_WIDTH         (3),
        .ADDR_WIDTH        (10),
        .MIN_PREFILL_LINES (2)
    ) u_vga_reader_linefifo (
        .clk_100          (clk_100),
        .pixel_ce         (pixel_ce),
        .rst_vga          (rst_sys),
        .vga_x            (x),
        .vga_y            (y),
        .hsync_in         (hsync_timing),
        .vsync_in         (vsync_timing),
        .active_video_in  (active_video),
        .frame_sync       (cam_frame_sync_sys),
        .wr_gray_sync     (stream_wr_gray_sys),
        .bank_line_y      (stream_bank_line_y_sys),
        .bank_frame_start (stream_bank_frame_start_sys),
        .rd_data          (stream_rd_data),
        .rd_gray          (stream_rd_gray),
        .rd_bank          (stream_rd_bank),
        .rd_addr          (stream_rd_addr),
        .rd_en            (stream_rd_en),
        .hsync_out        (stream_hsync_reader),
        .vsync_out        (stream_vsync_reader),
        .active_video_out (stream_active_video_reader),
        .rgb565_out       (stream_rgb565_reader),
        .underflow        (stream_underflow),
        .line_repeat_event (stream_line_repeat_event),
        .line_drop_event   (stream_line_drop_event),
        .frame_wrap_event  (stream_frame_wrap_event),
        .seam_active_event (stream_seam_active_event),
        .vblank_repeat_event (stream_vblank_repeat_event),
        .vblank_drop_event (stream_vblank_drop_event),
        .frame_resync_event (stream_frame_resync_event),
        .lines_available_dbg (stream_lines_available_sys),
        .stream_ready_dbg (stream_ready_sys)
    );

    wire [15:0] filtered_rgb565;

    video_filter_basic u_video_filter_basic (
        .rgb565_in  (stream_rgb565_reader),
        .mode       (filter_mode),
        .threshold  (filter_threshold),
        .rgb565_out (filtered_rgb565)
    );

    function [3:0] round5_to4;
        input [4:0] value;
        reg [5:0] rounded;
        begin
            rounded = {1'b0, value} + 6'd1;
            round5_to4 = rounded[5] ? 4'hf : rounded[4:1];
        end
    endfunction

    function [3:0] round6_to4;
        input [5:0] value;
        reg [6:0] rounded;
        begin
            rounded = {1'b0, value} + 7'd2;
            round6_to4 = rounded[6] ? 4'hf : rounded[5:2];
        end
    endfunction

    function [11:0] rgb565_to_rgb444;
        input [15:0] rgb565;
        begin
            rgb565_to_rgb444 = {
                round5_to4(rgb565[15:11]),
                round6_to4(rgb565[10:5]),
                round5_to4(rgb565[4:0])
            };
        end
    endfunction

    wire [11:0] filtered_rgb444 = rgb565_to_rgb444(filtered_rgb565);
    wire [11:0] camera_rgb444 = (init_done && stream_active_video_reader) ?
                                filtered_rgb444 : 12'h000;
    wire [11:0] display_rgb444 = debug_pattern_en ? pattern_rgb444 : camera_rgb444;

    assign Hsync = debug_pattern_en ? hsync_timing : stream_hsync_reader;
    assign Vsync = debug_pattern_en ? vsync_timing : stream_vsync_reader;
    assign vgaRed   = display_rgb444[11:8];
    assign vgaGreen = display_rgb444[7:4];
    assign vgaBlue  = display_rgb444[3:0];

    wire stream_overflow_sys;
    wire stream_frame_drop_sys;

    sync_2ff u_sync_stream_overflow_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (stream_overflow),
        .q_sync  (stream_overflow_sys)
    );

    sync_2ff u_sync_stream_frame_drop_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (stream_frame_drop),
        .q_sync  (stream_frame_drop_sys)
    );

    reg [25:0] heartbeat = 26'd0;
    reg stream_underflow_sticky = 1'b0;
    reg stream_overflow_sticky = 1'b0;
    reg stream_repeat_sticky = 1'b0;
    reg stream_drop_sticky = 1'b0;
    reg stream_frame_wrap_sticky = 1'b0;
    reg stream_seam_active_sticky = 1'b0;
    reg stream_vblank_repeat_sticky = 1'b0;
    reg stream_vblank_drop_sticky = 1'b0;
    reg stream_frame_resync_sticky = 1'b0;
    always @(posedge clk_100) begin
        if (rst_sys) begin
            heartbeat <= 26'd0;
            stream_underflow_sticky <= 1'b0;
            stream_overflow_sticky <= 1'b0;
            stream_repeat_sticky <= 1'b0;
            stream_drop_sticky <= 1'b0;
            stream_frame_wrap_sticky <= 1'b0;
            stream_seam_active_sticky <= 1'b0;
            stream_vblank_repeat_sticky <= 1'b0;
            stream_vblank_drop_sticky <= 1'b0;
            stream_frame_resync_sticky <= 1'b0;
        end else begin
            heartbeat <= heartbeat + 1'b1;
            if (stream_underflow) begin
                stream_underflow_sticky <= 1'b1;
            end
            if (stream_overflow_sys || stream_frame_drop_sys) begin
                stream_overflow_sticky <= 1'b1;
            end
            if (stream_line_repeat_event) begin
                stream_repeat_sticky <= 1'b1;
            end
            if (stream_line_drop_event) begin
                stream_drop_sticky <= 1'b1;
            end
            if (stream_frame_wrap_event) begin
                stream_frame_wrap_sticky <= 1'b1;
            end
            if (stream_seam_active_event) begin
                stream_seam_active_sticky <= 1'b1;
            end
            if (stream_vblank_repeat_event) begin
                stream_vblank_repeat_sticky <= 1'b1;
            end
            if (stream_vblank_drop_event) begin
                stream_vblank_drop_sticky <= 1'b1;
            end
            if (stream_frame_resync_event) begin
                stream_frame_resync_sticky <= 1'b1;
            end
        end
    end

    wire dbg_line_seen_sys;
    wire dbg_line_ge_width_sys;
    wire dbg_line_ge_width_plus_1_sys;
    wire dbg_line_ge_width_plus_extra_sys;

    sync_2ff u_sync_dbg_line_seen_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (stream_dbg_line_seen),
        .q_sync  (dbg_line_seen_sys)
    );

    sync_2ff u_sync_dbg_line_ge_width_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (stream_dbg_line_ge_width),
        .q_sync  (dbg_line_ge_width_sys)
    );

    sync_2ff u_sync_dbg_line_ge_width_plus_1_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (stream_dbg_line_ge_width_plus_1),
        .q_sync  (dbg_line_ge_width_plus_1_sys)
    );

    sync_2ff u_sync_dbg_line_ge_width_plus_extra_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (stream_dbg_line_ge_width_plus_extra),
        .q_sync  (dbg_line_ge_width_plus_extra_sys)
    );

    wire stream_diag_activity = dbg_line_seen_sys || cam_frame_seen;
    wire stream_diag_primed = stream_ready_sys || (stream_lines_available_sys >= 3'd2);
    wire stream_diag_queue_low = stream_lines_available_sys <= 3'd1;
    wire stream_diag_queue_high = stream_lines_available_sys >= 3'd3;
    wire cam_near_target = cam_frame_seen && !cam_too_fast && !cam_too_slow;

    wire [3:0] stream_diag_page_queue = {
        stream_diag_queue_high,
        stream_diag_queue_low,
        stream_diag_primed,
        stream_diag_activity
    };
    wire [3:0] stream_diag_page_sticky = {
        stream_repeat_sticky,
        stream_drop_sticky,
        stream_underflow_sticky,
        stream_overflow_sticky
    };
    wire [3:0] stream_diag_page_rate = {
        cam_too_slow,
        cam_too_fast,
        cam_near_target,
        cam_frame_seen
    };
    wire [3:0] stream_diag_page_seam = {
        stream_frame_resync_sticky,
        stream_seam_active_sticky,
        stream_vblank_drop_sticky,
        stream_vblank_repeat_sticky
    };

    wire [3:0] stream_diag_led =
        (sw_sync[4:3] == 2'b00) ? stream_diag_page_queue :
        (sw_sync[4:3] == 2'b01) ? stream_diag_page_sticky :
        (sw_sync[4:3] == 2'b10) ? stream_diag_page_rate :
                                  stream_diag_page_seam;

    assign led[0] = camera_diag_en ? stream_diag_led[0] : heartbeat[25];
    assign led[1] = camera_diag_en ? stream_diag_led[1] : init_done;
    assign led[2] = camera_diag_en ? stream_diag_led[2] : (stream_overflow_sys || stream_frame_drop_sys);
    assign led[3] = camera_diag_en ? stream_diag_led[3] : stream_underflow;

endmodule
