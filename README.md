# RISC-V SoC with Crypto Coprocessor

Project này dựng từ đầu theo block diagram:

- `rtl/riscv_crypto_soc.v`: top-level SoC dùng `picorv32_axi`
- `rtl/pynq_z2_top.v`: wrapper target riêng cho board PYNQ-Z2
- `rtl/crypto_coprocessor_axi.v`: AXI4-Lite slave + register file + FSM điều khiển
- `rtl/aes128_core.v`: AES-128 block encryption
- `rtl/sha256_core.v`: SHA-256 cho 1 block 512-bit
- `rtl/chacha20_core.v`: ChaCha20 block function 64-byte keystream
- `rtl/axi_lite_mem.v`: ROM/RAM AXI-Lite
- `rtl/axi_lite_crossbar.v`: interconnect 1 master / 3 slave
- `tb/tb_crypto_axi.v`: testbench mô phỏng và kiểm tra vector chuẩn
- `tb/tb_soc_firmware.v`: testbench end-to-end với CPU PicoRV32 chạy firmware thật
- `sim/vivado_run.tcl`: script chạy xsim trong Vivado
- `sim/vivado_build_pynq_z2.tcl`: script build bitstream cho PYNQ-Z2
- `constraints/pynq_z2.xdc`: pin constraints cho clock/buttons/switches/LED/Pmod JB

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
  - keystream: ghi đè `BUF[0]..BUF[15]`

## Chạy mô phỏng trên Vivado

Từ terminal:

```bash
cd "/Users/caothanhan/Documents/New project"
vivado -mode batch -source sim/vivado_run.tcl
```

## Build cho PYNQ-Z2

Target board:

- FPGA part: `xc7z020clg400-1`
- PL clock: `125 MHz` tại pin `H16`

Build bitstream:

```bash
cd "/Users/caothanhan/Documents/New project"
vivado -mode batch -source sim/vivado_build_pynq_z2.tcl
```

Sau khi chạy xong, bitstream và report sẽ nằm trong:

- `build/pynq_z2/`

### Mapping trên board

- `BTN[0]`: reset SoC
- `SW[0] = 0`: LED hiển thị `heartbeat/reset/trap/AXI activity`
- `SW[0] = 1`: LED hiển thị `firmware passmask`
- `JB[0..7]`: xuất tín hiệu debug để đo bằng LA/scope

Lưu ý:

- Cổng USB-UART trên PYNQ-Z2 đi qua Zynq PS MIO, không nối trực tiếp với logic PL. Vì vậy bản target hiện tại không giả lập PL UART ra microUSB để tránh constraint sai.
- Nếu cần UART cho logic PL, nên route ra Pmod JB/JA hoặc chuyển sang kiến trúc có Zynq PS.

Testbench Vivado mặc định hiện chạy end-to-end với PicoRV32 executing firmware trong ROM.

Các bài kiểm tra hiện có:

- AES-128 known answer test
- SHA-256 cho chuỗi `"abc"`
- ChaCha20 RFC8439 block test
- CPU PicoRV32 tự ghi MMIO, poll `DONE`, verify kết quả và ghi trạng thái `PASS/FAIL` vào RAM

## Ghi chú

- `firmware/boot_rom.hex` chỉ là ROM tối thiểu để SoC top có thể elaborate; verify chính đang tập trung vào crypto coprocessor qua AXI-Lite.
- Firmware hiện được viết ở `firmware/program.S` và build bằng `firmware/miniasm.py`, nên không phụ thuộc toolchain RISC-V ngoài.
- RAM debug words:
  - `0x1000_0000`: magic `0x600d0001` khi pass, `0xdead000X` khi fail
  - `0x1000_0004`: bitmask pass (`bit0=AES`, `bit1=SHA`, `bit2=ChaCha`)
  - `0x1000_0008`: stage hiện tại
  - `0x1000_000C`: word mismatch cuối cùng nếu fail
