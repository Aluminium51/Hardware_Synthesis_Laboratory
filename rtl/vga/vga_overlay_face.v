`timescale 1ns/1ps

// vga_overlay_face
// Purpose: Draw a bounding box overlay for detected faces on the VGA output.
// Clock domain: VGA pixel clock (clk_100).
// Inputs: RGB565 filtered video, VGA coordinates (x, y), face detection signals.
// Output: RGB565 with face bounding box overlay.
// Notes:
// - Detects face at 320x240 resolution but overlays on 640x480 display (2x scaled).
// - Window coordinates are scaled by 2x for display.
// - Window size is 24x24 at source resolution, so 48x48 at display resolution.
// - Overlay color is fixed to highlight (e.g., white or bright green).

module vga_overlay_face (
    input  wire        clk,
    input  wire        rst,

    input  wire [9:0]  vga_x,
    input  wire [8:0]  vga_y,
    input  wire        active_video,

    input  wire        face_found,
    input  wire        face_enable,
    input  wire [9:0]  window_x,
    input  wire [8:0]  window_y,

    input  wire [15:0] rgb565_in,
    output reg  [15:0] rgb565_out
);

    // Face window scaled to VGA coordinates (2x scaling from 320x240 -> 640x480).
    wire [10:0] display_x_min = {window_x, 1'b0};      // window_x * 2
    wire [10:0] display_x_max = {window_x, 1'b0} + 11'd48; // (window_x + 24) * 2
    wire [10:0] display_y_min = {window_y, 1'b0};      // window_y * 2
    wire [10:0] display_y_max = {window_y, 1'b0} + 11'd48; // (window_y + 24) * 2

    // Check if current pixel is on the bounding box border (2-pixel thick).
    wire x_on_border = (vga_x >= display_x_min && vga_x < display_x_max) &&
                       ((vga_y >= display_y_min && vga_y < display_y_min + 11'd2) ||
                        (vga_y >= display_y_max - 11'd2 && vga_y < display_y_max));

    wire y_on_border = (vga_y >= display_y_min && vga_y < display_y_max) &&
                       ((vga_x >= display_x_min && vga_x < display_x_min + 11'd2) ||
                        (vga_x >= display_x_max - 11'd2 && vga_x < display_x_max));

    wire on_border = (x_on_border || y_on_border) && face_found && active_video;

    // Overlay color: bright white (RGB565: R=31, G=63, B=31 = 0xFFFF).
    wire [15:0] overlay_color = 16'hFFFF;

    // Text overlay: "face detection is active" (5x7 font, 1-pixel spacing).
    localparam integer TEXT_LEN = 24;
    localparam integer TEXT_X_START = 640 - (TEXT_LEN * 6) - 4;
    localparam integer TEXT_Y_START = 480 - 8 - 2;

    function [7:0] text_char;
        input [4:0] idx;
        begin
            case (idx)
                5'd0:  text_char = 8'h66; // f
                5'd1:  text_char = 8'h61; // a
                5'd2:  text_char = 8'h63; // c
                5'd3:  text_char = 8'h65; // e
                5'd4:  text_char = 8'h20; // space
                5'd5:  text_char = 8'h64; // d
                5'd6:  text_char = 8'h65; // e
                5'd7:  text_char = 8'h74; // t
                5'd8:  text_char = 8'h65; // e
                5'd9:  text_char = 8'h63; // c
                5'd10: text_char = 8'h74; // t
                5'd11: text_char = 8'h69; // i
                5'd12: text_char = 8'h6f; // o
                5'd13: text_char = 8'h6e; // n
                5'd14: text_char = 8'h20; // space
                5'd15: text_char = 8'h69; // i
                5'd16: text_char = 8'h73; // s
                5'd17: text_char = 8'h20; // space
                5'd18: text_char = 8'h61; // a
                5'd19: text_char = 8'h63; // c
                5'd20: text_char = 8'h74; // t
                5'd21: text_char = 8'h69; // i
                5'd22: text_char = 8'h76; // v
                5'd23: text_char = 8'h65; // e
                default: text_char = 8'h20;
            endcase
        end
    endfunction

    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                8'h61: begin // a
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b01110;
                        3'd2: glyph_row = 5'b00001;
                        3'd3: glyph_row = 5'b01111;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h63: begin // c
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b01110;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10000;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b01110;
                        3'd6: glyph_row = 5'b00000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h64: begin // d
                    case (row)
                        3'd0: glyph_row = 5'b00001;
                        3'd1: glyph_row = 5'b00001;
                        3'd2: glyph_row = 5'b01101;
                        3'd3: glyph_row = 5'b10011;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b01111;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h65: begin // e
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b01110;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b11111;
                        3'd4: glyph_row = 5'b10000;
                        3'd5: glyph_row = 5'b01110;
                        3'd6: glyph_row = 5'b00000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h66: begin // f
                    case (row)
                        3'd0: glyph_row = 5'b00110;
                        3'd1: glyph_row = 5'b01001;
                        3'd2: glyph_row = 5'b01000;
                        3'd3: glyph_row = 5'b11100;
                        3'd4: glyph_row = 5'b01000;
                        3'd5: glyph_row = 5'b01000;
                        3'd6: glyph_row = 5'b01000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h69: begin // i
                    case (row)
                        3'd0: glyph_row = 5'b00100;
                        3'd1: glyph_row = 5'b00000;
                        3'd2: glyph_row = 5'b01100;
                        3'd3: glyph_row = 5'b00100;
                        3'd4: glyph_row = 5'b00100;
                        3'd5: glyph_row = 5'b00100;
                        3'd6: glyph_row = 5'b01110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h6e: begin // n
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b11100;
                        3'd2: glyph_row = 5'b10010;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b10001;
                        3'd6: glyph_row = 5'b10001;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h6f: begin // o
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b01110;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b10001;
                        3'd5: glyph_row = 5'b01110;
                        3'd6: glyph_row = 5'b00000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h73: begin // s
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b01111;
                        3'd2: glyph_row = 5'b10000;
                        3'd3: glyph_row = 5'b01110;
                        3'd4: glyph_row = 5'b00001;
                        3'd5: glyph_row = 5'b11110;
                        3'd6: glyph_row = 5'b00000;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h74: begin // t
                    case (row)
                        3'd0: glyph_row = 5'b01000;
                        3'd1: glyph_row = 5'b01000;
                        3'd2: glyph_row = 5'b11110;
                        3'd3: glyph_row = 5'b01000;
                        3'd4: glyph_row = 5'b01000;
                        3'd5: glyph_row = 5'b01001;
                        3'd6: glyph_row = 5'b00110;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                8'h76: begin // v
                    case (row)
                        3'd0: glyph_row = 5'b00000;
                        3'd1: glyph_row = 5'b10001;
                        3'd2: glyph_row = 5'b10001;
                        3'd3: glyph_row = 5'b10001;
                        3'd4: glyph_row = 5'b01010;
                        3'd5: glyph_row = 5'b01010;
                        3'd6: glyph_row = 5'b00100;
                        default: glyph_row = 5'b00000;
                    endcase
                end
                default: glyph_row = 5'b00000;
            endcase
        end
    endfunction

    wire [10:0] text_x_min = TEXT_X_START[10:0];
    wire [9:0]  text_y_min = TEXT_Y_START[9:0];
    wire        text_region = (vga_x >= text_x_min) &&
                              (vga_x < (text_x_min + (TEXT_LEN * 6))) &&
                              (vga_y >= text_y_min) &&
                              (vga_y < (text_y_min + 10'd8));

    wire [10:0] text_rel_x = vga_x - text_x_min;
    wire [9:0]  text_rel_y = vga_y - text_y_min;
    wire [4:0]  text_char_idx = text_rel_x / 11'd6;
    wire [2:0]  text_char_col = text_rel_x - (text_char_idx * 11'd6);
    wire [2:0]  text_row = text_rel_y[2:0];
    wire [7:0]  text_ch = text_char(text_char_idx);
    wire [4:0]  text_bits = glyph_row(text_ch, text_row);
    wire        text_pixel = (text_char_col < 3'd5) && text_bits[4 - text_char_col];
    wire        on_text = face_enable && active_video && text_region && text_pixel;

    always @(*) begin
        if (on_border || on_text) begin
            rgb565_out = overlay_color;
        end else begin
            rgb565_out = rgb565_in;
        end
    end

endmodule
