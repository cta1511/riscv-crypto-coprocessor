set proj_dir [file normalize [file dirname [info script]]/..]
set out_dir [file normalize "$proj_dir/build/pynq_z2"]

file mkdir $out_dir
cd $proj_dir

create_project -force pynq_z2_soc $out_dir -part xc7z020clg400-1

add_files rtl/vendor/picorv32.v
add_files rtl/aes128_core.v
add_files rtl/sha256_core.v
add_files rtl/chacha20_core.v
add_files rtl/crypto_coprocessor_axi.v
add_files rtl/axi_lite_mem.v
add_files rtl/axi_lite_crossbar.v
add_files rtl/riscv_crypto_soc.v
add_files rtl/pynq_z2_top.v
add_files -fileset constrs_1 constraints/pynq_z2.xdc

set_property top pynq_z2_top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1
report_timing_summary -file $out_dir/timing_summary.rpt
report_utilization -file $out_dir/utilization.rpt

set bitfile [get_property BITSTREAM.FILE [current_design]]
puts "BITSTREAM: $bitfile"
quit
