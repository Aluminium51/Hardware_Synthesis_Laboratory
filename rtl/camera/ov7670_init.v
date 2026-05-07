`timescale 1ns/1ps

// ov7670_init
// Purpose: sequence the OV7670 startup register ROM through the SCCB master.
// Clock domain: system/config clock, normally clk_100.
// Ports: explicit start/status interface plus SCCB-master transaction controls.
// Assumptions: SCCB done is a completion pulse; ack_error is valid with done.
module ov7670_init #(
    parameter integer STARTUP_DELAY_CLKS    = 1000000,
    parameter integer POST_RESET_DELAY_CLKS = 1000000,
    // parameter integer POST_RESET_DELAY_CLKS = 10000000,
    parameter [7:0]   OV7670_DEV_ADDR       = 8'h42
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start_init,
    input  wire       sccb_busy,
    input  wire       sccb_done,
    input  wire       sccb_ack_error,
    output reg        sccb_start,
    output wire [7:0] sccb_dev_addr,
    output reg  [7:0] sccb_reg_addr,
    output reg  [7:0] sccb_reg_data,
    output reg        init_busy,
    output reg        init_done,
    output reg        init_error
);

    localparam [2:0] ST_STARTUP_WAIT  = 3'd0;
    localparam [2:0] ST_WAIT_START    = 3'd1;
    localparam [2:0] ST_LOAD_ENTRY    = 3'd2;
    localparam [2:0] ST_ISSUE_WRITE   = 3'd3;
    localparam [2:0] ST_WAIT_SCCB     = 3'd4;
    localparam [2:0] ST_POST_RESET    = 3'd5;
    localparam [2:0] ST_DONE          = 3'd6;
    localparam [2:0] ST_ERROR         = 3'd7;

    localparam [31:0] STARTUP_DELAY_LIMIT =
        (STARTUP_DELAY_CLKS > 0) ? (STARTUP_DELAY_CLKS - 1) : 0;
    localparam [31:0] POST_RESET_DELAY_LIMIT =
        (POST_RESET_DELAY_CLKS > 0) ? (POST_RESET_DELAY_CLKS - 1) : 0;

    reg [2:0]  state = ST_STARTUP_WAIT;
    reg [31:0] startup_delay_count = 32'd0;
    reg [31:0] post_reset_delay_count = 32'd0;
    reg        start_seen = 1'b0;
    reg        current_is_last = 1'b0;

    reg  [7:0] rom_index = 8'd0;
    wire [7:0] rom_reg_addr;
    wire [7:0] rom_reg_data;
    wire       rom_is_last;

    assign sccb_dev_addr = OV7670_DEV_ADDR;

    ov7670_reg_rom reg_rom (
        .index    (rom_index),
        .reg_addr (rom_reg_addr),
        .reg_data (rom_reg_data),
        .is_last  (rom_is_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            state                  <= ST_STARTUP_WAIT;
            startup_delay_count    <= 32'd0;
            post_reset_delay_count <= 32'd0;
            start_seen             <= 1'b0;
            rom_index              <= 8'd0;
            current_is_last        <= 1'b0;
            sccb_start             <= 1'b0;
            sccb_reg_addr          <= 8'h00;
            sccb_reg_data          <= 8'h00;
            init_busy              <= 1'b0;
            init_done              <= 1'b0;
            init_error             <= 1'b0;
        end else begin
            sccb_start <= 1'b0;

            if (start_init && !init_busy && !init_done && !init_error) begin
                start_seen <= 1'b1;
            end

            case (state)
                ST_STARTUP_WAIT: begin
                    if ((STARTUP_DELAY_CLKS <= 0) ||
                        (startup_delay_count >= STARTUP_DELAY_LIMIT)) begin
                        if (start_seen || start_init) begin
                            init_busy <= 1'b1;
                            rom_index <= 8'd0;
                            state     <= ST_LOAD_ENTRY;
                        end else begin
                            state <= ST_WAIT_START;
                        end
                    end else begin
                        startup_delay_count <= startup_delay_count + 1'b1;
                    end
                end

                ST_WAIT_START: begin
                    if (start_init) begin
                        start_seen <= 1'b1;
                        init_busy  <= 1'b1;
                        rom_index  <= 8'd0;
                        state      <= ST_LOAD_ENTRY;
                    end
                end

                ST_LOAD_ENTRY: begin
                    sccb_reg_addr   <= rom_reg_addr;
                    sccb_reg_data   <= rom_reg_data;
                    current_is_last <= rom_is_last;
                    state           <= ST_ISSUE_WRITE;
                end

                ST_ISSUE_WRITE: begin
                    if (!sccb_busy) begin
                        sccb_start <= 1'b1;
                        state      <= ST_WAIT_SCCB;
                    end
                end

                ST_WAIT_SCCB: begin
                    if (sccb_done) begin
                        if (sccb_ack_error) begin
                            init_busy  <= 1'b0;
                            init_error <= 1'b1;
                            state      <= ST_ERROR;
                        end else if (current_is_last) begin
                            init_busy <= 1'b0;
                            init_done <= 1'b1;
                            state     <= ST_DONE;
                        end else if ((sccb_reg_addr == 8'h12) &&
                                     (sccb_reg_data == 8'h80)) begin
                            post_reset_delay_count <= 32'd0;
                            state                  <= ST_POST_RESET;
                        end else begin
                            rom_index <= rom_index + 1'b1;
                            state     <= ST_LOAD_ENTRY;
                        end
                    end
                end

                ST_POST_RESET: begin
                    if ((POST_RESET_DELAY_CLKS <= 0) ||
                        (post_reset_delay_count >= POST_RESET_DELAY_LIMIT)) begin
                        rom_index <= rom_index + 1'b1;
                        state     <= ST_LOAD_ENTRY;
                    end else begin
                        post_reset_delay_count <= post_reset_delay_count + 1'b1;
                    end
                end

                ST_DONE: begin
                    init_busy <= 1'b0;
                    init_done <= 1'b1;
                end

                ST_ERROR: begin
                    init_busy  <= 1'b0;
                    init_error <= 1'b1;
                end

                default: begin
                    init_busy  <= 1'b0;
                    init_error <= 1'b1;
                    state      <= ST_ERROR;
                end
            endcase
        end
    end

endmodule
