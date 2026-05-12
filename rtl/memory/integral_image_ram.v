`timescale 1ns/1ps

// integral_image_ram
// Purpose: streaming integral-image store for the camera pixel domain.
// Clock domain: camera/processing pixel clock for writes; same-clock read port for detector queries.
// Assumptions: pixels arrive in raster order with frame_start on the first pixel of each frame and line_start on the first pixel of each line.
module integral_image_ram #(
    parameter integer IMAGE_WIDTH  = 320,
    parameter integer IMAGE_HEIGHT = 240,
    parameter integer DATA_WIDTH   = 18,
    parameter integer ADDR_WIDTH   = 17,
    parameter integer FRAME_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT
) (
    input  wire                    clk,
    input  wire                    rst,

    input  wire                    wr_en,
    input  wire [ADDR_WIDTH-1:0]   wr_addr,
    input  wire [7:0]              wr_px,
    input  wire                    line_start,
    input  wire                    frame_start,

    input  wire                    rd_en,
    input  wire [ADDR_WIDTH-1:0]   rd_addr,
    output reg  [DATA_WIDTH-1:0]   rd_data,
    output reg                     rd_valid
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:FRAME_PIXELS-1];

    reg [DATA_WIDTH-1:0] row_sum;

    reg                    req_valid;
    reg [ADDR_WIDTH-1:0]   req_addr;
    reg [DATA_WIDTH-1:0]   req_row_sum;
    reg                    req_top_valid;
    reg [ADDR_WIDTH-1:0]   req_top_addr;

    reg                    wb_valid;
    reg [ADDR_WIDTH-1:0]   wb_addr;
    reg [DATA_WIDTH-1:0]   wb_row_sum;
    reg [DATA_WIDTH-1:0]   top_data_q;

    wire [DATA_WIDTH-1:0] row_sum_next = (frame_start || line_start) ? { {(DATA_WIDTH-8){1'b0}}, wr_px } : (row_sum + {{(DATA_WIDTH-8){1'b0}}, wr_px});

    integer idx;

    initial begin
        for (idx = 0; idx < FRAME_PIXELS; idx = idx + 1) begin
            mem[idx] = {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            row_sum    <= {DATA_WIDTH{1'b0}};
            req_valid  <= 1'b0;
            req_addr   <= {ADDR_WIDTH{1'b0}};
            req_row_sum <= {DATA_WIDTH{1'b0}};
            req_top_valid <= 1'b0;
            req_top_addr  <= {ADDR_WIDTH{1'b0}};
            wb_valid   <= 1'b0;
            wb_addr    <= {ADDR_WIDTH{1'b0}};
            wb_row_sum <= {DATA_WIDTH{1'b0}};
            top_data_q <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wb_valid) begin
                mem[wb_addr] <= wb_row_sum + top_data_q;
            end

            if (req_valid) begin
                top_data_q <= req_top_valid ? mem[req_top_addr] : {DATA_WIDTH{1'b0}};
            end else begin
                top_data_q <= {DATA_WIDTH{1'b0}};
            end

            wb_valid   <= req_valid;
            wb_addr    <= req_addr;
            wb_row_sum <= req_row_sum;

            if (wr_en) begin
                row_sum        <= row_sum_next;
                req_valid      <= 1'b1;
                req_addr       <= wr_addr;
                req_row_sum    <= row_sum_next;
                req_top_valid  <= (wr_addr >= IMAGE_WIDTH);
                req_top_addr   <= wr_addr - IMAGE_WIDTH[ADDR_WIDTH-1:0];
            end else begin
                req_valid <= 1'b0;
            end

            if (rd_en) begin
                rd_data  <= mem[rd_addr];
                rd_valid <= 1'b1;
            end else begin
                rd_valid <= 1'b0;
            end
        end
    end

endmodule