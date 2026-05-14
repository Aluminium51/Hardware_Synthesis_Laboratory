`timescale 1ns/1ps

// ov7670_sccb_master
//
// Purpose:
//   Perform one write-only OV7670 SCCB register transaction.
//
// Clock domain:
//   System/config clock, normally clk_100.
//
// Inputs:
//   start                 - one-cycle transaction request while idle
//   dev_addr/reg_addr/data - bytes transmitted in that order
//   siod_in               - observed SCCB data line for ACK sampling
//
// Outputs:
//   busy/done/ack_error   - transaction status
//   sioc                  - SCCB clock output
//   siod_oe/siod_out      - explicit open-drain SIOD drive controls
//
// Assumption:
//   dev_addr is the full 8-bit SCCB write address byte to transmit.
module ov7670_sccb_master #(
    parameter integer SCCB_HALF_PERIOD_CLKS = 500
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] dev_addr,
    input  wire [7:0] reg_addr,
    input  wire [7:0] reg_data,
    input  wire       siod_in,
    output reg        busy,
    output reg        done,
    output reg        ack_error,
    output reg        sioc,
    output reg        siod_oe,
    output reg        siod_out
);

    localparam [4:0] ST_IDLE           = 5'd0;
    localparam [4:0] ST_START_A        = 5'd1;
    localparam [4:0] ST_START_B        = 5'd2;
    localparam [4:0] ST_SEND_DEV_LOW   = 5'd3;
    localparam [4:0] ST_SEND_DEV_HIGH  = 5'd4;
    localparam [4:0] ST_DEV_ACK_LOW    = 5'd5;
    localparam [4:0] ST_DEV_ACK_HIGH   = 5'd6;
    localparam [4:0] ST_SEND_REG_LOW   = 5'd7;
    localparam [4:0] ST_SEND_REG_HIGH  = 5'd8;
    localparam [4:0] ST_REG_ACK_LOW    = 5'd9;
    localparam [4:0] ST_REG_ACK_HIGH   = 5'd10;
    localparam [4:0] ST_SEND_DATA_LOW  = 5'd11;
    localparam [4:0] ST_SEND_DATA_HIGH = 5'd12;
    localparam [4:0] ST_DATA_ACK_LOW   = 5'd13;
    localparam [4:0] ST_DATA_ACK_HIGH  = 5'd14;
    localparam [4:0] ST_STOP_A         = 5'd15;
    localparam [4:0] ST_STOP_B         = 5'd16;
    localparam [4:0] ST_STOP_C         = 5'd17;
    localparam [4:0] ST_DONE           = 5'd18;

    reg [4:0]  state = ST_IDLE;
    reg [31:0] clk_div = 32'd0;
    reg [7:0]  dev_addr_latched = 8'h00;
    reg [7:0]  reg_addr_latched = 8'h00;
    reg [7:0]  reg_data_latched = 8'h00;
    reg [7:0]  shift_reg = 8'h00;
    reg [2:0]  bit_idx = 3'd7;

    wire divider_running = (state != ST_IDLE) && (state != ST_DONE);
    wire sccb_tick = (clk_div == (SCCB_HALF_PERIOD_CLKS - 1));

    // Half-period timing divider. The FSM changes SIOC/SIOD only on sccb_tick,
    // making the SCCB waveform deterministic and easy to inspect in simulation.
    always @(posedge clk) begin
        if (rst) begin
            clk_div <= 32'd0;
        end else if (!divider_running) begin
            clk_div <= 32'd0;
        end else if (sccb_tick) begin
            clk_div <= 32'd0;
        end else begin
            clk_div <= clk_div + 1'b1;
        end
    end

    // SCCB transaction state machine. It emits START, device byte, register
    // byte, data byte, ACK checks after each byte, STOP, and a one-cycle done
    // pulse. SIOD is released during ACK phases so the external target can
    // pull the line low.
    always @(posedge clk) begin
        if (rst) begin
            state            <= ST_IDLE;
            dev_addr_latched <= 8'h00;
            reg_addr_latched <= 8'h00;
            reg_data_latched <= 8'h00;
            shift_reg        <= 8'h00;
            bit_idx          <= 3'd7;
            busy             <= 1'b0;
            done             <= 1'b0;
            ack_error        <= 1'b0;
            sioc             <= 1'b1;
            siod_oe          <= 1'b0;
            siod_out         <= 1'b1;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    // Idle bus is released-high. A start request latches all
                    // transaction fields before any bus activity begins.
                    busy      <= 1'b0;
                    ack_error <= 1'b0;
                    sioc      <= 1'b1;
                    siod_oe   <= 1'b0;
                    siod_out  <= 1'b1;

                    if (start) begin
                        dev_addr_latched <= dev_addr;
                        reg_addr_latched <= reg_addr;
                        reg_data_latched <= reg_data;
                        shift_reg        <= dev_addr;
                        bit_idx          <= 3'd7;
                        busy             <= 1'b1;
                        state            <= ST_START_A;
                        siod_oe          <= 1'b1;
                        siod_out         <= 1'b1;
                    end
                end

                ST_START_A: begin
                    // Start condition setup: data remains high while clock is
                    // high before the falling SIOD edge.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        state    <= ST_START_B;
                        siod_out <= 1'b0;
                    end
                end

                ST_START_B: begin
                    // Start condition hold: SIOD is low while SIOC is still high,
                    // then the clock is pulled low to begin bit transmission.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= 1'b0;

                    if (sccb_tick) begin
                        state    <= ST_SEND_DEV_LOW;
                        sioc     <= 1'b0;
                        siod_out <= shift_reg[7];
                    end
                end

                ST_SEND_DEV_LOW: begin
                    // Drive the selected data bit while SIOC is low.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b1;
                    siod_out <= shift_reg[bit_idx];

                    if (sccb_tick) begin
                        state <= ST_SEND_DEV_HIGH;
                        sioc  <= 1'b1;
                    end
                end

                ST_SEND_DEV_HIGH: begin
                    // Hold the bit stable while SIOC is high. After bit zero,
                    // release SIOD for the ACK phase.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= shift_reg[bit_idx];

                    if (sccb_tick) begin
                        sioc <= 1'b0;

                        if (bit_idx == 3'd0) begin
                            state    <= ST_DEV_ACK_LOW;
                            siod_oe  <= 1'b0;
                            siod_out <= 1'b1;
                        end else begin
                            bit_idx  <= bit_idx - 1'b1;
                            state    <= ST_SEND_DEV_LOW;
                            siod_out <= shift_reg[bit_idx - 1'b1];
                        end
                    end
                end

                ST_DEV_ACK_LOW: begin
                    // ACK setup for the device-address byte; FPGA releases SIOD.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        state <= ST_DEV_ACK_HIGH;
                        sioc  <= 1'b1;
                    end
                end

                ST_DEV_ACK_HIGH: begin
                    // Sample the target ACK while SIOC is high. A high SIOD
                    // records an ACK error and jumps to a clean STOP sequence.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        sioc <= 1'b0;

                        if (siod_in) begin
                            ack_error <= 1'b1;
                            state     <= ST_STOP_A;
                            siod_oe   <= 1'b1;
                            siod_out  <= 1'b0;
                        end else begin
                            shift_reg <= reg_addr_latched;
                            bit_idx   <= 3'd7;
                            state     <= ST_SEND_REG_LOW;
                            siod_oe   <= 1'b1;
                            siod_out  <= reg_addr_latched[7];
                        end
                    end
                end

                ST_SEND_REG_LOW: begin
                    // Drive the selected register-address bit while SIOC is low.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b1;
                    siod_out <= shift_reg[bit_idx];

                    if (sccb_tick) begin
                        state <= ST_SEND_REG_HIGH;
                        sioc  <= 1'b1;
                    end
                end

                ST_SEND_REG_HIGH: begin
                    // Hold the register-address bit while SIOC is high.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= shift_reg[bit_idx];

                    if (sccb_tick) begin
                        sioc <= 1'b0;

                        if (bit_idx == 3'd0) begin
                            state    <= ST_REG_ACK_LOW;
                            siod_oe  <= 1'b0;
                            siod_out <= 1'b1;
                        end else begin
                            bit_idx  <= bit_idx - 1'b1;
                            state    <= ST_SEND_REG_LOW;
                            siod_out <= shift_reg[bit_idx - 1'b1];
                        end
                    end
                end

                ST_REG_ACK_LOW: begin
                    // ACK setup for the register-address byte.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        state <= ST_REG_ACK_HIGH;
                        sioc  <= 1'b1;
                    end
                end

                ST_REG_ACK_HIGH: begin
                    // ACK sample after the register-address byte.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        sioc <= 1'b0;

                        if (siod_in) begin
                            ack_error <= 1'b1;
                            state     <= ST_STOP_A;
                            siod_oe   <= 1'b1;
                            siod_out  <= 1'b0;
                        end else begin
                            shift_reg <= reg_data_latched;
                            bit_idx   <= 3'd7;
                            state     <= ST_SEND_DATA_LOW;
                            siod_oe   <= 1'b1;
                            siod_out  <= reg_data_latched[7];
                        end
                    end
                end

                ST_SEND_DATA_LOW: begin
                    // Drive the selected register-data bit while SIOC is low.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b1;
                    siod_out <= shift_reg[bit_idx];

                    if (sccb_tick) begin
                        state <= ST_SEND_DATA_HIGH;
                        sioc  <= 1'b1;
                    end
                end

                ST_SEND_DATA_HIGH: begin
                    // Hold the register-data bit while SIOC is high.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= shift_reg[bit_idx];

                    if (sccb_tick) begin
                        sioc <= 1'b0;

                        if (bit_idx == 3'd0) begin
                            state    <= ST_DATA_ACK_LOW;
                            siod_oe  <= 1'b0;
                            siod_out <= 1'b1;
                        end else begin
                            bit_idx  <= bit_idx - 1'b1;
                            state    <= ST_SEND_DATA_LOW;
                            siod_out <= shift_reg[bit_idx - 1'b1];
                        end
                    end
                end

                ST_DATA_ACK_LOW: begin
                    // ACK setup for the register-data byte.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        state <= ST_DATA_ACK_HIGH;
                        sioc  <= 1'b1;
                    end
                end

                ST_DATA_ACK_HIGH: begin
                    // Final ACK sample; the transaction continues to STOP even
                    // when an ACK error is detected.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        sioc <= 1'b0;

                        if (siod_in) begin
                            ack_error <= 1'b1;
                        end

                        state    <= ST_STOP_A;
                        siod_oe  <= 1'b1;
                        siod_out <= 1'b0;
                    end
                end

                ST_STOP_A: begin
                    // Stop sequence begins with both SIOC and SIOD low.
                    sioc     <= 1'b0;
                    siod_oe  <= 1'b1;
                    siod_out <= 1'b0;

                    if (sccb_tick) begin
                        state <= ST_STOP_B;
                        sioc  <= 1'b1;
                    end
                end

                ST_STOP_B: begin
                    // Raise SIOC while SIOD remains low.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= 1'b0;

                    if (sccb_tick) begin
                        state    <= ST_STOP_C;
                        siod_out <= 1'b1;
                    end
                end

                ST_STOP_C: begin
                    // Stop condition completes when SIOD rises while SIOC is high.
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b1;
                    siod_out <= 1'b1;

                    if (sccb_tick) begin
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    // Report transaction completion for one system-clock cycle.
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    sioc     <= 1'b1;
                    siod_oe  <= 1'b0;
                    siod_out <= 1'b1;
                    state    <= ST_IDLE;
                end

                default: begin
                    state     <= ST_IDLE;
                    busy      <= 1'b0;
                    done      <= 1'b0;
                    ack_error <= 1'b0;
                    sioc      <= 1'b1;
                    siod_oe   <= 1'b0;
                    siod_out  <= 1'b1;
                end
            endcase
        end
    end

endmodule
