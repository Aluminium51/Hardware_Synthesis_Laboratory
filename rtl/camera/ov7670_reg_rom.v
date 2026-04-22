`timescale 1ns/1ps

// ov7670_reg_rom
// Purpose: fixed OV7670 startup register table for conservative QVGA RGB565 mode.
// Clock domain: none; this is a combinational lookup table.
// Ports: index selects one register/value entry and reports the final entry.
// Assumption: invalid indices safely alias to the final valid entry.
module ov7670_reg_rom (
    input  wire [4:0] index,
    output wire [7:0] reg_addr,
    output wire [7:0] reg_data,
    output wire       is_last
);

    function [16:0] rom_entry;
        input [4:0] entry_index;
        begin
            rom_entry = {1'b1, 8'ha2, 8'h02};

            case (entry_index)
                5'd0: begin
                    rom_entry = {1'b0, 8'h12, 8'h80}; // COM7: soft reset
                end

                5'd1: begin
                    rom_entry = {1'b0, 8'h11, 8'h01}; // CLKRC: modest internal clock prescale
                end

                5'd2: begin
                    rom_entry = {1'b0, 8'h12, 8'h14}; // COM7: QVGA + RGB output
                end

                5'd3: begin
                    rom_entry = {1'b0, 8'h8c, 8'h00}; // RGB444: disabled, use RGB565 path
                end

                5'd4: begin
                    rom_entry = {1'b0, 8'h40, 8'hd0}; // COM15: full range + RGB565
                end

                5'd5: begin
                    rom_entry = {1'b0, 8'h0c, 8'h04}; // COM3: enable scaling/DCW
                end

                5'd6: begin
                    rom_entry = {1'b0, 8'h3e, 8'h19}; // COM14: manual scaling + scaled PCLK divide
                end

                5'd7: begin
                    rom_entry = {1'b0, 8'h72, 8'h11}; // SCALING_DCWCTR: downsample by 2
                end

                5'd8: begin
                    rom_entry = {1'b0, 8'h70, 8'h3a}; // SCALING_XSC: default horizontal scale factor
                end

                5'd9: begin
                    rom_entry = {1'b0, 8'h71, 8'h35}; // SCALING_YSC: default vertical scale factor
                end

                5'd10: begin
                    rom_entry = {1'b0, 8'h73, 8'hf1}; // SCALING_PCLK_DIV: scaled PCLK divider setting
                end

                5'd11: begin
                    rom_entry = {1'b1, 8'ha2, 8'h02}; // SCALING_PCLK_DELAY: default scaling delay
                end

                default: begin
                    rom_entry = {1'b1, 8'ha2, 8'h02};
                end
            endcase
        end
    endfunction

    wire [16:0] selected_entry = rom_entry(index);

    assign is_last  = selected_entry[16];
    assign reg_addr = selected_entry[15:8];
    assign reg_data = selected_entry[7:0];

endmodule
