`timescale 1ns/1ps

// ov7670_reg_rom
//
// Purpose:
//   Provide the fixed OV7670 startup register table used by the RGB565/QVGA
//   bring-up profiles.
//
// Clock domain:
//   None; this is a purely combinational lookup table.
//
// Inputs:
//   index   - register-table entry selector
//   profile - camera profile selector sampled by the top-level reset path
//
// Outputs:
//   reg_addr - OV7670 register address for the selected entry
//   reg_data - data byte for the selected entry
//   is_last  - asserted on the final table entry
//
// Assumption:
//   Invalid indices safely alias to the final valid entry.
//
// Profile map:
// - 0000: live auto, normal speed
// - 0001: live low-noise, normal speed
// - 0010: live low-noise, lower-speed diagnostic
// - 0011: internal color bars for camera-path debug
// - 0100: live auto plus averaged-QVGA scaler/DCW experiment
// - 1000: full-VGA sensor output plus FPGA 2x2 average, 8-pixel horizontal shift
// - 1001: full-VGA sensor output plus FPGA 2x2 average, 16-pixel horizontal shift
// - 1010: full-VGA sensor output plus FPGA 2x2 average, 8-pixel horizontal shift
// - 1011: full-VGA sensor output plus FPGA 2x2 average, reference horizontal window
//
// Register comments use common OV7670 names where they are known. Entries
// marked as reference tuning or reserved are kept from the hardware-tested
// reference table; change those one at a time and retest on hardware.
module ov7670_reg_rom (
    input  wire [7:0] index,
    input  wire [3:0] profile,
    output wire [7:0] reg_addr,
    output wire [7:0] reg_data,
    output wire       is_last
);

    function [16:0] rom_entry;
        input [7:0] entry_index;
        begin
            // Entry format is {is_last, reg_addr[7:0], reg_data[7:0]}.
            rom_entry = {1'b1, 8'h42, profile_com17(profile)}; // Default/fallback: final COM17 profile entry.

            case (entry_index)
                // Reset and core format selection.
                8'd0:   rom_entry = {1'b0, 8'h12, 8'h80}; // COM7: soft reset.
                8'd1:   rom_entry = {1'b0, 8'h12, profile_com7(profile)}; // COM7: RGB output; full-average profile disables QVGA mode.
                8'd2:   rom_entry = {1'b0, 8'h40, 8'hD0}; // COM15: RGB565 / RGB output range control.
                8'd3:   rom_entry = {1'b0, 8'h3A, 8'h04}; // TSLB: output byte/order timing control.
                8'd4:   rom_entry = {1'b0, 8'h3D, 8'hC8}; // COM13: gamma/UV/color processing control.
                8'd5:   rom_entry = {1'b0, 8'h1E, 8'h31}; // MVFP: mirror/flip and image orientation bits.
                8'd6:   rom_entry = {1'b0, 8'h6B, 8'h00}; // DBLV: PLL/internal clock multiplier control.
                8'd7:   rom_entry = {1'b0, 8'h32, profile_href(profile)}; // HREF: horizontal window low-bit packing.
                8'd8:   rom_entry = {1'b0, 8'h17, profile_hstart(profile)}; // HSTART: horizontal start high bits.
                8'd9:   rom_entry = {1'b0, 8'h18, profile_hstop(profile)}; // HSTOP: horizontal stop high bits.
                8'd10:  rom_entry = {1'b0, 8'h19, profile_vstart(profile)}; // VSTART: vertical start high bits.
                8'd11:  rom_entry = {1'b0, 8'h1A, profile_vstop(profile)}; // VSTOP: vertical stop high bits.
                8'd12:  rom_entry = {1'b0, 8'h03, profile_vref(profile)}; // VREF: vertical window low-bit packing.
                8'd13:  rom_entry = {1'b0, 8'h0C, profile_com3(profile)}; // COM3: scaling/DCW feature control; profile 0100 enables DCW.
                8'd14:  rom_entry = {1'b0, 8'h3E, profile_com14(profile)}; // COM14: PCLK/scaling divider control; profile 0100 uses scaled PCLK.
                8'd15:  rom_entry = {1'b0, 8'h70, profile_scaling_xsc(profile)}; // SCALING_XSC: horizontal scaling/test-pattern control.
                8'd16:  rom_entry = {1'b0, 8'h71, profile_scaling_ysc(profile)}; // SCALING_YSC: vertical scaling/test-pattern control.
                8'd17:  rom_entry = {1'b0, 8'h72, profile_scaling_dcwctr(profile)}; // SCALING_DCWCTR: profile 0100 tests averaged 2x QVGA downsampling.
                8'd18:  rom_entry = {1'b0, 8'h73, profile_scaling_pclk_div(profile)}; // SCALING_PCLK_DIV: profile 0100 matches scaled QVGA timing.
                8'd19:  rom_entry = {1'b0, 8'hA2, profile_scaling_pclk_delay(profile)}; // SCALING_PCLK_DELAY: scaled PCLK delay tuning.
                8'd20:  rom_entry = {1'b0, 8'h11, 8'h80}; // CLKRC: internal clock prescale; profile override later.

                // Gamma and automatic control defaults.
                8'd21:  rom_entry = {1'b0, 8'h7A, 8'h20}; // GAM1: gamma curve point 1.
                8'd22:  rom_entry = {1'b0, 8'h7B, 8'h1C}; // GAM2: gamma curve point 2.
                8'd23:  rom_entry = {1'b0, 8'h7C, 8'h28}; // GAM3: gamma curve point 3.
                8'd24:  rom_entry = {1'b0, 8'h7D, 8'h3C}; // GAM4: gamma curve point 4.
                8'd25:  rom_entry = {1'b0, 8'h7E, 8'h55}; // GAM5: gamma curve point 5.
                8'd26:  rom_entry = {1'b0, 8'h7F, 8'h68}; // GAM6: gamma curve point 6.
                8'd27:  rom_entry = {1'b0, 8'h80, 8'h76}; // GAM7: gamma curve point 7.
                8'd28:  rom_entry = {1'b0, 8'h81, 8'h80}; // GAM8: gamma curve point 8.
                8'd29:  rom_entry = {1'b0, 8'h82, 8'h88}; // GAM9: gamma curve point 9.
                8'd30:  rom_entry = {1'b0, 8'h83, 8'h8F}; // GAM10: gamma curve point 10.
                8'd31:  rom_entry = {1'b0, 8'h84, 8'h96}; // GAM11: gamma curve point 11.
                8'd32:  rom_entry = {1'b0, 8'h85, 8'hA3}; // GAM12: gamma curve point 12.
                8'd33:  rom_entry = {1'b0, 8'h86, 8'hAF}; // GAM13: gamma curve point 13.
                8'd34:  rom_entry = {1'b0, 8'h87, 8'hC4}; // GAM14: gamma curve point 14.
                8'd35:  rom_entry = {1'b0, 8'h88, 8'hD7}; // GAM15: gamma curve point 15.
                8'd36:  rom_entry = {1'b0, 8'h89, 8'hE8}; // GAM16: gamma curve point 16.
                8'd37:  rom_entry = {1'b0, 8'h13, 8'hE0}; // COM8: temporarily disable some auto controls during setup.
                8'd38:  rom_entry = {1'b0, 8'h00, 8'h00}; // GAIN: manual/initial analog gain.
                8'd39:  rom_entry = {1'b0, 8'h10, 8'h00}; // AECH: manual/initial exposure high bits.
                8'd40:  rom_entry = {1'b0, 8'h0D, 8'h00}; // COM4: window/exposure reference tuning.
                8'd41:  rom_entry = {1'b0, 8'h14, 8'h28}; // COM9: maximum automatic gain limit; affects noise.
                8'd42:  rom_entry = {1'b0, 8'hA5, 8'h05}; // BD50MAX: 50 Hz banding filter upper limit.
                8'd43:  rom_entry = {1'b0, 8'hAB, 8'h07}; // BD60MAX: 60 Hz banding filter upper limit.
                8'd44:  rom_entry = {1'b0, 8'h24, 8'h75}; // AEW: upper auto-exposure stable-zone threshold.
                8'd45:  rom_entry = {1'b0, 8'h25, 8'h63}; // AEB: lower auto-exposure stable-zone threshold.
                8'd46:  rom_entry = {1'b0, 8'h26, 8'hA5}; // VPT: fast auto-exposure adjustment threshold.
                8'd47:  rom_entry = {1'b0, 8'h9F, 8'h78}; // HAECC1: histogram auto-exposure tuning.
                8'd48:  rom_entry = {1'b0, 8'hA0, 8'h68}; // HAECC2: histogram auto-exposure tuning.
                8'd49:  rom_entry = {1'b0, 8'hA1, 8'h03}; // HAECC3/reserved: reference auto-exposure tuning.
                8'd50:  rom_entry = {1'b0, 8'hA6, 8'hDF}; // HAECC4: histogram auto-exposure tuning.
                8'd51:  rom_entry = {1'b0, 8'hA7, 8'hDF}; // HAECC5: histogram auto-exposure tuning.
                8'd52:  rom_entry = {1'b0, 8'hA8, 8'hF0}; // HAECC6: histogram auto-exposure tuning.
                8'd53:  rom_entry = {1'b0, 8'hA9, 8'h90}; // HAECC7: histogram auto-exposure tuning.
                8'd54:  rom_entry = {1'b0, 8'hAA, 8'h94}; // HAECC8/reference: histogram auto-exposure tuning.
                8'd55:  rom_entry = {1'b0, 8'h13, 8'hEF}; // COM8: re-enable auto gain/exposure/white-balance controls.
                8'd56:  rom_entry = {1'b0, 8'h0E, 8'h61}; // COM5: reference timing/exposure control.
                8'd57:  rom_entry = {1'b0, 8'h0F, 8'h4B}; // COM6: reference timing/exposure control.
                8'd58:  rom_entry = {1'b0, 8'h16, 8'h02}; // Reference/reserved control; keep unless isolating color/noise.

                // Windowing and scaling controls.
                8'd59:  rom_entry = {1'b0, 8'h21, 8'h02}; // ADCCTR1: ADC/reference tuning from reference table.
                8'd60:  rom_entry = {1'b0, 8'h22, 8'h91}; // ADCCTR2: ADC/reference tuning from reference table.
                8'd61:  rom_entry = {1'b0, 8'h29, 8'h07}; // ADCCTR3: ADC/reference tuning from reference table.
                8'd62:  rom_entry = {1'b0, 8'h33, 8'h0B}; // CHLF: array/current reference tuning.
                8'd63:  rom_entry = {1'b0, 8'h35, 8'h0B}; // Reference/reserved ADC tuning.
                8'd64:  rom_entry = {1'b0, 8'h37, 8'h1D}; // ADC/control reference tuning.
                8'd65:  rom_entry = {1'b0, 8'h38, 8'h71}; // ACOM: ADC/common-mode reference tuning.
                8'd66:  rom_entry = {1'b0, 8'h39, 8'h2A}; // OFON: ADC offset/reference tuning.
                8'd67:  rom_entry = {1'b0, 8'h3C, 8'h78}; // COM12: HREF/timing reference control.
                8'd68:  rom_entry = {1'b0, 8'h4D, 8'h40}; // Reference/reserved clock or DSP tuning.
                8'd69:  rom_entry = {1'b0, 8'h4E, 8'h20}; // Reference/reserved clock or DSP tuning.
                8'd70:  rom_entry = {1'b0, 8'h69, 8'h00}; // GFIX: fixed gain/control tuning.
                8'd71:  rom_entry = {1'b0, 8'h74, 8'h19}; // REG74: digital gain/control tuning.
                8'd72:  rom_entry = {1'b0, 8'h8D, 8'h4F}; // Reference/reserved DSP tuning.
                8'd73:  rom_entry = {1'b0, 8'h8E, 8'h00}; // Reference/reserved DSP tuning.
                8'd74:  rom_entry = {1'b0, 8'h8F, 8'h00}; // Reference/reserved DSP tuning.
                8'd75:  rom_entry = {1'b0, 8'h90, 8'h00}; // Reference/reserved DSP tuning.
                8'd76:  rom_entry = {1'b0, 8'h91, 8'h00}; // Reference/reserved DSP tuning.
                8'd77:  rom_entry = {1'b0, 8'h92, 8'h00}; // Reference/reserved DSP tuning.
                8'd78:  rom_entry = {1'b0, 8'h96, 8'h00}; // Reference/reserved lens/DSP tuning.
                8'd79:  rom_entry = {1'b0, 8'h9A, 8'h80}; // Reference/reserved lens/DSP tuning.
                8'd80:  rom_entry = {1'b0, 8'hB0, 8'h84}; // RSVD/BLC: black-level calibration tuning.
                8'd81:  rom_entry = {1'b0, 8'hB1, 8'h0C}; // ABLC1: automatic black-level calibration tuning.
                8'd82:  rom_entry = {1'b0, 8'hB2, 8'h0E}; // Reference/reserved black-level tuning.
                8'd83:  rom_entry = {1'b0, 8'hB3, 8'h82}; // THL_ST: black-level threshold tuning; candidate for dark-noise experiments.
                8'd84:  rom_entry = {1'b0, 8'hB8, 8'h0A}; // Reference/reserved black-level tuning.

                // Matrix and saturation controls.
                8'd85:  rom_entry = {1'b0, 8'h43, 8'h14}; // AWB/control matrix tuning; affects color cast.
                8'd86:  rom_entry = {1'b0, 8'h44, 8'hF0}; // AWB/control matrix tuning; affects color cast.
                8'd87:  rom_entry = {1'b0, 8'h45, 8'h34}; // AWB/control matrix tuning; affects color cast.
                8'd88:  rom_entry = {1'b0, 8'h46, 8'h58}; // AWB/control matrix tuning; affects color cast.
                8'd89:  rom_entry = {1'b0, 8'h47, 8'h28}; // AWB/control matrix tuning; affects color cast.
                8'd90:  rom_entry = {1'b0, 8'h48, 8'h3A}; // AWB/control matrix tuning; affects color cast.
                8'd91:  rom_entry = {1'b0, 8'h59, 8'h88}; // Lens/color correction tuning.
                8'd92:  rom_entry = {1'b0, 8'h5A, 8'h88}; // Lens/color correction tuning.
                8'd93:  rom_entry = {1'b0, 8'h5B, 8'h44}; // Lens/color correction tuning.
                8'd94:  rom_entry = {1'b0, 8'h5C, 8'h67}; // Lens/color correction tuning.
                8'd95:  rom_entry = {1'b0, 8'h5D, 8'h49}; // Lens/color correction tuning.
                8'd96:  rom_entry = {1'b0, 8'h5E, 8'h0E}; // Lens/color correction tuning.
                8'd97:  rom_entry = {1'b0, 8'h64, 8'h04}; // LCC/reference color correction tuning.
                8'd98:  rom_entry = {1'b0, 8'h65, 8'h20}; // LCC/reference color correction tuning.
                8'd99:  rom_entry = {1'b0, 8'h66, 8'h05}; // LCC/reference color correction tuning.
                8'd100: rom_entry = {1'b0, 8'h94, 8'h04}; // Lens correction threshold/control tuning.
                8'd101: rom_entry = {1'b0, 8'h95, 8'h08}; // Lens correction threshold/control tuning.
                8'd102: rom_entry = {1'b0, 8'h6C, 8'h0A}; // AWBCTR/control: white-balance tuning.
                8'd103: rom_entry = {1'b0, 8'h6D, 8'h55}; // AWBCTR/control: white-balance tuning.
                8'd104: rom_entry = {1'b0, 8'h6E, 8'h11}; // AWBCTR/control: white-balance tuning.
                8'd105: rom_entry = {1'b0, 8'h6F, 8'h9F}; // AWBCTR/control: white-balance tuning.
                8'd106: rom_entry = {1'b0, 8'h6A, 8'h40}; // GGAIN: green gain reference.
                8'd107: rom_entry = {1'b0, 8'h01, 8'h40}; // BLUE: blue-channel gain reference.
                8'd108: rom_entry = {1'b0, 8'h02, 8'h40}; // RED: red-channel gain reference.
                8'd109: rom_entry = {1'b0, 8'h13, 8'hE7}; // COM8: auto controls after gain/color setup.
                8'd110: rom_entry = {1'b0, 8'h15, 8'h00}; // COM10: VSYNC/HREF/PCLK polarity and timing control.

                // RGB matrix and control tuning.
                8'd111: rom_entry = {1'b0, 8'h4F, 8'h80}; // MTX1: color conversion matrix coefficient.
                8'd112: rom_entry = {1'b0, 8'h50, 8'h80}; // MTX2: color conversion matrix coefficient.
                8'd113: rom_entry = {1'b0, 8'h51, 8'h00}; // MTX3: color conversion matrix coefficient.
                8'd114: rom_entry = {1'b0, 8'h52, 8'h22}; // MTX4: color conversion matrix coefficient.
                8'd115: rom_entry = {1'b0, 8'h53, 8'h5E}; // MTX5: color conversion matrix coefficient.
                8'd116: rom_entry = {1'b0, 8'h54, 8'h80}; // MTX6: color conversion matrix coefficient.
                8'd117: rom_entry = {1'b0, 8'h58, 8'h9E}; // MTXS: matrix sign/saturation control.
                8'd118: rom_entry = {1'b0, 8'h41, 8'h08}; // COM16: denoise/edge/AWB gain options; later override follows.
                8'd119: rom_entry = {1'b0, 8'h3F, 8'h00}; // EDGE: edge enhancement factor.
                8'd120: rom_entry = {1'b0, 8'h75, 8'h05}; // Reference/reserved DSP tuning.
                8'd121: rom_entry = {1'b0, 8'h76, 8'hE1}; // Reference/reserved DSP tuning.
                8'd122: rom_entry = {1'b0, 8'h4C, 8'h00}; // DNSTH: denoise threshold; profile override later.
                8'd123: rom_entry = {1'b0, 8'h77, 8'h01}; // Reference/reserved DSP tuning.
                8'd124: rom_entry = {1'b0, 8'h4B, 8'h09}; // REG4B: reference DSP/color tuning; candidate for UV-filter experiments.
                8'd125: rom_entry = {1'b0, 8'hC9, 8'hF0}; // SATCTR: saturation control.
                8'd126: rom_entry = {1'b0, 8'h41, 8'h38}; // COM16: final denoise/edge/AWB gain option mix.
                8'd127: rom_entry = {1'b0, 8'h56, 8'h40}; // CONTRAS: contrast control.

                // Additional gain and edge tuning.
                8'd128: rom_entry = {1'b0, 8'h34, 8'h11}; // ARBLM/reference: array black-level tuning.
                8'd129: rom_entry = {1'b0, 8'h3B, 8'h02}; // COM11: night-mode/banding behavior; later override follows.
                8'd130: rom_entry = {1'b0, 8'hA4, 8'h89}; // NT_CTRL: auto frame-rate/night-mode control.
                8'd131: rom_entry = {1'b0, 8'h96, 8'h00}; // Reference/reserved lens/DSP tuning.
                8'd132: rom_entry = {1'b0, 8'h97, 8'h30}; // Reference/reserved lens/DSP tuning.
                8'd133: rom_entry = {1'b0, 8'h98, 8'h20}; // Reference/reserved lens/DSP tuning.
                8'd134: rom_entry = {1'b0, 8'h99, 8'h30}; // Reference/reserved lens/DSP tuning.
                8'd135: rom_entry = {1'b0, 8'h9A, 8'h84}; // Reference/reserved lens/DSP tuning.
                8'd136: rom_entry = {1'b0, 8'h9B, 8'h29}; // Reference/reserved lens/DSP tuning.
                8'd137: rom_entry = {1'b0, 8'h9C, 8'h03}; // Reference/reserved lens/DSP tuning.
                8'd138: rom_entry = {1'b0, 8'h9D, 8'h4C}; // Reference/reserved lens/DSP tuning.
                8'd139: rom_entry = {1'b0, 8'h9E, 8'h3F}; // Reference/reserved lens/DSP tuning.
                8'd140: rom_entry = {1'b0, 8'h78, 8'h04}; // Reference/reserved DSP tuning.

                // DSP control sequence from the proven reference design.
                8'd141: rom_entry = {1'b0, 8'h79, 8'h01}; // DSP index select for following C8 data write.
                8'd142: rom_entry = {1'b0, 8'hC8, 8'hF0}; // DSP indexed data write; reference table value.
                8'd143: rom_entry = {1'b0, 8'h79, 8'h0F}; // DSP index select for following C8 data write.
                8'd144: rom_entry = {1'b0, 8'hC8, 8'h00}; // DSP indexed data write; reference table value.
                8'd145: rom_entry = {1'b0, 8'h79, 8'h10}; // DSP index select for following C8 data write.
                8'd146: rom_entry = {1'b0, 8'hC8, 8'h7E}; // DSP indexed data write; reference table value.
                8'd147: rom_entry = {1'b0, 8'h79, 8'h0A}; // DSP index select for following C8 data write.
                8'd148: rom_entry = {1'b0, 8'hC8, 8'h80}; // DSP indexed data write; reference table value.
                8'd149: rom_entry = {1'b0, 8'h79, 8'h0B}; // DSP index select for following C8 data write.
                8'd150: rom_entry = {1'b0, 8'hC8, 8'h01}; // DSP indexed data write; reference table value.
                8'd151: rom_entry = {1'b0, 8'h79, 8'h0C}; // DSP index select for following C8 data write.
                8'd152: rom_entry = {1'b0, 8'hC8, 8'h0F}; // DSP indexed data write; reference table value.
                8'd153: rom_entry = {1'b0, 8'h79, 8'h0D}; // DSP index select for following C8 data write.
                8'd154: rom_entry = {1'b0, 8'hC8, 8'h20}; // DSP indexed data write; reference table value.
                8'd155: rom_entry = {1'b0, 8'h79, 8'h09}; // DSP index select for following C8 data write.
                8'd156: rom_entry = {1'b0, 8'hC8, 8'h80}; // DSP indexed data write; reference table value.
                8'd157: rom_entry = {1'b0, 8'h79, 8'h02}; // DSP index select for following C8 data write.
                8'd158: rom_entry = {1'b0, 8'hC8, 8'hC0}; // DSP indexed data write; reference table value.
                8'd159: rom_entry = {1'b0, 8'h79, 8'h03}; // DSP index select for following C8 data write.
                8'd160: rom_entry = {1'b0, 8'hC8, 8'h40}; // DSP indexed data write; reference table value.
                8'd161: rom_entry = {1'b0, 8'h79, 8'h05}; // DSP index select for following C8 data write.
                8'd162: rom_entry = {1'b0, 8'hC8, 8'h30}; // DSP indexed data write; reference table value.
                8'd163: rom_entry = {1'b0, 8'h79, 8'h26}; // DSP index select; terminates/sets indexed DSP sequence.
                8'd164: rom_entry = {1'b0, 8'h09, 8'h03}; // COM2: output drive/current reference control.
                8'd165: rom_entry = {1'b0, 8'h3B, 8'h42}; // COM11: final banding/night-mode behavior.

                // Profile-specific final tuning. These entries are kept last so
                // hardware can compare live auto, low-noise, lower-speed,
                // averaged-scaler live auto, and
                // color-bar profiles without changing the known-good base table.
                8'd166: rom_entry = {1'b0, 8'h13, profile_com8(profile)};  // COM8 profile override: auto-control/noise behavior.
                8'd167: rom_entry = {1'b0, 8'h14, profile_com9(profile)};  // COM9 profile override: max AGC gain; lower usually less noisy.
                8'd168: rom_entry = {1'b0, 8'h24, profile_aew(profile)};   // AEW profile override: upper exposure threshold.
                8'd169: rom_entry = {1'b0, 8'h25, profile_aeb(profile)};   // AEB profile override: lower exposure threshold.
                8'd170: rom_entry = {1'b0, 8'h4C, profile_dnsth(profile)}; // DNSTH profile override: denoise threshold.
                8'd171: rom_entry = {1'b0, 8'h11, profile_clkrc(profile)}; // CLKRC profile override: camera internal clock speed.
                8'd172: rom_entry = {1'b1, 8'h42, profile_com17(profile)}; // COM17 final entry: live image or internal color bars.

                default: rom_entry = {1'b1, 8'h42, profile_com17(profile)}; // Safe alias to final COM17 profile entry.
            endcase
        end
    endfunction

    function [7:0] profile_com7;
        input [3:0] profile_value;
        begin
            if (profile_value[3]) begin
                profile_com7 = 8'h04; // Full VGA RGB output for FPGA-side 2x2 averaging.
            end else begin
                profile_com7 = 8'h14; // RGB output with QVGA-style camera output.
            end
        end
    endfunction

    function [7:0] profile_href;
        input [3:0] profile_value;
        begin
            if (profile_value[3]) begin
                case (profile_value[1:0])
                    2'b00,
                    2'b01,
                    2'b10,
                    2'b11: profile_href = 8'hB6; // Full-VGA averaged A/B: 8, 16, 8, or reference shift.
                endcase
            end else begin
                profile_href = 8'h89; // Tuned QVGA window shift for left-edge stripe.
            end
        end
    endfunction

    function [7:0] profile_hstart;
        input [3:0] profile_value;
        begin
            if (profile_value[3]) begin
                case (profile_value[1:0])
                    2'b00: profile_hstart = 8'h14; // Full-VGA averaged default: 8-pixel horizontal shift.
                    2'b01: profile_hstart = 8'h15; // Full-VGA averaged A/B: 16-pixel horizontal shift.
                    2'b10: profile_hstart = 8'h14; // Full-VGA averaged A/B: 8-pixel horizontal shift.
                    2'b11: profile_hstart = 8'h13; // Full-VGA averaged A/B: reference horizontal window.
                endcase
            end else begin
                profile_hstart = 8'h16; // Tuned QVGA horizontal start.
            end
        end
    endfunction

    function [7:0] profile_hstop;
        input [3:0] profile_value;
        begin
            if (profile_value[3]) begin
                case (profile_value[1:0])
                    2'b00: profile_hstop = 8'h02; // Full-VGA averaged default: 8-pixel horizontal shift.
                    2'b01: profile_hstop = 8'h03; // Full-VGA averaged A/B: 16-pixel horizontal shift.
                    2'b10: profile_hstop = 8'h02; // Full-VGA averaged A/B: 8-pixel horizontal shift.
                    2'b11: profile_hstop = 8'h01; // Full-VGA averaged A/B: reference horizontal window.
                endcase
            end else begin
                profile_hstop = 8'h04; // Tuned QVGA horizontal stop.
            end
        end
    endfunction

    function [7:0] profile_vstart;
        input [3:0] profile_value;
        begin
            profile_vstart = 8'h04; // Tuned vertical start; skips the bright top line.
        end
    endfunction

    function [7:0] profile_vstop;
        input [3:0] profile_value;
        begin
            profile_vstop = 8'h7C; // Tuned vertical stop.
        end
    endfunction

    function [7:0] profile_vref;
        input [3:0] profile_value;
        begin
            profile_vref = 8'h0A; // Known-good vertical low-bit packing.
        end
    endfunction

    function [7:0] profile_com3;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_com3 = 8'h04; // Averaged-QVGA experiment: enable DCW/scaling.
                default: profile_com3 = 8'h00; // Stable profiles keep prior geometry.
            endcase
        end
    endfunction

    function [7:0] profile_com14;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_com14 = 8'h19; // Averaged-QVGA experiment: scaled PCLK/manual scaling.
                default: profile_com14 = 8'h00;
            endcase
        end
    endfunction

    function [7:0] profile_scaling_xsc;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_scaling_xsc = 8'h3A; // Reference QVGA scaler value.
                default: profile_scaling_xsc = 8'h00;
            endcase
        end
    endfunction

    function [7:0] profile_scaling_ysc;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_scaling_ysc = 8'h35; // Reference QVGA scaler value.
                default: profile_scaling_ysc = 8'h00;
            endcase
        end
    endfunction

    function [7:0] profile_scaling_dcwctr;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_scaling_dcwctr = 8'hDD; // 2x H/V downsampling with rounding/averaging bits.
                default: profile_scaling_dcwctr = 8'h11; // Stable QVGA-like subsampling setting.
            endcase
        end
    endfunction

    function [7:0] profile_scaling_pclk_div;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_scaling_pclk_div = 8'hF1; // Reference QVGA scaled PCLK divider.
                default: profile_scaling_pclk_div = 8'h00;
            endcase
        end
    endfunction

    function [7:0] profile_scaling_pclk_delay;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0100: profile_scaling_pclk_delay = 8'h02;
                default: profile_scaling_pclk_delay = 8'h02;
            endcase
        end
    endfunction

    function [7:0] profile_com8;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0001,
                4'b0010: profile_com8 = 8'hA7; // AEC step limited, AGC/AWB/AEC on.
                default: profile_com8 = 8'hE7;
            endcase
        end
    endfunction

    function [7:0] profile_com9;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0001: profile_com9 = 8'h00; // Limit maximum AGC gain for the low-noise profile.
                4'b0010: profile_com9 = 8'h00; // 2x max AGC for slower diagnostic mode.
                default: profile_com9 = 8'h28;
            endcase
        end
    endfunction

    function [7:0] profile_aew;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0001: profile_aew = 8'h60;
                4'b0010: profile_aew = 8'h50;
                default: profile_aew = 8'h75;
            endcase
        end
    endfunction

    function [7:0] profile_aeb;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0001: profile_aeb = 8'h50;
                4'b0010: profile_aeb = 8'h40;
                default: profile_aeb = 8'h63;
            endcase
        end
    endfunction

    function [7:0] profile_dnsth;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0001,
                4'b0010: profile_dnsth = 8'h0C; // Raise denoise threshold for low-noise profiles.
                default: profile_dnsth = 8'h00;
            endcase
        end
    endfunction

    function [7:0] profile_clkrc;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0010: profile_clkrc = 8'h01; // Diagnostic: divide camera internal clock by 2.
                default: profile_clkrc = 8'h80;
            endcase
        end
    endfunction

    function [7:0] profile_com17;
        input [3:0] profile_value;
        begin
            case (profile_value)
                4'b0011: profile_com17 = 8'h08; // COM17_CBAR: internal color bars.
                default: profile_com17 = 8'h00; // Live image output.
            endcase
        end
    endfunction

    wire [16:0] selected_entry = rom_entry(index);

    assign is_last  = selected_entry[16];
    assign reg_addr = selected_entry[15:8];
    assign reg_data = selected_entry[7:0];

endmodule
