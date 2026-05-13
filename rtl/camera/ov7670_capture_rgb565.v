`timescale 1ns/1ps

// ov7670_capture_rgb565
//
// Purpose:
//   Capture an OV7670 RGB565 byte stream and emit bounded RGB565 framebuffer
//   write transactions for one 320x240 frame.
//
// Clock domain:
//   pclk, the camera pixel clock.
//
// Inputs:
//   vsync - active-high frame boundary from the camera
//   href  - active line/data qualifier
//   cam_d - 8-bit camera data bus
//
// Outputs:
//   wr_en/wr_addr/wr_data - camera-domain framebuffer write interface
//   frame_done            - one-pclk pulse at the end of a non-empty frame
//   frame_active          - asserted after byte activity begins in a frame
//   dbg_line_*            - sticky line-length diagnostics for hardware debug
//
// Assumptions:
//   RGB565 bytes arrive most-significant byte first, and VSYNC is active-high.
module ov7670_capture_rgb565 #(
    parameter integer FRAME_WIDTH  = 320,
    parameter integer FRAME_HEIGHT = 240,
    parameter integer SKIP_LEFT_PIXELS = 0,
    parameter integer SKIP_TOP_LINES   = 0,
    parameter integer DIAG_EXTRA_PIXELS = 8,
    parameter integer FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT,
    parameter integer ADDR_WIDTH   = 17
) (
    input  wire                  pclk,
    input  wire                  rst,
    input  wire                  vsync,
    input  wire                  href,
    input  wire [7:0]            cam_d,
    output reg                   wr_en,
    output reg  [ADDR_WIDTH-1:0] wr_addr,
    output reg  [15:0]           wr_data,
    output reg                   frame_done,
    output reg                   frame_active,
    output reg                   dbg_line_seen,
    output reg                   dbg_line_ge_width,
    output reg                   dbg_line_ge_width_plus_1,
    output reg                   dbg_line_ge_width_plus_extra
);

    localparam [ADDR_WIDTH-1:0] FRAME_LAST_ADDR = FRAME_PIXELS - 1;
    localparam [9:0] CAPTURE_X_START = SKIP_LEFT_PIXELS;
    localparam [9:0] CAPTURE_X_END   = SKIP_LEFT_PIXELS + FRAME_WIDTH;
    localparam [8:0] CAPTURE_Y_START = SKIP_TOP_LINES;
    localparam [8:0] CAPTURE_Y_END   = SKIP_TOP_LINES + FRAME_HEIGHT;
    localparam [9:0] DIAG_WIDTH = FRAME_WIDTH;
    localparam [9:0] DIAG_WIDTH_PLUS_1 = FRAME_WIDTH + 1;
    localparam [9:0] DIAG_WIDTH_PLUS_EXTRA = FRAME_WIDTH + DIAG_EXTRA_PIXELS;

    reg       vsync_d;
    reg       byte_phase;
    reg [7:0] first_byte;
    reg       frame_has_pixel;
    reg       frame_full;
    reg       href_d;
    reg       line_has_pixel;
    reg [9:0] x_count;
    reg [8:0] y_count;

    wire vsync_rise = vsync && !vsync_d;
    wire [15:0] rgb565_pixel = {first_byte, cam_d};
    wire        pixel_in_bounds =
        (x_count >= CAPTURE_X_START) && (x_count < CAPTURE_X_END) &&
        (y_count >= CAPTURE_Y_START) && (y_count < CAPTURE_Y_END);
    wire [9:0] dest_x = x_count - CAPTURE_X_START;
    wire [8:0] dest_y = y_count - CAPTURE_Y_START;
    wire [31:0] dest_addr_full = (dest_y * FRAME_WIDTH) + dest_x;
    wire [ADDR_WIDTH-1:0] dest_addr = dest_addr_full[ADDR_WIDTH-1:0];

    // Camera-domain capture process. It tracks frame/line boundaries, assembles
    // two input bytes into one RGB565 pixel, applies optional crop offsets, and
    // suppresses writes after the final framebuffer address until the next
    // frame boundary.
    always @(posedge pclk) begin
        if (rst) begin
            vsync_d         <= 1'b0;
            byte_phase      <= 1'b0;
            first_byte      <= 8'h00;
            frame_has_pixel <= 1'b0;
            frame_full      <= 1'b0;
            href_d          <= 1'b0;
            line_has_pixel  <= 1'b0;
            x_count         <= 10'd0;
            y_count         <= 9'd0;
            wr_en           <= 1'b0;
            wr_addr         <= {ADDR_WIDTH{1'b0}};
            wr_data         <= 16'h0000;
            frame_done      <= 1'b0;
            frame_active    <= 1'b0;
            dbg_line_seen   <= 1'b0;
            dbg_line_ge_width <= 1'b0;
            dbg_line_ge_width_plus_1 <= 1'b0;
            dbg_line_ge_width_plus_extra <= 1'b0;
        end else begin
            vsync_d    <= vsync;
            href_d     <= href;
            wr_en      <= 1'b0;
            frame_done <= 1'b0;

            if (vsync) begin
                // VSYNC marks a frame boundary and clears any partial byte pair
                // so incomplete pixels cannot leak into the next frame.
                byte_phase     <= 1'b0;
                first_byte     <= 8'h00;
                line_has_pixel <= 1'b0;
                x_count        <= 10'd0;
                y_count        <= 9'd0;

                if (vsync_rise) begin
                    wr_addr         <= {ADDR_WIDTH{1'b0}};
                    frame_done      <= frame_has_pixel;
                    frame_active    <= 1'b0;
                    frame_has_pixel <= 1'b0;
                    frame_full      <= 1'b0;
                    dbg_line_seen   <= 1'b0;
                    dbg_line_ge_width <= 1'b0;
                    dbg_line_ge_width_plus_1 <= 1'b0;
                    dbg_line_ge_width_plus_extra <= 1'b0;
                end
            end else if (!href) begin
                // HREF low closes the current line. Completed-pixel line counts
                // update the debug flags and advance the source y coordinate.
                byte_phase <= 1'b0;
                first_byte <= 8'h00;

                if (href_d && line_has_pixel) begin
                    dbg_line_seen <= 1'b1;
                    if (x_count >= DIAG_WIDTH) begin
                        dbg_line_ge_width <= 1'b1;
                    end
                    if (x_count >= DIAG_WIDTH_PLUS_1) begin
                        dbg_line_ge_width_plus_1 <= 1'b1;
                    end
                    if (x_count >= DIAG_WIDTH_PLUS_EXTRA) begin
                        dbg_line_ge_width_plus_extra <= 1'b1;
                    end

                    if (y_count < CAPTURE_Y_END) begin
                        y_count <= y_count + 1'b1;
                    end

                    x_count        <= 10'd0;
                    line_has_pixel <= 1'b0;
                end
            end else begin
                frame_active <= 1'b1;

                if (!byte_phase) begin
                    // First byte of RGB565 is held until the matching second
                    // byte arrives on the next qualified camera transfer.
                    first_byte <= cam_d;
                    byte_phase <= 1'b1;
                end else begin
                    // Second byte completes the RGB565 word. In-bounds pixels
                    // produce one write pulse at their mapped framebuffer address.
                    byte_phase     <= 1'b0;
                    line_has_pixel <= 1'b1;

                    if (x_count != 10'h3ff) begin
                        x_count <= x_count + 1'b1;
                    end

                    if (!frame_full && pixel_in_bounds) begin
                        wr_en           <= 1'b1;
                        wr_addr         <= dest_addr;
                        wr_data         <= rgb565_pixel;
                        frame_has_pixel <= 1'b1;

                        if (dest_addr == FRAME_LAST_ADDR) begin
                            frame_full <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
