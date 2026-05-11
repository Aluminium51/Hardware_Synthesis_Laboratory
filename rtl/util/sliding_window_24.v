// sliding_window_24.v
// Purpose: Build a WINDOW x WINDOW grayscale sliding window from a raster pixel stream.
// Clock domain: camera/processing pixel clock domain.
// Inputs are expected to be asserted as follows:
// - frame_start: pulse at first valid pixel of a frame
// - line_start: pulse at first valid pixel of a line
// - px_valid: high for each valid pixel sample

module sliding_window_24 #(
    parameter integer IMAGE_WIDTH = 320,
    parameter integer DATA_WIDTH  = 8,
    parameter integer WINDOW      = 24
) (
    input  wire                                clk,
    input  wire                                rst,
    input  wire                                px_valid,
    input  wire                                line_start,
    input  wire                                frame_start,
    input  wire [DATA_WIDTH-1:0]               px_in,

    output reg                                 window_valid,
    output reg [9:0]                           window_x,
    output reg [8:0]                           window_y,
    output reg [(WINDOW*WINDOW*DATA_WIDTH)-1:0] window_data
);

wire [DATA_WIDTH-1:0] line_chain [0:WINDOW-1];
wire [WINDOW-2:0] lb_full;
wire [DATA_WIDTH-1:0] row_in [0:WINDOW-1];

assign line_chain[0] = px_in;

genvar g;
generate
    for (g = 0; g < WINDOW-1; g = g + 1) begin : G_LB
        linebuffer_ram #(
            .DATA_WIDTH(DATA_WIDTH),
            .DEPTH(IMAGE_WIDTH)
        ) u_lb (
            .clk(clk),
            .rst(rst),
            .wr_en(px_valid),
            .din(line_chain[g]),
            .dout(line_chain[g+1]),
            .full(lb_full[g])
        );
    end
endgenerate

generate
    for (g = 0; g < WINDOW; g = g + 1) begin : G_ROWMAP
        // row 0 is oldest line (top of window), row WINDOW-1 is current line.
        assign row_in[g] = line_chain[WINDOW-1-g];
    end
endgenerate

reg [DATA_WIDTH-1:0] shift_regs [0:WINDOW-1][0:WINDOW-1];
reg [DATA_WIDTH-1:0] shift_next [0:WINDOW-1][0:WINDOW-1];
reg [9:0] col_ctr;
reg [8:0] row_ctr;
reg [9:0] next_col_ctr;
reg [8:0] next_row_ctr;

wire rows_ready = &lb_full;
wire cols_ready = (col_ctr >= WINDOW-1);
wire geom_ready = (row_ctr >= WINDOW-1);

integer i;
integer j;
always @(posedge clk) begin
    if (rst) begin
        col_ctr <= 10'd0;
        row_ctr <= 9'd0;
        next_col_ctr <= 10'd0;
        next_row_ctr <= 9'd0;
        window_valid <= 1'b0;
        window_x <= 10'd0;
        window_y <= 9'd0;
        window_data <= {(WINDOW*WINDOW*DATA_WIDTH){1'b0}};

        for (i = 0; i < WINDOW; i = i + 1) begin
            for (j = 0; j < WINDOW; j = j + 1) begin
                shift_regs[i][j] <= {DATA_WIDTH{1'b0}};
                shift_next[i][j] <= {DATA_WIDTH{1'b0}};
            end
        end
    end else begin
        window_valid <= 1'b0;

        if (px_valid) begin
            if (frame_start) begin
                next_row_ctr = 9'd0;
                next_col_ctr = 10'd0;
            end else if (line_start) begin
                next_row_ctr = row_ctr + 9'd1;
                next_col_ctr = 10'd0;
            end else begin
                next_row_ctr = row_ctr;
                next_col_ctr = col_ctr + 10'd1;
            end

            row_ctr <= next_row_ctr;
            col_ctr <= next_col_ctr;

            for (i = 0; i < WINDOW; i = i + 1) begin
                for (j = 0; j < WINDOW-1; j = j + 1) begin
                    shift_next[i][j] = shift_regs[i][j+1];
                end
                shift_next[i][WINDOW-1] = row_in[i];

                for (j = 0; j < WINDOW; j = j + 1) begin
                    shift_regs[i][j] <= shift_next[i][j];
                end
            end

            if (rows_ready && (next_row_ctr >= WINDOW-1) && (next_col_ctr >= WINDOW-1)) begin
                for (i = 0; i < WINDOW; i = i + 1) begin
                    for (j = 0; j < WINDOW; j = j + 1) begin
                        window_data[((i*WINDOW + j + 1)*DATA_WIDTH)-1 -: DATA_WIDTH] <= shift_next[i][j];
                    end
                end
                window_x <= next_col_ctr - (WINDOW-1);
                window_y <= next_row_ctr - (WINDOW-1);
                window_valid <= 1'b1;
            end
        end
    end
end

endmodule
