`timescale 1ns/1ps

// top_basys3_ov7670_vga
// Purpose: OV7670 camera-to-framebuffer-to-VGA integration with readout filters.
// Clock domains: clk_100 for VGA/control, cam_pclk for camera capture.
// Outputs: VGA sync/RGB, OV7670 control pins, SCCB pins, and debug LEDs.
// Inputs: slide switches select VGA test-pattern/filter mode; buttons adjust threshold.
// Assumptions: OV7670 RESET is active-low and PWDN is active-high on the selected module.
module top_basys3_ov7670_vga (
    input  wire        clk_100,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        btnD,
    input  wire [5:0]  sw,
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

    wire rst_vga = rst_sys;

    wire [5:0] sw_sync;

    genvar sw_i;
    generate
        for (sw_i = 0; sw_i < 6; sw_i = sw_i + 1) begin : gen_sw_sync
            sync_2ff u_sync_sw (
                .clk     (clk_100),
                .rst     (rst_sys),
                .d_async (sw[sw_i]),
                .q_sync  (sw_sync[sw_i])
            );
        end
    endgenerate

    wire       debug_pattern_en = sw_sync[5];
    wire [1:0] filter_mode = sw_sync[1:0];

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
    wire [11:0] capture_wr_data;
    wire        capture_frame_done;

    ov7670_capture_rgb565 u_ov7670_capture (
        .pclk         (cam_pclk),
        .rst          (capture_rst),
        .vsync        (cam_vsync),
        .href         (cam_href),
        .cam_d        (cam_d),
        .wr_en        (capture_wr_en),
        .wr_addr      (capture_wr_addr),
        .wr_data      (capture_wr_data),
        .frame_done   (capture_frame_done),
        .frame_active ()
    );

    wire [16:0] fb_rd_addr;
    wire [11:0] fb_rd_data;

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
    wire [11:0] reader_rgb444;

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
        .rgb444_out       (reader_rgb444)
    );

    wire [11:0] filtered_rgb444;

    video_filter_basic u_video_filter_basic (
        .rgb444_in  (reader_rgb444),
        .mode       (filter_mode),
        .threshold  (filter_threshold),
        .rgb444_out (filtered_rgb444)
    );

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

    assign led[0] = heartbeat[25];
    assign led[1] = init_done;
    assign led[2] = init_error;
    assign led[3] = (frame_activity_hold != 24'd0);

endmodule
