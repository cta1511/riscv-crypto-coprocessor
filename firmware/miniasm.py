#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


REG_ALIASES = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15, "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23, "s8": 24, "s9": 25,
    "s10": 26, "s11": 27, "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}


def reg_num(name: str) -> int:
    name = name.strip()
    if re.fullmatch(r"x([0-9]|[12][0-9]|3[01])", name):
        return int(name[1:])
    if name in REG_ALIASES:
        return REG_ALIASES[name]
    raise ValueError(f"Unknown register: {name}")


def parse_imm(token: str) -> int:
    return int(token, 0)


def parse_mem(token: str):
    m = re.fullmatch(r"(.+)\(([^)]+)\)", token.replace(" ", ""))
    if not m:
        raise ValueError(f"Bad memory operand: {token}")
    return parse_imm(m.group(1)), reg_num(m.group(2))


def enc_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7f) << 25) | ((rs2 & 0x1f) << 20) | ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


def enc_i(imm, rs1, funct3, rd, opcode):
    imm &= 0xfff
    return (imm << 20) | ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


def enc_s(imm, rs2, rs1, funct3, opcode):
    imm &= 0xfff
    imm115 = (imm >> 5) & 0x7f
    imm40 = imm & 0x1f
    return (imm115 << 25) | ((rs2 & 0x1f) << 20) | ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | (imm40 << 7) | (opcode & 0x7f)


def enc_b(imm, rs2, rs1, funct3, opcode):
    imm &= 0x1fff
    b12 = (imm >> 12) & 0x1
    b105 = (imm >> 5) & 0x3f
    b41 = (imm >> 1) & 0xf
    b11 = (imm >> 11) & 0x1
    return (b12 << 31) | (b105 << 25) | ((rs2 & 0x1f) << 20) | ((rs1 & 0x1f) << 15) | ((funct3 & 0x7) << 12) | (b41 << 8) | (b11 << 7) | (opcode & 0x7f)


def enc_u(imm, rd, opcode):
    return (imm & 0xfffff000) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


def enc_j(imm, rd, opcode):
    imm &= 0x1fffff
    j20 = (imm >> 20) & 0x1
    j101 = (imm >> 1) & 0x3ff
    j11 = (imm >> 11) & 0x1
    j1912 = (imm >> 12) & 0xff
    return (j20 << 31) | (j1912 << 12) | (j11 << 20) | (j101 << 21) | ((rd & 0x1f) << 7) | (opcode & 0x7f)


def split_imm32(value):
    upper = (value + 0x800) >> 12
    lower = value - (upper << 12)
    return upper << 12, lower


def tokenize(line):
    return [t for t in re.split(r"[\s,]+", line.strip()) if t]


def expand_line(text):
    toks = tokenize(text)
    if not toks:
        return []
    op = toks[0]
    if op == "li":
        rd = toks[1]
        imm = parse_imm(toks[2])
        if -2048 <= imm <= 2047:
            return [f"addi {rd}, x0, {imm}"]
        upper, lower = split_imm32(imm)
        return [f"lui {rd}, {upper}", f"addi {rd}, {rd}, {lower}"]
    if op == "mv":
        return [f"addi {toks[1]}, {toks[2]}, 0"]
    if op == "j":
        return [f"jal x0, {toks[1]}"]
    if op == "call":
        return [f"jal x1, {toks[1]}"]
    if op == "ret":
        return ["jalr x0, 0(x1)"]
    if op == "beqz":
        return [f"beq {toks[1]}, x0, {toks[2]}"]
    if op == "bnez":
        return [f"bne {toks[1]}, x0, {toks[2]}"]
    return [text.strip()]


def assemble_instruction(text, pc, labels):
    toks = tokenize(text)
    op = toks[0]
    if op == "lui":
        return enc_u(parse_imm(toks[2]), reg_num(toks[1]), 0x37)
    if op == "addi":
        return enc_i(parse_imm(toks[3]), reg_num(toks[2]), 0x0, reg_num(toks[1]), 0x13)
    if op == "andi":
        return enc_i(parse_imm(toks[3]), reg_num(toks[2]), 0x7, reg_num(toks[1]), 0x13)
    if op == "ori":
        return enc_i(parse_imm(toks[3]), reg_num(toks[2]), 0x6, reg_num(toks[1]), 0x13)
    if op == "add":
        return enc_r(0x00, reg_num(toks[3]), reg_num(toks[2]), 0x0, reg_num(toks[1]), 0x33)
    if op == "lw":
        imm, rs1 = parse_mem(toks[2])
        return enc_i(imm, rs1, 0x2, reg_num(toks[1]), 0x03)
    if op == "sw":
        imm, rs1 = parse_mem(toks[2])
        return enc_s(imm, reg_num(toks[1]), rs1, 0x2, 0x23)
    if op in ("beq", "bne"):
        target = labels[toks[3]]
        imm = target - pc
        funct3 = 0x0 if op == "beq" else 0x1
        return enc_b(imm, reg_num(toks[2]), reg_num(toks[1]), funct3, 0x63)
    if op == "jal":
        target = labels[toks[2]]
        imm = target - pc
        return enc_j(imm, reg_num(toks[1]), 0x6f)
    if op == "jalr":
        imm, rs1 = parse_mem(toks[2])
        return enc_i(imm, rs1, 0x0, reg_num(toks[1]), 0x67)
    raise ValueError(f"Unsupported instruction: {text}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--words", type=int, default=256)
    args = ap.parse_args()

    source = Path(args.source).read_text().splitlines()
    labels = {}
    expanded = []
    pc = 0

    for raw in source:
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.endswith(":"):
            labels[line[:-1]] = pc
            continue
        for item in expand_line(line):
            expanded.append((pc, item))
            pc += 4

    words = []
    for pc, text in expanded:
        words.append(assemble_instruction(text, pc, labels))

    while len(words) < args.words:
        words.append(0x00000013)

    out = Path(args.output)
    out.write_text("".join(f"{w:08x}\n" for w in words[:args.words]))


if __name__ == "__main__":
    main()
