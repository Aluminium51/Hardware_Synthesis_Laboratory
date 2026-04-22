`timescale 1ns/1ps

// ov7670_capture_rgb565
// Purpose: capture OV7670 RGB565 byte stream and produce RGB444 framebuffer writes.
// Clock domain: camera pixel clock, pclk.
// Ports: camera sync/data inputs and linear framebuffer write-side outputs.
// Assumptions: RGB565 bytes arrive MSB first; VSYNC is an active-high frame boundary.
module ov7670_capture_rgb565 #(
    parameter integer FRAME_PIXELS = 76800,
    parameter integer ADDR_WIDTH   = 17
) (
    input  wire                  pclk,
    input  wire                  rst,
    input  wire                  vsync,
    input  wire                  href,
    input  wire [7:0]            cam_d,
    output reg                   wr_en,
    output reg  [ADDR_WIDTH-1:0] wr_addr,
    output reg  [11:0]           wr_data,
    output reg                   frame_done,
    output reg                   frame_active
);

    localparam [ADDR_WIDTH-1:0] FRAME_LAST_ADDR = FRAME_PIXELS - 1;

    reg       vsync_d;
    reg       byte_phase;
    reg [7:0] first_byte;
    reg       frame_has_pixel;
    reg       frame_full;
    reg [ADDR_WIDTH-1:0] wr_ptr;

    wire vsync_rise = vsync && !vsync_d;

    wire [11:0] rgb444_pixel = {
        first_byte[7:4],
        first_byte[2:0],
        cam_d[7],
        cam_d[4:1]
    };

    always @(posedge pclk) begin
        if (rst) begin
            vsync_d         <= 1'b0;
            byte_phase      <= 1'b0;
            first_byte      <= 8'h00;
            frame_has_pixel <= 1'b0;
            frame_full      <= 1'b0;
            wr_ptr          <= {ADDR_WIDTH{1'b0}};
            wr_en           <= 1'b0;
            wr_addr         <= {ADDR_WIDTH{1'b0}};
            wr_data         <= 12'h000;
            frame_done      <= 1'b0;
            frame_active    <= 1'b0;
        end else begin
            vsync_d    <= vsync;
            wr_en      <= 1'b0;
            frame_done <= 1'b0;

            if (vsync) begin
                byte_phase <= 1'b0;
                first_byte <= 8'h00;

                if (vsync_rise) begin
                    wr_addr         <= {ADDR_WIDTH{1'b0}};
                    wr_ptr          <= {ADDR_WIDTH{1'b0}};
                    frame_done      <= frame_has_pixel;
                    frame_active    <= 1'b0;
                    frame_has_pixel <= 1'b0;
                    frame_full      <= 1'b0;
                end
            end else if (!href) begin
                byte_phase <= 1'b0;
                first_byte <= 8'h00;
            end else begin
                frame_active <= 1'b1;

                if (!byte_phase) begin
                    first_byte <= cam_d;
                    byte_phase <= 1'b1;
                end else begin
                    byte_phase <= 1'b0;

                    if (!frame_full) begin
                        wr_en           <= 1'b1;
                        wr_addr         <= wr_ptr;
                        wr_data         <= rgb444_pixel;
                        frame_has_pixel <= 1'b1;

                        if (wr_ptr == FRAME_LAST_ADDR) begin
                            frame_full <= 1'b1;
                        end else begin
                            wr_ptr <= wr_ptr + 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
