start:
    li x2, 0x10001000
    li x3, 0x10000000
    li x4, 0x20000000

    li x5, 0x0000c0de
    sw x5, 0(x3)
    addi x20, x0, 0
    sw x20, 4(x3)
    sw x20, 8(x3)
    sw x20, 12(x3)

stage_aes:
    li x5, 1
    sw x5, 8(x3)
    li x5, 0xccddeeff
    sw x5, 0x10(x4)
    li x5, 0x8899aabb
    sw x5, 0x14(x4)
    li x5, 0x44556677
    sw x5, 0x18(x4)
    li x5, 0x00112233
    sw x5, 0x1c(x4)
    li x5, 0x0c0d0e0f
    sw x5, 0x20(x4)
    li x5, 0x08090a0b
    sw x5, 0x24(x4)
    li x5, 0x04050607
    sw x5, 0x28(x4)
    li x5, 0x00010203
    sw x5, 0x2c(x4)
    addi x5, x0, 0
    sw x5, 0x08(x4)
    addi x5, x0, 1
    sw x5, 0x00(x4)

wait_aes_done:
    lw x6, 0x04(x4)
    andi x6, x6, 2
    beq x6, x0, wait_aes_done

    lw x6, 0x60(x4)
    li x7, 0x70b4c55a
    bne x6, x7, aes_fail
    lw x6, 0x64(x4)
    li x7, 0xd8cdb780
    bne x6, x7, aes_fail
    lw x6, 0x68(x4)
    li x7, 0x6a7b0430
    bne x6, x7, aes_fail
    lw x6, 0x6c(x4)
    li x7, 0x69c4e0d8
    bne x6, x7, aes_fail
    ori x20, x20, 1
    beq x0, x0, aes_done

aes_fail:
    sw x6, 12(x3)

aes_done:
    li x5, 2
    sw x5, 0x04(x4)
    sw x20, 4(x3)

stage_sha:
    li x5, 2
    sw x5, 8(x3)
    li x5, 0x61626380
    sw x5, 0x10(x4)
    addi x5, x0, 0
    sw x5, 0x14(x4)
    sw x5, 0x18(x4)
    sw x5, 0x1c(x4)
    sw x5, 0x20(x4)
    sw x5, 0x24(x4)
    sw x5, 0x28(x4)
    sw x5, 0x2c(x4)
    sw x5, 0x30(x4)
    sw x5, 0x34(x4)
    sw x5, 0x38(x4)
    sw x5, 0x3c(x4)
    sw x5, 0x40(x4)
    sw x5, 0x44(x4)
    sw x5, 0x48(x4)
    li x5, 0x00000018
    sw x5, 0x4c(x4)
    addi x5, x0, 1
    sw x5, 0x08(x4)
    addi x5, x0, 1
    sw x5, 0x00(x4)

wait_sha_done:
    lw x6, 0x04(x4)
    andi x6, x6, 2
    beq x6, x0, wait_sha_done

    lw x6, 0x70(x4)
    li x7, 0xf20015ad
    bne x6, x7, sha_fail
    lw x6, 0x74(x4)
    li x7, 0xb410ff61
    bne x6, x7, sha_fail
    lw x6, 0x78(x4)
    li x7, 0x96177a9c
    bne x6, x7, sha_fail
    lw x6, 0x7c(x4)
    li x7, 0xb00361a3
    bne x6, x7, sha_fail
    lw x6, 0x80(x4)
    li x7, 0x5dae2223
    bne x6, x7, sha_fail
    lw x6, 0x84(x4)
    li x7, 0x414140de
    bne x6, x7, sha_fail
    lw x6, 0x88(x4)
    li x7, 0x8f01cfea
    bne x6, x7, sha_fail
    lw x6, 0x8c(x4)
    li x7, 0xba7816bf
    bne x6, x7, sha_fail
    ori x20, x20, 2
    beq x0, x0, sha_done

sha_fail:
    sw x6, 12(x3)

sha_done:
    li x5, 2
    sw x5, 0x04(x4)
    sw x20, 4(x3)

stage_chacha:
    li x5, 3
    sw x5, 8(x3)
    li x5, 0x03020100
    sw x5, 0x30(x4)
    li x5, 0x07060504
    sw x5, 0x34(x4)
    li x5, 0x0b0a0908
    sw x5, 0x38(x4)
    li x5, 0x0f0e0d0c
    sw x5, 0x3c(x4)
    li x5, 0x13121110
    sw x5, 0x40(x4)
    li x5, 0x17161514
    sw x5, 0x44(x4)
    li x5, 0x1b1a1918
    sw x5, 0x48(x4)
    li x5, 0x1f1e1d1c
    sw x5, 0x4c(x4)
    li x5, 0x00000001
    sw x5, 0x50(x4)
    li x5, 0x09000000
    sw x5, 0x54(x4)
    li x5, 0x4a000000
    sw x5, 0x58(x4)
    addi x5, x0, 0
    sw x5, 0x5c(x4)
    addi x5, x0, 2
    sw x5, 0x08(x4)
    addi x5, x0, 1
    sw x5, 0x00(x4)

wait_chacha_done:
    lw x6, 0x04(x4)
    andi x6, x6, 2
    beq x6, x0, wait_chacha_done

    lw x6, 0x10(x4)
    li x7, 0xe4e7f110
    bne x6, x7, chacha_fail
    lw x6, 0x14(x4)
    li x7, 0x15593bd1
    bne x6, x7, chacha_fail
    lw x6, 0x18(x4)
    li x7, 0x1fdd0f50
    bne x6, x7, chacha_fail
    lw x6, 0x1c(x4)
    li x7, 0xc47120a3
    bne x6, x7, chacha_fail
    lw x6, 0x20(x4)
    li x7, 0xc7f4d1c7
    bne x6, x7, chacha_fail
    lw x6, 0x24(x4)
    li x7, 0x0368c033
    bne x6, x7, chacha_fail
    lw x6, 0x28(x4)
    li x7, 0x9aaa2204
    bne x6, x7, chacha_fail
    lw x6, 0x2c(x4)
    li x7, 0x4e6cd4c3
    bne x6, x7, chacha_fail
    lw x6, 0x30(x4)
    li x7, 0x466482d2
    bne x6, x7, chacha_fail
    lw x6, 0x34(x4)
    li x7, 0x09aa9f07
    bne x6, x7, chacha_fail
    lw x6, 0x38(x4)
    li x7, 0x05d7c214
    bne x6, x7, chacha_fail
    lw x6, 0x3c(x4)
    li x7, 0xa2028bd9
    bne x6, x7, chacha_fail
    lw x6, 0x40(x4)
    li x7, 0xd19c12b5
    bne x6, x7, chacha_fail
    lw x6, 0x44(x4)
    li x7, 0xb94e16de
    bne x6, x7, chacha_fail
    lw x6, 0x48(x4)
    li x7, 0xe883d0cb
    bne x6, x7, chacha_fail
    lw x6, 0x4c(x4)
    li x7, 0x4e3c50a2
    bne x6, x7, chacha_fail
    ori x20, x20, 4
    beq x0, x0, chacha_done

chacha_fail:
    sw x6, 12(x3)

chacha_done:
    li x5, 2
    sw x5, 0x04(x4)
    sw x20, 4(x3)

final_check:
    li x5, 7
    bne x20, x5, firmware_fail
    li x5, 0x600d0001
    sw x5, 0(x3)
    beq x0, x0, firmware_done

firmware_fail:
    li x5, 0xdead0000
    add x5, x5, x20
    sw x5, 0(x3)

firmware_done:
    sw x20, 4(x3)
    sw x0, 8(x3)
    beq x0, x0, firmware_done
