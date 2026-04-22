## basys3_ov7670_vga.xdc
## TASK-007 raw OV7670 camera-to-VGA integration constraints for Basys 3.

## =========================================================
## Clock
## =========================================================
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk_100]
create_clock -add -name clk_100_pin -period 10.00 -waveform {0 5} [get_ports clk_100]

## =========================================================
## Reset button
## =========================================================
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btnC]

## =========================================================
## Debug LEDs
## =========================================================
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## =========================================================
## Switches for TASK-003 filter control
## =========================================================
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
# set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
# set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
# set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
# set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
# set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
# set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
# set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
# set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
# set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
# set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## =========================================================
## VGA Connector
## =========================================================
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports {vgaRed[0]}]
set_property -dict { PACKAGE_PIN H19 IOSTANDARD LVCMOS33 } [get_ports {vgaRed[1]}]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports {vgaRed[2]}]
set_property -dict { PACKAGE_PIN N19 IOSTANDARD LVCMOS33 } [get_ports {vgaRed[3]}]

set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[0]}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[1]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[2]}]
set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[3]}]

set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[0]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[1]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[2]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[3]}]

set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 } [get_ports Hsync]
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports Vsync]

## =========================================================
## OV7670 Camera Connector
## =========================================================
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {cam_d[0]}]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {cam_d[1]}]
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports {cam_d[2]}]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {cam_d[3]}]
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports {cam_d[4]}]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {cam_d[5]}]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports {cam_d[6]}]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports {cam_d[7]}]

set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports cam_href]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports cam_vsync]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports cam_pclk]
create_clock -add -name cam_pclk_pin -period 40.000 -waveform {0 20.000} [get_ports cam_pclk]

set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports cam_xclk]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports cam_pwdn]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports cam_reset]

set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports cam_sioc]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports cam_siod]
set_property PULLUP true [get_ports cam_siod]

set_clock_groups -asynchronous \
    -group [get_clocks clk_100_pin] \
    -group [get_clocks cam_pclk_pin]

## =========================================================
## Configuration options
## =========================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
