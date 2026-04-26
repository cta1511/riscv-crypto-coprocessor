set proj_dir [file normalize [file dirname [info script]]/..]
cd $proj_dir

read_verilog rtl/vendor/picorv32.v
read_verilog rtl/aes128_core.v
read_verilog rtl/sha256_core.v
read_verilog rtl/chacha20_core.v
read_verilog rtl/crypto_coprocessor_axi.v
read_verilog rtl/axi_lite_mem.v
read_verilog rtl/axi_lite_crossbar.v
read_verilog rtl/riscv_crypto_soc.v
read_verilog tb/tb_crypto_axi.v
read_verilog tb/tb_soc_firmware.v

set_property top tb_soc_firmware [current_fileset]
launch_simulation
run all
quit
