# RISC-V SoC with Crypto Coprocessor

This project implements a small RISC-V SoC with an AXI4-Lite crypto coprocessor, built from the block diagram in RTL.

- `rtl/riscv_crypto_soc.v`: top-level SoC using `picorv32_axi`
- `rtl/pynq_z2_top.v`: PYNQ-Z2 board-specific top-level wrapper
- `rtl/crypto_coprocessor_axi.v`: AXI4-Lite slave, register file, and control FSM
- `rtl/aes128_core.v`: AES-128 block encryption
- `rtl/sha256_core.v`: SHA-256 single 512-bit block compression
- `rtl/chacha20_core.v`: ChaCha20 block function generating a 64-byte keystream
- `rtl/axi_lite_mem.v`: ROM/RAM AXI-Lite
- `rtl/axi_lite_crossbar.v`: 1-master / 3-slave AXI-Lite interconnect
- `tb/tb_crypto_axi.v`: simulation testbench with standard crypto test vectors
- `tb/tb_soc_firmware.v`: end-to-end testbench with PicoRV32 running firmware
- `sim/vivado_run.tcl`: Vivado xsim simulation script
- `sim/vivado_build_pynq_z2.tcl`: Vivado bitstream build script for PYNQ-Z2
- `constraints/pynq_z2.xdc`: pin constraints for clock, buttons, switches, LEDs, and Pmod JB

## Address map

- `0x0000_0000` - `0x0FFF_FFFF`: Instruction ROM
- `0x1000_0000` - `0x1FFF_FFFF`: Data RAM
- `0x2000_0000` - `0x2000_FFFF`: Crypto coprocessor

## Crypto MMIO map

- `0x00`: `CTRL`
  - bit `0`: `START`
- `0x04`: `STATUS`
  - bit `0`: `BUSY`
  - bit `1`: `DONE`
  - bit `2`: `ERROR`
- `0x08`: `ALGO_SEL`
  - `0`: AES-128
  - `1`: SHA-256
  - `2`: ChaCha20
- `0x10` ... `0x8C`: `BUF[0]` ... `BUF[31]`

## Buffer convention

- AES input:
  - plaintext: `BUF[0]..BUF[3]`
  - key: `BUF[4]..BUF[7]`
  - result: `BUF[20]..BUF[23]`
- SHA-256 input:
  - message block 512-bit: `BUF[0]..BUF[15]`
  - digest: `BUF[24]..BUF[31]`
- ChaCha20 input:
  - key: `BUF[8]..BUF[15]`
  - counter: `BUF[16]`
  - nonce: `BUF[17]..BUF[19]`
  - keystream: overwrites `BUF[0]..BUF[15]`

## Running simulation in Vivado

From the repository root:

```bash
vivado -mode batch -source sim/vivado_run.tcl
```

## Building for PYNQ-Z2

Target board:

- FPGA part: `xc7z020clg400-1`
- PL clock: `125 MHz` on pin `H16`

Build bitstream:

```bash
vivado -mode batch -source sim/vivado_build_pynq_z2.tcl
```

After the build completes, the bitstream and reports are written to:

- `build/pynq_z2/`

### Board mapping

- `BTN[0]`: reset the SoC
- `SW[0] = 0`: LEDs show `heartbeat/reset/trap/AXI activity`
- `SW[0] = 1`: LEDs show the `firmware passmask`
- `JB[0..7]`: debug signals for logic analyzer or oscilloscope probing

Notes:

- The USB-UART port on the PYNQ-Z2 is connected through the Zynq PS MIO pins, not directly to PL logic. For that reason, this target does not expose a PL UART on the micro-USB connector.
- If a PL-side UART is needed, route it through Pmod JB/JA or move to an architecture that uses the Zynq PS.

The default Vivado testbench runs an end-to-end simulation with PicoRV32 executing firmware from ROM.

Current tests:

- AES-128 known answer test
- SHA-256 for the string `"abc"`
- ChaCha20 RFC8439 block test
- PicoRV32 writes MMIO registers, polls `DONE`, verifies the results, and writes `PASS/FAIL` status to RAM

## Notes

- `firmware/boot_rom.hex` is a minimal ROM image used so the SoC top can elaborate; the main verification flow focuses on the crypto coprocessor through AXI-Lite.
- Firmware is written in `firmware/program.S` and built with `firmware/miniasm.py`, so no external RISC-V toolchain is required.
- RAM debug words:
  - `0x1000_0000`: magic value `0x600d0001` on pass, `0xdead000X` on fail
  - `0x1000_0004`: bitmask pass (`bit0=AES`, `bit1=SHA`, `bit2=ChaCha`)
  - `0x1000_0008`: current stage
  - `0x1000_000C`: last mismatched word on failure
