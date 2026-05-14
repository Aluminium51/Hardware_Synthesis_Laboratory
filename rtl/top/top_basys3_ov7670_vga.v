`timescale 1ns/1ps

// top_basys3_ov7670_vga
// Purpose: OV7670 camera-to-framebuffer-to-VGA integration with readout filters.
// Clock domains: clk_100 for control/SCCB, selected VGA/read clock, cam_pclk for camera capture.
// Outputs: VGA sync/RGB, OV7670 control pins, SCCB pins, and debug LEDs.
// Inputs: slide switches select VGA test-pattern/filter/profile mode; buttons adjust threshold.
// Assumptions: OV7670 RESET is active-low and PWDN is active-high on the selected module.
module top_basys3_ov7670_vga (
    input  wire        clk_100,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        btnD,
    input  wire [9:0]  sw,
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

    wire [8:0] sw_sync;

    genvar sw_i;
    generate
        for (sw_i = 0; sw_i < 9; sw_i = sw_i + 1) begin : gen_sw_sync
            sync_2ff u_sync_sw (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (sw[sw_i]),
                .q_sync  (sw_sync[sw_i])
            );
        end
    endgenerate

    wire       debug_pattern_en_sys = sw_sync[5];
    wire       camera_diag_en = sw_sync[2];
    reg  [3:0] camera_profile = 4'b0000;
    reg        mode_4x_latched = 1'b0;

    // Camera profile switches are sampled only during btnC reset.
    // sw[4:3] selects the base profile. sw[6] selects the OV7670 internal
    // averaged-QVGA experiment when sw[7]=0. sw[7] selects full-VGA sensor
    // output with FPGA-side 2x2 averaging; sw[4:3] then selects horizontal
    // window A/B variants.
    always @(posedge clk_100) begin
        if (rst_sys) begin
            camera_profile <= {sw[7], sw[6], sw[4:3]};
            mode_4x_latched <= sw[9];
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

    reg [1:0] xclk_div = 2'd0;

    always @(posedge clk_100) begin
        if (rst_sys) begin
            xclk_div  <= 2'd0;
        end else begin
            xclk_div  <= xclk_div + 1'b1;
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

    assign cam_xclk = xclk_div[1];

    wire clk_108;
    wire clk108_locked;
    wire selected_vga_clk;

    vga_clock_108 u_vga_clock_108 (
        .clk_100 (clk_100),
        .rst     (rst_sys),
        .clk_108 (clk_108),
        .locked  (clk108_locked)
    );

    vga_clock_select u_vga_clock_select (
        .clk_100    (clk_100),
        .clk_108    (clk_108),
        .select_108 (mode_4x_latched),
        .clk_out    (selected_vga_clk)
    );

    wire vga_clock_ready = mode_4x_latched ? clk108_locked : 1'b1;
    wire vga_rst_async = rst_sys | ~vga_clock_ready;
    wire rst_vga;

    reset_sync u_reset_sync_vga (
        .clk       (selected_vga_clk),
        .rst_async (vga_rst_async),
        .rst_sync  (rst_vga)
    );

    wire mode_4x_vga;

    sync_2ff u_sync_mode_4x_vga (
        .clk     (selected_vga_clk),
        .rst     (rst_vga),
        .d_async (mode_4x_latched),
        .q_sync  (mode_4x_vga)
    );

    wire enable_2x = ~mode_4x_vga;
    wire enable_4x = mode_4x_vga;

    wire debug_pattern_en;
    wire enable_bilinear;
    wire [1:0] filter_mode;
    wire [3:0] filter_threshold_vga;
    wire init_done;
    wire init_error;

    sync_2ff u_sync_debug_pattern_vga (
        .clk     (selected_vga_clk),
        .rst     (rst_vga),
        .d_async (debug_pattern_en_sys),
        .q_sync  (debug_pattern_en)
    );

    sync_2ff u_sync_bilinear_vga (
        .clk     (selected_vga_clk),
        .rst     (rst_vga),
        .d_async (sw[8]),
        .q_sync  (enable_bilinear)
    );

    wire init_done_vga;

    sync_2ff u_sync_init_done_vga (
        .clk     (selected_vga_clk),
        .rst     (rst_vga),
        .d_async (init_done),
        .q_sync  (init_done_vga)
    );

    genvar vga_ctl_i;
    generate
        for (vga_ctl_i = 0; vga_ctl_i < 2; vga_ctl_i = vga_ctl_i + 1) begin : gen_filter_mode_sync
            sync_2ff u_sync_filter_mode (
                .clk     (selected_vga_clk),
                .rst     (rst_vga),
                .d_async (sw[vga_ctl_i]),
                .q_sync  (filter_mode[vga_ctl_i])
            );
        end

        for (vga_ctl_i = 0; vga_ctl_i < 4; vga_ctl_i = vga_ctl_i + 1) begin : gen_threshold_sync
            sync_2ff u_sync_threshold (
                .clk     (selected_vga_clk),
                .rst     (rst_vga),
                .d_async (filter_threshold[vga_ctl_i]),
                .q_sync  (filter_threshold_vga[vga_ctl_i])
            );
        end
    endgenerate

    reg [1:0] pixel_div_vga = 2'd0;

    always @(posedge selected_vga_clk) begin
        if (rst_vga) begin
            pixel_div_vga <= 2'd0;
        end else begin
            pixel_div_vga <= pixel_div_vga + 1'b1;
        end
    end

    wire pixel_ce_2x = (pixel_div_vga == 2'd3);

    wire        hsync_timing_2x;
    wire        vsync_timing_2x;
    wire        active_video_2x;
    wire [9:0]  x_2x;
    wire [9:0]  y_2x;

    vga_timing_640x480 u_vga_timing_640x480 (
        .clk_100      (selected_vga_clk),
        .pixel_ce     (pixel_ce_2x),
        .rst_vga      (rst_vga),
        .hsync        (hsync_timing_2x),
        .vsync        (vsync_timing_2x),
        .active_video (active_video_2x),
        .x            (x_2x),
        .y            (y_2x)
    );

    wire        hsync_timing_4x;
    wire        vsync_timing_4x;
    wire        active_video_4x;
    wire [10:0] x_4x;
    wire [9:0]  y_4x;
    wire [10:0] h_count_4x;
    wire [9:0]  v_count_4x;

    vga_timing_1280x960 u_vga_timing_1280x960 (
        .clk          (selected_vga_clk),
        .rst          (rst_vga),
        .vga_x        (x_4x),
        .vga_y        (y_4x),
        .active_video (active_video_4x),
        .hsync        (hsync_timing_4x),
        .vsync        (vsync_timing_4x),
        .h_count      (h_count_4x),
        .v_count      (v_count_4x)
    );

    wire        hsync_timing = mode_4x_vga ? hsync_timing_4x : hsync_timing_2x;
    wire        vsync_timing = mode_4x_vga ? vsync_timing_4x : vsync_timing_2x;
    wire        active_video = mode_4x_vga ? active_video_4x : active_video_2x;
    wire [10:0] x = mode_4x_vga ? x_4x : {1'b0, x_2x};
    wire [9:0]  y = mode_4x_vga ? y_4x : y_2x;

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
    ov7670_init u_ov7670_init (
        .clk            (clk_100),
        .rst            (rst_sys),
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
        .rst       (rst_sys),
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

    // SCCB uses an open-drain data line, so only drive low or release.
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

    wire        capture_wr_en;
    wire [16:0] capture_wr_addr;
    wire [15:0] capture_wr_data;
    wire        capture_frame_done;
    wire        capture_dbg_line_seen;
    wire        capture_dbg_line_ge_width;
    wire        capture_dbg_line_ge_width_plus_1;
    wire        capture_dbg_line_ge_width_plus_extra;
    wire        full_avg_capture_en = camera_profile[3];

    wire        stable_capture_wr_en;
    wire [16:0] stable_capture_wr_addr;
    wire [15:0] stable_capture_wr_data;
    wire        stable_capture_frame_done;
    wire        stable_capture_dbg_line_seen;
    wire        stable_capture_dbg_line_ge_width;
    wire        stable_capture_dbg_line_ge_width_plus_1;
    wire        stable_capture_dbg_line_ge_width_plus_extra;

    ov7670_capture_rgb565 #(
        .SKIP_LEFT_PIXELS (0),
        .SKIP_TOP_LINES   (0)
    ) u_ov7670_capture (
        .pclk         (cam_pclk),
        .rst          (capture_rst),
        .vsync        (cam_vsync),
        .href         (cam_href),
        .cam_d        (cam_d),
        .wr_en        (stable_capture_wr_en),
        .wr_addr      (stable_capture_wr_addr),
        .wr_data      (stable_capture_wr_data),
        .frame_done   (stable_capture_frame_done),
        .frame_active (),
        .dbg_line_seen (stable_capture_dbg_line_seen),
        .dbg_line_ge_width (stable_capture_dbg_line_ge_width),
        .dbg_line_ge_width_plus_1 (stable_capture_dbg_line_ge_width_plus_1),
        .dbg_line_ge_width_plus_extra (stable_capture_dbg_line_ge_width_plus_extra)
    );

    wire        avg_capture_wr_en;
    wire [16:0] avg_capture_wr_addr;
    wire [15:0] avg_capture_wr_data;
    wire        avg_capture_frame_done;
    wire        avg_capture_dbg_line_seen;
    wire        avg_capture_dbg_line_ge_width;
    wire        avg_capture_dbg_line_ge_width_plus_1;
    wire        avg_capture_dbg_line_ge_width_plus_extra;

    ov7670_capture_rgb565_2x2_avg u_ov7670_capture_2x2_avg (
        .pclk         (cam_pclk),
        .rst          (capture_rst),
        .vsync        (cam_vsync),
        .href         (cam_href),
        .cam_d        (cam_d),
        .wr_en        (avg_capture_wr_en),
        .wr_addr      (avg_capture_wr_addr),
        .wr_data      (avg_capture_wr_data),
        .frame_done   (avg_capture_frame_done),
        .frame_active (),
        .dbg_line_seen (avg_capture_dbg_line_seen),
        .dbg_line_ge_width (avg_capture_dbg_line_ge_width),
        .dbg_line_ge_width_plus_1 (avg_capture_dbg_line_ge_width_plus_1),
        .dbg_line_ge_width_plus_extra (avg_capture_dbg_line_ge_width_plus_extra)
    );

    assign capture_wr_en = full_avg_capture_en ? avg_capture_wr_en : stable_capture_wr_en;
    assign capture_wr_addr = full_avg_capture_en ? avg_capture_wr_addr : stable_capture_wr_addr;
    assign capture_wr_data = full_avg_capture_en ? avg_capture_wr_data : stable_capture_wr_data;
    assign capture_frame_done = full_avg_capture_en ? avg_capture_frame_done : stable_capture_frame_done;
    assign capture_dbg_line_seen = full_avg_capture_en ? avg_capture_dbg_line_seen : stable_capture_dbg_line_seen;
    assign capture_dbg_line_ge_width = full_avg_capture_en ? avg_capture_dbg_line_ge_width : stable_capture_dbg_line_ge_width;
    assign capture_dbg_line_ge_width_plus_1 = full_avg_capture_en ? avg_capture_dbg_line_ge_width_plus_1 : stable_capture_dbg_line_ge_width_plus_1;
    assign capture_dbg_line_ge_width_plus_extra = full_avg_capture_en ? avg_capture_dbg_line_ge_width_plus_extra : stable_capture_dbg_line_ge_width_plus_extra;

    wire [16:0] fb_rd_addr;
    wire [15:0] fb_rd_data;

    framebuffer_bram u_framebuffer (
        .wr_clk  (cam_pclk),
        .wr_en   (capture_wr_en),
        .wr_addr (capture_wr_addr),
        .wr_data (capture_wr_data),
        .rd_clk  (selected_vga_clk),
        .rd_addr (fb_rd_addr),
        .rd_data (fb_rd_data)
    );

    wire [16:0] fb_rd_addr_2x;
    wire [16:0] fb_rd_addr_4x;

    assign fb_rd_addr = mode_4x_vga ? fb_rd_addr_4x : fb_rd_addr_2x;

    wire        hsync_reader_2x;
    wire        vsync_reader_2x;
    wire        active_video_reader_2x;
    wire [15:0] reader_rgb565_2x;

    vga_reader_bilinear u_vga_reader (
        .clk_100          (selected_vga_clk),
        .pixel_ce         (pixel_ce_2x),
        .rst_vga          (rst_vga),
        .vga_x            (x_2x),
        .vga_y            (y_2x),
        .hsync_in         (hsync_timing_2x),
        .vsync_in         (vsync_timing_2x),
        .active_video_in  (active_video_2x),
        .rd_data          (fb_rd_data),
        .enable_bilinear  (enable_bilinear),
        .rd_addr          (fb_rd_addr_2x),
        .hsync_out        (hsync_reader_2x),
        .vsync_out        (vsync_reader_2x),
        .active_video_out (active_video_reader_2x),
        .rgb565_out       (reader_rgb565_2x)
    );

    wire        hsync_reader_4x;
    wire        vsync_reader_4x;
    wire        active_video_reader_4x;
    wire [15:0] reader_rgb565_4x;

    vga_reader_bilinear_4x u_vga_reader_4x (
        .clk              (selected_vga_clk),
        .rst              (rst_vga),
        .enable           (enable_4x),
        .enable_bilinear  (enable_bilinear),
        .vga_x            (x_4x),
        .vga_y            (y_4x),
        .h_count          (h_count_4x),
        .v_count          (v_count_4x),
        .active_video_in  (active_video_4x),
        .hsync_in         (hsync_timing_4x),
        .vsync_in         (vsync_timing_4x),
        .fb_rd_addr       (fb_rd_addr_4x),
        .fb_rd_data       (fb_rd_data),
        .pixel_out        (reader_rgb565_4x),
        .active_video_out (active_video_reader_4x),
        .hsync_out        (hsync_reader_4x),
        .vsync_out        (vsync_reader_4x)
    );

    wire        hsync_reader = mode_4x_vga ? hsync_reader_4x : hsync_reader_2x;
    wire        vsync_reader = mode_4x_vga ? vsync_reader_4x : vsync_reader_2x;
    wire        active_video_reader = mode_4x_vga ? active_video_reader_4x : active_video_reader_2x;
    wire [15:0] reader_rgb565 = mode_4x_vga ? reader_rgb565_4x : reader_rgb565_2x;

    wire [15:0] filtered_rgb565;

    video_filter_basic u_video_filter_basic (
        .rgb565_in  (reader_rgb565),
        .mode       (filter_mode),
        .threshold  (filter_threshold_vga),
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
    wire [11:0] camera_rgb444 = (init_done_vga && active_video_reader) ?
                                filtered_rgb444 : 12'h000;
    wire [11:0] display_rgb444 = debug_pattern_en ? pattern_rgb444 : camera_rgb444;
    wire        display_hsync = debug_pattern_en ? hsync_timing : hsync_reader;
    wire        display_vsync = debug_pattern_en ? vsync_timing : vsync_reader;

    reg [25:0] heartbeat = 26'd0;

    always @(posedge clk_100) begin
        if (rst_sys) begin
            heartbeat <= 26'd0;
        end else begin
            heartbeat <= heartbeat + 1'b1;
        end
    end

    reg frame_done_toggle = 1'b0;

    always @(posedge cam_pclk) begin
        if (capture_rst) begin
            frame_done_toggle <= 1'b0;
        end else if (capture_frame_done) begin
            frame_done_toggle <= ~frame_done_toggle;
        end
    end

    wire frame_done_toggle_sys;

    sync_2ff u_sync_frame_done_toggle_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (frame_done_toggle),
        .q_sync  (frame_done_toggle_sys)
    );

    reg        frame_done_toggle_sys_d = 1'b0;
    reg [23:0] frame_activity_hold = 24'd0;

    wire frame_done_event_sys = frame_done_toggle_sys ^ frame_done_toggle_sys_d;

    always @(posedge clk_100) begin
        if (rst_sys) begin
            frame_done_toggle_sys_d <= 1'b0;
            frame_activity_hold     <= 24'd0;
        end else begin
            frame_done_toggle_sys_d <= frame_done_toggle_sys;

            if (frame_done_event_sys) begin
                frame_activity_hold <= 24'hffffff;
            end else if (frame_activity_hold != 24'd0) begin
                frame_activity_hold <= frame_activity_hold - 1'b1;
            end
        end
    end

    assign Hsync = display_hsync;
    assign Vsync = display_vsync;

    assign vgaRed   = display_rgb444[11:8];
    assign vgaGreen = display_rgb444[7:4];
    assign vgaBlue  = display_rgb444[3:0];

    wire dbg_line_seen_sys;
    wire dbg_line_ge_width_sys;
    wire dbg_line_ge_width_plus_1_sys;
    wire dbg_line_ge_width_plus_extra_sys;

    sync_2ff u_sync_dbg_line_seen_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (capture_dbg_line_seen),
        .q_sync  (dbg_line_seen_sys)
    );

    sync_2ff u_sync_dbg_line_ge_width_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (capture_dbg_line_ge_width),
        .q_sync  (dbg_line_ge_width_sys)
    );

    sync_2ff u_sync_dbg_line_ge_width_plus_1_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (capture_dbg_line_ge_width_plus_1),
        .q_sync  (dbg_line_ge_width_plus_1_sys)
    );

    sync_2ff u_sync_dbg_line_ge_width_plus_extra_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (capture_dbg_line_ge_width_plus_extra),
        .q_sync  (dbg_line_ge_width_plus_extra_sys)
    );

    assign led[0] = camera_diag_en ? dbg_line_seen_sys : heartbeat[25];
    assign led[1] = camera_diag_en ? dbg_line_ge_width_sys : init_done;
    assign led[2] = camera_diag_en ? dbg_line_ge_width_plus_1_sys : init_error;
    assign led[3] = camera_diag_en ? dbg_line_ge_width_plus_extra_sys :
                                     (mode_4x_latched ? clk108_locked :
                                                        (frame_activity_hold != 24'd0));

endmodule
