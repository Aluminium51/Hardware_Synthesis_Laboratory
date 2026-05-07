`timescale 1ns/1ps

// ov7670_reg_rom
// Purpose: fixed OV7670 startup register table for RGB565/QVGA debug bring-up.
// Clock domain: none; this is a combinational lookup table.
// Ports: index selects one register/value entry and reports the final entry.
// Assumptions: invalid indices safely alias to the final valid entry.
//
// Bring-up note:
// - This table keeps the OV7670 internal color-bar pattern enabled so the
//   first-light target is a stable known pattern instead of live video.
// - After the camera path is stable on hardware, change the final COM17 write
//   from 42/F0 to 42/00 to return to live image output.
module ov7670_reg_rom (
    input  wire [7:0] index,
    output wire [7:0] reg_addr,
    output wire [7:0] reg_data,
    output wire       is_last
);

    function [16:0] rom_entry;
        input [7:0] entry_index;
        begin
            rom_entry = {1'b1, 8'h42, 8'hF0};

            case (entry_index)
                // Reset and core format selection.
                8'd0:   rom_entry = {1'b0, 8'h12, 8'h80};
                8'd1:   rom_entry = {1'b0, 8'h12, 8'h14};
                8'd2:   rom_entry = {1'b0, 8'h40, 8'hD0};
                8'd3:   rom_entry = {1'b0, 8'h3A, 8'h04};
                8'd4:   rom_entry = {1'b0, 8'h3D, 8'hC8};
                8'd5:   rom_entry = {1'b0, 8'h1E, 8'h31};
                8'd6:   rom_entry = {1'b0, 8'h6B, 8'h00};
                8'd7:   rom_entry = {1'b0, 8'h32, 8'hB6};
                8'd8:   rom_entry = {1'b0, 8'h17, 8'h13};
                8'd9:   rom_entry = {1'b0, 8'h18, 8'h01};
                8'd10:  rom_entry = {1'b0, 8'h19, 8'h02};
                8'd11:  rom_entry = {1'b0, 8'h1A, 8'h7A};
                8'd12:  rom_entry = {1'b0, 8'h03, 8'h0A};
                8'd13:  rom_entry = {1'b0, 8'h0C, 8'h00};
                8'd14:  rom_entry = {1'b0, 8'h3E, 8'h00};
                8'd15:  rom_entry = {1'b0, 8'h70, 8'h00};
                8'd16:  rom_entry = {1'b0, 8'h71, 8'h00};
                8'd17:  rom_entry = {1'b0, 8'h72, 8'h11};
                8'd18:  rom_entry = {1'b0, 8'h73, 8'h00};
                8'd19:  rom_entry = {1'b0, 8'hA2, 8'h02};
                8'd20:  rom_entry = {1'b0, 8'h11, 8'h80};

                // Gamma and automatic control defaults.
                8'd21:  rom_entry = {1'b0, 8'h7A, 8'h20};
                8'd22:  rom_entry = {1'b0, 8'h7B, 8'h1C};
                8'd23:  rom_entry = {1'b0, 8'h7C, 8'h28};
                8'd24:  rom_entry = {1'b0, 8'h7D, 8'h3C};
                8'd25:  rom_entry = {1'b0, 8'h7E, 8'h55};
                8'd26:  rom_entry = {1'b0, 8'h7F, 8'h68};
                8'd27:  rom_entry = {1'b0, 8'h80, 8'h76};
                8'd28:  rom_entry = {1'b0, 8'h81, 8'h80};
                8'd29:  rom_entry = {1'b0, 8'h82, 8'h88};
                8'd30:  rom_entry = {1'b0, 8'h83, 8'h8F};
                8'd31:  rom_entry = {1'b0, 8'h84, 8'h96};
                8'd32:  rom_entry = {1'b0, 8'h85, 8'hA3};
                8'd33:  rom_entry = {1'b0, 8'h86, 8'hAF};
                8'd34:  rom_entry = {1'b0, 8'h87, 8'hC4};
                8'd35:  rom_entry = {1'b0, 8'h88, 8'hD7};
                8'd36:  rom_entry = {1'b0, 8'h89, 8'hE8};
                8'd37:  rom_entry = {1'b0, 8'h13, 8'hE0};
                8'd38:  rom_entry = {1'b0, 8'h00, 8'h00};
                8'd39:  rom_entry = {1'b0, 8'h10, 8'h00};
                8'd40:  rom_entry = {1'b0, 8'h0D, 8'h00};
                8'd41:  rom_entry = {1'b0, 8'h14, 8'h28};
                8'd42:  rom_entry = {1'b0, 8'hA5, 8'h05};
                8'd43:  rom_entry = {1'b0, 8'hAB, 8'h07};
                8'd44:  rom_entry = {1'b0, 8'h24, 8'h75};
                8'd45:  rom_entry = {1'b0, 8'h25, 8'h63};
                8'd46:  rom_entry = {1'b0, 8'h26, 8'hA5};
                8'd47:  rom_entry = {1'b0, 8'h9F, 8'h78};
                8'd48:  rom_entry = {1'b0, 8'hA0, 8'h68};
                8'd49:  rom_entry = {1'b0, 8'hA1, 8'h03};
                8'd50:  rom_entry = {1'b0, 8'hA6, 8'hDF};
                8'd51:  rom_entry = {1'b0, 8'hA7, 8'hDF};
                8'd52:  rom_entry = {1'b0, 8'hA8, 8'hF0};
                8'd53:  rom_entry = {1'b0, 8'hA9, 8'h90};
                8'd54:  rom_entry = {1'b0, 8'hAA, 8'h94};
                8'd55:  rom_entry = {1'b0, 8'h13, 8'hEF};
                8'd56:  rom_entry = {1'b0, 8'h0E, 8'h61};
                8'd57:  rom_entry = {1'b0, 8'h0F, 8'h4B};
                8'd58:  rom_entry = {1'b0, 8'h16, 8'h02};

                // Windowing and scaling controls.
                8'd59:  rom_entry = {1'b0, 8'h21, 8'h02};
                8'd60:  rom_entry = {1'b0, 8'h22, 8'h91};
                8'd61:  rom_entry = {1'b0, 8'h29, 8'h07};
                8'd62:  rom_entry = {1'b0, 8'h33, 8'h0B};
                8'd63:  rom_entry = {1'b0, 8'h35, 8'h0B};
                8'd64:  rom_entry = {1'b0, 8'h37, 8'h1D};
                8'd65:  rom_entry = {1'b0, 8'h38, 8'h71};
                8'd66:  rom_entry = {1'b0, 8'h39, 8'h2A};
                8'd67:  rom_entry = {1'b0, 8'h3C, 8'h78};
                8'd68:  rom_entry = {1'b0, 8'h4D, 8'h40};
                8'd69:  rom_entry = {1'b0, 8'h4E, 8'h20};
                8'd70:  rom_entry = {1'b0, 8'h69, 8'h00};
                8'd71:  rom_entry = {1'b0, 8'h74, 8'h19};
                8'd72:  rom_entry = {1'b0, 8'h8D, 8'h4F};
                8'd73:  rom_entry = {1'b0, 8'h8E, 8'h00};
                8'd74:  rom_entry = {1'b0, 8'h8F, 8'h00};
                8'd75:  rom_entry = {1'b0, 8'h90, 8'h00};
                8'd76:  rom_entry = {1'b0, 8'h91, 8'h00};
                8'd77:  rom_entry = {1'b0, 8'h92, 8'h00};
                8'd78:  rom_entry = {1'b0, 8'h96, 8'h00};
                8'd79:  rom_entry = {1'b0, 8'h9A, 8'h80};
                8'd80:  rom_entry = {1'b0, 8'hB0, 8'h84};
                8'd81:  rom_entry = {1'b0, 8'hB1, 8'h0C};
                8'd82:  rom_entry = {1'b0, 8'hB2, 8'h0E};
                8'd83:  rom_entry = {1'b0, 8'hB3, 8'h82};
                8'd84:  rom_entry = {1'b0, 8'hB8, 8'h0A};

                // Matrix and saturation controls.
                8'd85:  rom_entry = {1'b0, 8'h43, 8'h14};
                8'd86:  rom_entry = {1'b0, 8'h44, 8'hF0};
                8'd87:  rom_entry = {1'b0, 8'h45, 8'h34};
                8'd88:  rom_entry = {1'b0, 8'h46, 8'h58};
                8'd89:  rom_entry = {1'b0, 8'h47, 8'h28};
                8'd90:  rom_entry = {1'b0, 8'h48, 8'h3A};
                8'd91:  rom_entry = {1'b0, 8'h59, 8'h88};
                8'd92:  rom_entry = {1'b0, 8'h5A, 8'h88};
                8'd93:  rom_entry = {1'b0, 8'h5B, 8'h44};
                8'd94:  rom_entry = {1'b0, 8'h5C, 8'h67};
                8'd95:  rom_entry = {1'b0, 8'h5D, 8'h49};
                8'd96:  rom_entry = {1'b0, 8'h5E, 8'h0E};
                8'd97:  rom_entry = {1'b0, 8'h64, 8'h04};
                8'd98:  rom_entry = {1'b0, 8'h65, 8'h20};
                8'd99:  rom_entry = {1'b0, 8'h66, 8'h05};
                8'd100: rom_entry = {1'b0, 8'h94, 8'h04};
                8'd101: rom_entry = {1'b0, 8'h95, 8'h08};
                8'd102: rom_entry = {1'b0, 8'h6C, 8'h0A};
                8'd103: rom_entry = {1'b0, 8'h6D, 8'h55};
                8'd104: rom_entry = {1'b0, 8'h6E, 8'h11};
                8'd105: rom_entry = {1'b0, 8'h6F, 8'h9F};
                8'd106: rom_entry = {1'b0, 8'h6A, 8'h40};
                8'd107: rom_entry = {1'b0, 8'h01, 8'h40};
                8'd108: rom_entry = {1'b0, 8'h02, 8'h40};
                8'd109: rom_entry = {1'b0, 8'h13, 8'hE7};
                8'd110: rom_entry = {1'b0, 8'h15, 8'h00};

                // RGB matrix and control tuning.
                8'd111: rom_entry = {1'b0, 8'h4F, 8'h80};
                8'd112: rom_entry = {1'b0, 8'h50, 8'h80};
                8'd113: rom_entry = {1'b0, 8'h51, 8'h00};
                8'd114: rom_entry = {1'b0, 8'h52, 8'h22};
                8'd115: rom_entry = {1'b0, 8'h53, 8'h5E};
                8'd116: rom_entry = {1'b0, 8'h54, 8'h80};
                8'd117: rom_entry = {1'b0, 8'h58, 8'h9E};
                8'd118: rom_entry = {1'b0, 8'h41, 8'h08};
                8'd119: rom_entry = {1'b0, 8'h3F, 8'h00};
                8'd120: rom_entry = {1'b0, 8'h75, 8'h05};
                8'd121: rom_entry = {1'b0, 8'h76, 8'hE1};
                8'd122: rom_entry = {1'b0, 8'h4C, 8'h00};
                8'd123: rom_entry = {1'b0, 8'h77, 8'h01};
                8'd124: rom_entry = {1'b0, 8'h4B, 8'h09};
                8'd125: rom_entry = {1'b0, 8'hC9, 8'hF0};
                8'd126: rom_entry = {1'b0, 8'h41, 8'h38};
                8'd127: rom_entry = {1'b0, 8'h56, 8'h40};

                // Additional gain and edge tuning.
                8'd128: rom_entry = {1'b0, 8'h34, 8'h11};
                8'd129: rom_entry = {1'b0, 8'h3B, 8'h02};
                8'd130: rom_entry = {1'b0, 8'hA4, 8'h89};
                8'd131: rom_entry = {1'b0, 8'h96, 8'h00};
                8'd132: rom_entry = {1'b0, 8'h97, 8'h30};
                8'd133: rom_entry = {1'b0, 8'h98, 8'h20};
                8'd134: rom_entry = {1'b0, 8'h99, 8'h30};
                8'd135: rom_entry = {1'b0, 8'h9A, 8'h84};
                8'd136: rom_entry = {1'b0, 8'h9B, 8'h29};
                8'd137: rom_entry = {1'b0, 8'h9C, 8'h03};
                8'd138: rom_entry = {1'b0, 8'h9D, 8'h4C};
                8'd139: rom_entry = {1'b0, 8'h9E, 8'h3F};
                8'd140: rom_entry = {1'b0, 8'h78, 8'h04};

                // DSP control sequence from the proven reference design.
                8'd141: rom_entry = {1'b0, 8'h79, 8'h01};
                8'd142: rom_entry = {1'b0, 8'hC8, 8'hF0};
                8'd143: rom_entry = {1'b0, 8'h79, 8'h0F};
                8'd144: rom_entry = {1'b0, 8'hC8, 8'h00};
                8'd145: rom_entry = {1'b0, 8'h79, 8'h10};
                8'd146: rom_entry = {1'b0, 8'hC8, 8'h7E};
                8'd147: rom_entry = {1'b0, 8'h79, 8'h0A};
                8'd148: rom_entry = {1'b0, 8'hC8, 8'h80};
                8'd149: rom_entry = {1'b0, 8'h79, 8'h0B};
                8'd150: rom_entry = {1'b0, 8'hC8, 8'h01};
                8'd151: rom_entry = {1'b0, 8'h79, 8'h0C};
                8'd152: rom_entry = {1'b0, 8'hC8, 8'h0F};
                8'd153: rom_entry = {1'b0, 8'h79, 8'h0D};
                8'd154: rom_entry = {1'b0, 8'hC8, 8'h20};
                8'd155: rom_entry = {1'b0, 8'h79, 8'h09};
                8'd156: rom_entry = {1'b0, 8'hC8, 8'h80};
                8'd157: rom_entry = {1'b0, 8'h79, 8'h02};
                8'd158: rom_entry = {1'b0, 8'hC8, 8'hC0};
                8'd159: rom_entry = {1'b0, 8'h79, 8'h03};
                8'd160: rom_entry = {1'b0, 8'hC8, 8'h40};
                8'd161: rom_entry = {1'b0, 8'h79, 8'h05};
                8'd162: rom_entry = {1'b0, 8'hC8, 8'h30};
                8'd163: rom_entry = {1'b0, 8'h79, 8'h26};
                8'd164: rom_entry = {1'b0, 8'h09, 8'h03};
                8'd165: rom_entry = {1'b0, 8'h3B, 8'h42};

                // Keep the sensor's internal test pattern enabled for debug.
                8'd166: rom_entry = {1'b1, 8'h42, 8'hF0};

                default: rom_entry = {1'b1, 8'h42, 8'hF0};
            endcase
        end
    endfunction

    wire [16:0] selected_entry = rom_entry(index);

    assign is_last  = selected_entry[16];
    assign reg_addr = selected_entry[15:8];
    assign reg_data = selected_entry[7:0];

endmodule
