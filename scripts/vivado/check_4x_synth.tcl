set origin_dir [file normalize [file join [file dirname [info script]] ../..]]

read_verilog [glob -nocomplain [file join $origin_dir rtl clock *.v]]
read_verilog [glob -nocomplain [file join $origin_dir rtl clocking *.v]]
read_verilog [glob -nocomplain [file join $origin_dir rtl util *.v]]
read_verilog [glob -nocomplain [file join $origin_dir rtl vga *.v]]
read_verilog [glob -nocomplain [file join $origin_dir rtl filters *.v]]
read_verilog [glob -nocomplain [file join $origin_dir rtl memory *.v]]
read_verilog [glob -nocomplain [file join $origin_dir rtl camera *.v]]
read_verilog [file join $origin_dir rtl top top_basys3_ov7670_vga.v]
read_xdc [file join $origin_dir constr basys3_ov7670_vga.xdc]

synth_design -top top_basys3_ov7670_vga -part xc7a35tcpg236-1

file mkdir [file join $origin_dir reports timing]
report_utilization -hierarchical -hierarchical_depth 6 \
    -file [file join $origin_dir reports timing util_hier_4x_synth.rpt]
report_timing_summary -delay_type max -max_paths 20 \
    -file [file join $origin_dir reports timing timing_summary_4x_synth.rpt]
