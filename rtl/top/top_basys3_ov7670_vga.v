`timescale 1ns/1ps

// top_basys3_ov7670_vga
// Purpose: OV7670 camera-to-framebuffer-to-VGA integration with readout filters.
// Clock domains: clk_100 for VGA/control, cam_pclk for camera capture.
// Outputs: VGA sync/RGB, OV7670 control pins, SCCB pins, and debug LEDs.
// Inputs: slide switches select VGA test-pattern/filter/profile mode; buttons adjust threshold.
// Assumptions: OV7670 RESET is active-low and PWDN is active-high on the selected module.
module top_basys3_ov7670_vga (
    input  wire        clk_100,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        btnD,
    input  wire [14:0] sw,
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
    output wire [3:0]  led,
    output wire        led11,
    output wire        led12,
    output wire        led13,
    output wire        led14
);

    wire rst_sys;

    reset_sync u_reset_sync_sys (
        .clk       (clk_100),
        .rst_async (btnC),
        .rst_sync  (rst_sys)
    );

    wire rst_vga = rst_sys;

    wire [14:0] sw_sync;

    genvar sw_i;
    generate
        for (sw_i = 0; sw_i < 15; sw_i = sw_i + 1) begin : gen_sw_sync
            sync_2ff u_sync_sw (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (sw[sw_i]),
                .q_sync  (sw_sync[sw_i])
            );
        end
    endgenerate

    wire       face_detect_en = sw_sync[14];
    wire [1:0] face_stride_sel = sw_sync[12:11];
    wire       debug_pattern_en = sw_sync[5];
    wire       camera_diag_en = sw_sync[2];
    wire [1:0] filter_mode = sw_sync[1:0];
    reg  [3:0] camera_profile = 4'b0000;

    // Camera profile switches are sampled only during btnC reset.
    // sw[4:3] selects the base profile. sw[6] selects the OV7670 internal
    // averaged-QVGA experiment when sw[7]=0. sw[7] selects full-VGA sensor
    // output with FPGA-side 2x2 averaging; sw[4:3] then selects horizontal
    // window A/B variants.
    always @(posedge clk_100) begin
        if (rst_sys) begin
            camera_profile <= {sw[7], sw[6], sw[4:3]};
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
    reg [1:0] xclk_div = 2'd0;

    always @(posedge clk_100) begin
        if (rst_sys) begin
            pixel_div <= 2'd0;
            xclk_div  <= 2'd0;
        end else begin
            pixel_div <= pixel_div + 1'b1;
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

    wire pixel_ce = (pixel_div == 2'd3);
    assign cam_xclk = xclk_div[1];

    wire       hsync_timing;
    wire       vsync_timing;
    wire       active_video;
    wire [9:0] x;
    wire [9:0] y;

    vga_timing_640x480 u_vga_timing (
        .clk_100      (clk_100),
        .pixel_ce     (pixel_ce),
        .rst_vga      (rst_vga),
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

    // Optional face-detect preprocessing stream in camera pixel domain.
    // Approximate Y ~= (R + 2*G + B) / 4 using shifts only.
    wire [7:0] cap_r8 = {capture_wr_data[15:11], capture_wr_data[15:13]};
    wire [7:0] cap_g8 = {capture_wr_data[10:5],  capture_wr_data[10:9]};
    wire [7:0] cap_b8 = {capture_wr_data[4:0],   capture_wr_data[4:2]};
    wire [9:0] cap_gray_acc = {2'b00, cap_r8} + {1'b0, cap_g8, 1'b0} + {2'b00, cap_b8};
    wire [7:0] capture_gray = cap_gray_acc[9:2];

    reg [8:0] fd_col_cam = 9'd0;
    reg [7:0] fd_row_cam = 8'd0;
    reg       capture_wr_en_d = 1'b0;

    wire fd_frame_start = capture_wr_en && !capture_wr_en_d && (capture_wr_addr == 17'd0);
    wire fd_line_start  = capture_wr_en && (fd_col_cam == 9'd0);

    always @(posedge cam_pclk) begin
        if (capture_rst) begin
            capture_wr_en_d <= 1'b0;
            fd_col_cam <= 9'd0;
            fd_row_cam <= 8'd0;
        end else begin
            capture_wr_en_d <= capture_wr_en;

            if (capture_wr_en) begin
                if (fd_col_cam == 9'd319) begin
                    fd_col_cam <= 9'd0;
                    if (fd_row_cam == 8'd239)
                        fd_row_cam <= 8'd0;
                    else
                        fd_row_cam <= fd_row_cam + 8'd1;
                end else begin
                    fd_col_cam <= fd_col_cam + 9'd1;
                end
            end

            if (fd_frame_start) begin
                fd_col_cam <= 9'd0;
                fd_row_cam <= 8'd0;
            end
        end
    end

    wire        fd_window_valid;
    wire [9:0]  fd_window_x;
    wire [8:0]  fd_window_y;
    wire [24*24*8-1:0] fd_window_data;

    wire        fd_busy;
    wire        fd_done;
    wire        fd_face_found;
    reg         fd_start;
    reg  [9:0]  fd_win_x_latched;
    reg  [8:0]  fd_win_y_latched;
    reg         fd_face_found_hold;

    wire [31:0] fd_rom_addr;
    wire        fd_rom_ren;
    wire [31:0] fd_rom_data;
    wire [31:0] fd_ii_addr;
    wire        fd_ii_ren;
    wire [17:0] fd_ii_data;
    wire        fd_ii_valid;
    wire        face_detect_en_cam;
    wire [17:0] fd_ii_data_int;
    wire        fd_ii_valid_int;

    sync_2ff u_sync_face_detect_en_cam (
        .clk     (cam_pclk),
        .rst     (capture_rst),
        .d_async (face_detect_en),
        .q_sync  (face_detect_en_cam)
    );

    localparam integer II_WIDTH = 321;
    localparam integer II_HEIGHT = 241;

    wire [8:0]  ii_wr_row = {1'b0, fd_row_cam} + 9'd1;
    wire [9:0]  ii_wr_col = {1'b0, fd_col_cam} + 10'd1;
    wire [16:0] ii_wr_addr = (ii_wr_row * II_WIDTH) + ii_wr_col;

    haarcascade_rom #(
        .ROM_WORDS (24471),
        .MEM_FILE  ("haarcascade_frontalface_q8.mem")
    ) u_haarcascade_rom (
        .clk  (cam_pclk),
        .ren  (fd_rom_ren),
        .addr (fd_rom_addr),
        .data (fd_rom_data)
    );

    integral_image_ram #(
        .IMAGE_WIDTH  (II_WIDTH),
        .IMAGE_HEIGHT (II_HEIGHT),
        .DATA_WIDTH   (18),
        .ADDR_WIDTH   (17)
    ) u_integral_image_ram (
        .clk        (cam_pclk),
        .rst        (capture_rst || !face_detect_en_cam),
        .wr_en      (capture_wr_en && face_detect_en_cam),
        .wr_addr    (ii_wr_addr),
        .wr_px      (capture_gray),
        .line_start (fd_line_start),
        .frame_start(fd_frame_start),
        .rd_en      (fd_ii_ren),
        .rd_addr    (fd_ii_addr),
        .rd_data    (fd_ii_data_int),
        .rd_valid   (fd_ii_valid_int)
    );

    sliding_window_24 #(
        .IMAGE_WIDTH (320),
        .DATA_WIDTH  (8),
        .WINDOW      (24)
    ) u_sliding_window_24 (
        .clk         (cam_pclk),
        .rst         (capture_rst || !face_detect_en_cam),
        .px_valid    (capture_wr_en && face_detect_en_cam),
        .line_start  (fd_line_start),
        .frame_start (fd_frame_start),
        .px_in       (capture_gray),
        .window_valid(fd_window_valid),
        .window_x    (fd_window_x),
        .window_y    (fd_window_y),
        .window_data (fd_window_data)
    );

    wire fd_stride_ok = (face_stride_sel == 2'b00) ? 1'b1 :
                        (face_stride_sel == 2'b01) ? ((fd_window_x[1:0] == 2'b00) && (fd_window_y[1:0] == 2'b00)) :
                        (face_stride_sel == 2'b10) ? ((fd_window_x[2:0] == 3'b000) && (fd_window_y[2:0] == 3'b000)) :
                                                     ((fd_window_x[3:0] == 4'b0000) && (fd_window_y[3:0] == 4'b0000));

    wire fd_start_next = fd_window_valid && !fd_busy && fd_stride_ok;

    always @(posedge cam_pclk) begin
        if (capture_rst || !face_detect_en_cam) begin
            fd_start <= 1'b0;
            fd_win_x_latched <= 10'd0;
            fd_win_y_latched <= 9'd0;
            fd_face_found_hold <= 1'b0;
        end else begin
            // Simple scheduler: evaluate next window when FSM is idle.
            fd_start <= fd_start_next;

            if (fd_start_next) begin
                fd_win_x_latched <= fd_window_x;
                fd_win_y_latched <= fd_window_y;
            end

            if (fd_frame_start) begin
                fd_face_found_hold <= 1'b0;
            end else if (fd_done && fd_face_found) begin
                fd_face_found_hold <= 1'b1;
            end
        end
    end

    face_detect #(
        .IMG_WIDTH   (320),
        .SCALE_SHIFT (8)
    ) u_face_detect (
        .clk        (cam_pclk),
        .rst        (capture_rst || !face_detect_en_cam),
        .start      (fd_start),
        .win_x      (fd_win_x_latched),
        .win_y      (fd_win_y_latched),
        .rom_addr   (fd_rom_addr),
        .rom_ren    (fd_rom_ren),
        .rom_data   (fd_rom_data),
        .ii_addr    (fd_ii_addr),
        .ii_ren     (fd_ii_ren),
        .ii_data    (fd_ii_data_int),
        .ii_valid   (fd_ii_valid_int),
        .busy       (fd_busy),
        .done       (fd_done),
        .face_found (fd_face_found)
    );

    assign fd_ii_data  = fd_ii_data_int;
    assign fd_ii_valid = fd_ii_valid_int;

    wire [16:0] fb_rd_addr;
    wire [15:0] fb_rd_data;

    framebuffer_bram u_framebuffer (
        .wr_clk  (cam_pclk),
        .wr_en   (capture_wr_en),
        .wr_addr (capture_wr_addr),
        .wr_data (capture_wr_data),
        .rd_clk  (clk_100),
        .rd_addr (fb_rd_addr),
        .rd_data (fb_rd_data)
    );

    wire        hsync_reader;
    wire        vsync_reader;
    wire        active_video_reader;
    wire [15:0] reader_rgb565;

    vga_reader_320x240 u_vga_reader (
        .clk_100          (clk_100),
        .pixel_ce         (pixel_ce),
        .rst_vga          (rst_vga),
        .vga_x            (x),
        .vga_y            (y),
        .hsync_in         (hsync_timing),
        .vsync_in         (vsync_timing),
        .active_video_in  (active_video),
        .rd_data          (fb_rd_data),
        .rd_addr          (fb_rd_addr),
        .hsync_out        (hsync_reader),
        .vsync_out        (vsync_reader),
        .active_video_out (active_video_reader),
        .rgb565_out       (reader_rgb565)
    );

    wire [15:0] filtered_rgb565;

    video_filter_basic u_video_filter_basic (
        .rgb565_in  (reader_rgb565),
        .mode       (filter_mode),
        .threshold  (filter_threshold),
        .rgb565_out (filtered_rgb565)
    );

    // Synchronize face detection signals from camera clock domain to VGA clock domain.
    wire        fd_face_found_sys;
    wire [9:0]  fd_window_x_sys;
    wire [8:0]  fd_window_y_sys;

    sync_2ff u_sync_fd_face_found_sys (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_face_found_hold),
        .q_sync  (fd_face_found_sys)
    );

    reg face_found_latched_sys = 1'b0;

    always @(posedge clk_100) begin
        if (rst_sys || !face_detect_en) begin
            face_found_latched_sys <= 1'b0;
        end else if (fd_face_found_sys) begin
            face_found_latched_sys <= 1'b1;
        end
    end

    sync_2ff u_sync_fd_window_x_sys_0 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[0]),
        .q_sync  (fd_window_x_sys[0])
    );

    sync_2ff u_sync_fd_window_x_sys_1 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[1]),
        .q_sync  (fd_window_x_sys[1])
    );

    sync_2ff u_sync_fd_window_x_sys_2 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[2]),
        .q_sync  (fd_window_x_sys[2])
    );

    sync_2ff u_sync_fd_window_x_sys_3 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[3]),
        .q_sync  (fd_window_x_sys[3])
    );

    sync_2ff u_sync_fd_window_x_sys_4 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[4]),
        .q_sync  (fd_window_x_sys[4])
    );

    sync_2ff u_sync_fd_window_x_sys_5 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[5]),
        .q_sync  (fd_window_x_sys[5])
    );

    sync_2ff u_sync_fd_window_x_sys_6 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[6]),
        .q_sync  (fd_window_x_sys[6])
    );

    sync_2ff u_sync_fd_window_x_sys_7 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[7]),
        .q_sync  (fd_window_x_sys[7])
    );

    sync_2ff u_sync_fd_window_x_sys_8 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[8]),
        .q_sync  (fd_window_x_sys[8])
    );

    sync_2ff u_sync_fd_window_x_sys_9 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_x_latched[9]),
        .q_sync  (fd_window_x_sys[9])
    );

    sync_2ff u_sync_fd_window_y_sys_0 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[0]),
        .q_sync  (fd_window_y_sys[0])
    );

    sync_2ff u_sync_fd_window_y_sys_1 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[1]),
        .q_sync  (fd_window_y_sys[1])
    );

    sync_2ff u_sync_fd_window_y_sys_2 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[2]),
        .q_sync  (fd_window_y_sys[2])
    );

    sync_2ff u_sync_fd_window_y_sys_3 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[3]),
        .q_sync  (fd_window_y_sys[3])
    );

    sync_2ff u_sync_fd_window_y_sys_4 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[4]),
        .q_sync  (fd_window_y_sys[4])
    );

    sync_2ff u_sync_fd_window_y_sys_5 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[5]),
        .q_sync  (fd_window_y_sys[5])
    );

    sync_2ff u_sync_fd_window_y_sys_6 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[6]),
        .q_sync  (fd_window_y_sys[6])
    );

    sync_2ff u_sync_fd_window_y_sys_7 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[7]),
        .q_sync  (fd_window_y_sys[7])
    );

    sync_2ff u_sync_fd_window_y_sys_8 (
        .clk     (clk_100),
        .rst     (rst_sys),
        .d_async (fd_win_y_latched[8]),
        .q_sync  (fd_window_y_sys[8])
    );

    // Overlay face detection box on filtered video.
    wire [15:0] overlay_rgb565;

    vga_overlay_face u_vga_overlay_face (
        .clk           (clk_100),
        .rst           (rst_vga),
        .vga_x         (x),
        .vga_y         (y),
        .active_video  (active_video_reader),
        .face_found    (fd_face_found_sys),
        .face_enable   (face_detect_en),
        .window_x      (fd_window_x_sys),
        .window_y      (fd_window_y_sys),
        .rgb565_in     (filtered_rgb565),
        .rgb565_out    (overlay_rgb565)
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

    wire [11:0] filtered_rgb444 = rgb565_to_rgb444(overlay_rgb565);
    wire [11:0] camera_rgb444 = (init_done && active_video_reader) ?
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
                                     (frame_activity_hold != 24'd0);
    assign led11 = face_stride_sel[0];
    assign led12 = face_stride_sel[1];
    assign led13 = face_found_latched_sys;
    assign led14 = face_detect_en;

endmodule
