# Clean Vivado build for the full-resolution stream experiment.
# Run from repo root or by passing this file to Vivado:
#   vivado -mode batch -source scripts/vivado/build_stream_clean.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir .. ..]]
set build_dir  [file normalize [file join $repo_root tmp vivado_stream_clean]]
set proj_name  ov7670_vga_stream_clean
set top_name   top_basys3_ov7670_vga_stream
set part_name  xc7a35tcpg236-1

puts "Repo root: $repo_root"
puts "Build dir: $build_dir"

file delete -force $build_dir
file mkdir $build_dir

create_project $proj_name $build_dir -part $part_name -force
set_property target_language Verilog [current_project]

proc collect_verilog {dir} {
    set result {}
    foreach path [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $path]} {
            set result [concat $result [collect_verilog $path]]
        } elseif {[string match *.v $path] || [string match *.sv $path]} {
            lappend result [file normalize $path]
        }
    }
    return $result
}

set rtl_files [lsort [collect_verilog [file join $repo_root rtl]]]
if {[llength $rtl_files] == 0} {
    error "No RTL files found under $repo_root/rtl"
}

foreach rtl_file $rtl_files {
    puts "RTL: $rtl_file"
}

add_files -fileset sources_1 -norecurse $rtl_files
add_files -fileset constrs_1 -norecurse [file join $repo_root constr basys3_ov7670_vga.xdc]
set_property top $top_name [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "Checking that stale MMCM probe instances are absent from current RTL..."
foreach bad_pattern {u_bufg_49p95074 clk49p95074 u_mmcm_49p95074 BUFGMUX MMCME2_BASE} {
    set matches {}
    foreach rtl_file $rtl_files {
        set fh [open $rtl_file r]
        set text [read $fh]
        close $fh
        if {[string first $bad_pattern $text] >= 0} {
            lappend matches $rtl_file
        }
    }
    if {[llength $matches] > 0} {
        error "Found stale pattern '$bad_pattern' in: $matches"
    }
}

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 did not complete successfully: [get_property STATUS [get_runs synth_1]]"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 did not complete successfully: [get_property STATUS [get_runs impl_1]]"
}

set bit_file [file join $build_dir $proj_name.runs impl_1 "${top_name}.bit"]
puts "Clean stream build complete."
puts "Bitstream: $bit_file"
