`timescale 1ns/1ps

// vga_reader_bilinear
// Purpose: bilinear 320x240 to 640x480 upscaling using time-multiplexed BRAM reads.
// Clock domain: clk_100 with pixel_ce indicating the 25 MHz VGA pixel cadence.
// Outputs: framebuffer read address plus delayed sync/control and RGB565 output.
// Assumption: rd_data is valid one clk_100 after rd_addr is presented.
module vga_reader_bilinear (
    input  wire        clk_100,
    input  wire        pixel_ce,
    input  wire        rst_vga,
    input  wire [9:0]  vga_x,
    input  wire [9:0]  vga_y,
    input  wire        hsync_in,
    input  wire        vsync_in,
    input  wire        active_video_in,
    input  wire [15:0] rd_data,
    input  wire        enable_bilinear,
    output reg  [16:0] rd_addr,
    output reg         hsync_out,
    output reg         vsync_out,
    output reg         active_video_out,
    output reg  [15:0] rgb565_out
);

    function automatic [16:0] fb_addr;
        input [8:0] x;
        input [7:0] y;
        begin
            fb_addr = {1'b0, y, 8'b0} + {3'b000, y, 6'b0} + {8'b00000000, x};
        end
    endfunction

    wire [8:0] src_x_raw = vga_x[9:1];
    wire [7:0] src_y_raw = vga_y[8:1];

    wire [8:0] src_x_clamp = (src_x_raw > 9'd319) ? 9'd319 : src_x_raw;
    wire [7:0] src_y_clamp = (src_y_raw > 8'd239) ? 8'd239 : src_y_raw;

    wire [8:0] src_x1_clamp = (src_x_clamp == 9'd319) ? 9'd319 : (src_x_clamp + 1'b1);
    wire [7:0] src_y1_clamp = (src_y_clamp == 8'd239) ? 8'd239 : (src_y_clamp + 1'b1);

    reg [8:0] src_x_reg = 9'd0;
    reg [7:0] src_y_reg = 8'd0;
    reg [8:0] src_x1_reg = 9'd0;
    reg [7:0] src_y1_reg = 8'd0;

    reg [1:0] fetch_state = 2'd0;
    reg       fetch_active = 1'b0;

    reg [1:0] issued_state_d = 2'd0;
    reg       issued_valid_d = 1'b0;

    reg [15:0] p00_reg = 16'h0000;
    reg [15:0] p10_reg = 16'h0000;
    reg [15:0] p01_reg = 16'h0000;
    reg [15:0] p11_reg = 16'h0000;

    reg        output_valid = 1'b0;

    reg [4:0] hsync_pipe = 5'b11111;
    reg [4:0] vsync_pipe = 5'b11111;
    reg [4:0] active_pipe = 5'b00000;
    reg [4:0] lsb_x_pipe = 5'b00000;
    reg [4:0] lsb_y_pipe = 5'b00000;
    reg [4:0] enable_pipe = 5'b00000;

    reg        hsync_hold = 1'b1;
    reg        vsync_hold = 1'b1;
    reg        active_hold = 1'b0;
    reg        enable_hold = 1'b0;
    reg [15:0] rgb_calc_reg = 16'h0000;
    reg [15:0] p00_hold_reg = 16'h0000;

    reg [4:0] r_out;
    reg [5:0] g_out;
    reg [4:0] b_out;

    reg [6:0] r_sum2;
    reg [7:0] g_sum2;
    reg [6:0] b_sum2;
    reg [6:0] r_sum4;
    reg [7:0] g_sum4;
    reg [6:0] b_sum4;

    wire [16:0] addr_p00_next = fb_addr(src_x_clamp, src_y_clamp);
    wire [16:0] addr_p10_next = fb_addr(src_x1_clamp, src_y_clamp);
    wire [16:0] addr_p01_next = fb_addr(src_x_clamp, src_y1_clamp);
    wire [16:0] addr_p11_next = fb_addr(src_x1_clamp, src_y1_clamp);

    wire [16:0] addr_p00_reg = fb_addr(src_x_reg, src_y_reg);
    wire [16:0] addr_p10_reg = fb_addr(src_x1_reg, src_y_reg);
    wire [16:0] addr_p01_reg = fb_addr(src_x_reg, src_y1_reg);
    wire [16:0] addr_p11_reg = fb_addr(src_x1_reg, src_y1_reg);

    wire [1:0] issued_state_next = pixel_ce ? 2'd0 : (fetch_active ? fetch_state : 2'd0);
    wire       issued_valid_next = pixel_ce || fetch_active;
    wire       compute_valid = issued_valid_d && (issued_state_d == 2'd3);

    always @(posedge clk_100) begin
        if (rst_vga) begin
            rd_addr          <= 17'd0;
            src_x_reg        <= 9'd0;
            src_y_reg        <= 8'd0;
            src_x1_reg       <= 9'd0;
            src_y1_reg       <= 8'd0;
            fetch_state      <= 2'd0;
            fetch_active     <= 1'b0;
            issued_state_d   <= 2'd0;
            issued_valid_d   <= 1'b0;
            p00_reg          <= 16'h0000;
            p10_reg          <= 16'h0000;
            p01_reg          <= 16'h0000;
            p11_reg          <= 16'h0000;
            output_valid     <= 1'b0;
            hsync_pipe       <= 5'b11111;
            vsync_pipe       <= 5'b11111;
            active_pipe      <= 5'b00000;
            lsb_x_pipe       <= 5'b00000;
            lsb_y_pipe       <= 5'b00000;
            enable_pipe      <= 5'b00000;
            hsync_hold       <= 1'b1;
            vsync_hold       <= 1'b1;
            active_hold      <= 1'b0;
            enable_hold      <= 1'b0;
            rgb_calc_reg     <= 16'h0000;
            p00_hold_reg     <= 16'h0000;
            hsync_out        <= 1'b1;
            vsync_out        <= 1'b1;
            active_video_out <= 1'b0;
            rgb565_out       <= 16'h0000;
        end else begin
            if (pixel_ce) begin
                src_x_reg    <= src_x_clamp;
                src_y_reg    <= src_y_clamp;
                src_x1_reg   <= src_x1_clamp;
                src_y1_reg   <= src_y1_clamp;
                fetch_state  <= 2'd1;
                fetch_active <= 1'b1;
                rd_addr      <= addr_p00_next;
            end else if (fetch_active) begin
                case (fetch_state)
                    2'd1: rd_addr <= addr_p10_reg;
                    2'd2: rd_addr <= addr_p01_reg;
                    2'd3: rd_addr <= addr_p11_reg;
                    default: rd_addr <= addr_p00_reg;
                endcase

                if (fetch_state == 2'd3) begin
                    fetch_state  <= 2'd0;
                    fetch_active <= 1'b0;
                end else begin
                    fetch_state <= fetch_state + 1'b1;
                end
            end else begin
                rd_addr <= 17'd0;
            end

            issued_state_d <= issued_state_next;
            issued_valid_d <= issued_valid_next;

            if (issued_valid_d) begin
                case (issued_state_d)
                    2'd0: p00_reg <= rd_data;
                    2'd1: p10_reg <= rd_data;
                    2'd2: p01_reg <= rd_data;
                    2'd3: p11_reg <= rd_data;
                    default: p00_reg <= rd_data;
                endcase
            end

            if (pixel_ce) begin
                hsync_pipe[0]  <= hsync_in;
                vsync_pipe[0]  <= vsync_in;
                active_pipe[0] <= active_video_in;
                lsb_x_pipe[0]  <= vga_x[0];
                lsb_y_pipe[0]  <= vga_y[0];
                enable_pipe[0] <= enable_bilinear;
            end

            hsync_pipe[4:1]  <= hsync_pipe[3:0];
            vsync_pipe[4:1]  <= vsync_pipe[3:0];
            active_pipe[4:1] <= active_pipe[3:0];
            lsb_x_pipe[4:1]  <= lsb_x_pipe[3:0];
            lsb_y_pipe[4:1]  <= lsb_y_pipe[3:0];
            enable_pipe[4:1] <= enable_pipe[3:0];

            if (compute_valid) begin
                hsync_hold   <= hsync_pipe[4];
                vsync_hold   <= vsync_pipe[4];
                active_hold  <= active_pipe[4];
                enable_hold  <= enable_pipe[4];
                p00_hold_reg <= p00_reg;
                rgb_calc_reg <= {r_out, g_out, b_out};
            end

            output_valid <= compute_valid;

            if (output_valid) begin
                hsync_out        <= hsync_hold;
                vsync_out        <= vsync_hold;
                active_video_out <= active_hold;
                if (active_hold) begin
                    rgb565_out <= enable_hold ? rgb_calc_reg : p00_hold_reg;
                end else begin
                    rgb565_out <= 16'h0000;
                end
            end
        end
    end

    wire [4:0] r00 = p00_reg[15:11];
    wire [5:0] g00 = p00_reg[10:5];
    wire [4:0] b00 = p00_reg[4:0];
    wire [4:0] r10 = p10_reg[15:11];
    wire [5:0] g10 = p10_reg[10:5];
    wire [4:0] b10 = p10_reg[4:0];
    wire [4:0] r01 = p01_reg[15:11];
    wire [5:0] g01 = p01_reg[10:5];
    wire [4:0] b01 = p01_reg[4:0];
    wire [15:0] p11_use = (issued_valid_d && (issued_state_d == 2'd3)) ? rd_data : p11_reg;
    wire [4:0] r11 = p11_use[15:11];
    wire [5:0] g11 = p11_use[10:5];
    wire [4:0] b11 = p11_use[4:0];

    always @* begin
        r_out = r00;
        g_out = g00;
        b_out = b00;

        r_sum2 = 7'd0;
        g_sum2 = 8'd0;
        b_sum2 = 7'd0;
        r_sum4 = 7'd0;
        g_sum4 = 8'd0;
        b_sum4 = 7'd0;

        if (lsb_x_pipe[4] && !lsb_y_pipe[4]) begin
            r_sum2 = r00 + r10;
            g_sum2 = g00 + g10;
            b_sum2 = b00 + b10;
            r_out = r_sum2[6:1];
            g_out = g_sum2[7:1];
            b_out = b_sum2[6:1];
        end else if (!lsb_x_pipe[4] && lsb_y_pipe[4]) begin
            r_sum2 = r00 + r01;
            g_sum2 = g00 + g01;
            b_sum2 = b00 + b01;
            r_out = r_sum2[6:1];
            g_out = g_sum2[7:1];
            b_out = b_sum2[6:1];
        end else if (lsb_x_pipe[4] && lsb_y_pipe[4]) begin
            r_sum4 = r00 + r10 + r01 + r11;
            g_sum4 = g00 + g10 + g01 + g11;
            b_sum4 = b00 + b10 + b01 + b11;
            r_out = r_sum4[6:2];
            g_out = g_sum4[7:2];
            b_out = b_sum4[6:2];
        end
    end

endmodule
