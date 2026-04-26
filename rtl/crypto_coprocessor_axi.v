`timescale 1ns / 1ps

module crypto_coprocessor_axi (
    input wire         clk,
    input wire         rst_n,
    input wire         s_axi_awvalid,
    output wire        s_axi_awready,
    input wire [31:0]  s_axi_awaddr,
    input wire         s_axi_wvalid,
    output wire        s_axi_wready,
    input wire [31:0]  s_axi_wdata,
    input wire [3:0]   s_axi_wstrb,
    output reg         s_axi_bvalid,
    input wire         s_axi_bready,
    input wire         s_axi_arvalid,
    output wire        s_axi_arready,
    input wire [31:0]  s_axi_araddr,
    output reg         s_axi_rvalid,
    input wire         s_axi_rready,
    output reg [31:0]  s_axi_rdata
);
    localparam REG_CTRL     = 32'h0000_0000;
    localparam REG_STATUS   = 32'h0000_0004;
    localparam REG_ALGO_SEL = 32'h0000_0008;
    localparam REG_BUF_BASE = 32'h0000_0010;

    localparam ALGO_AES     = 2'd0;
    localparam ALGO_SHA256  = 2'd1;
    localparam ALGO_CHACHA  = 2'd2;

    reg [31:0] ctrl_reg;
    reg [31:0] algo_sel_reg;
    reg [31:0] buf_reg [0:31];
    reg [31:0] awaddr_hold;
    reg [31:0] araddr_hold;
    reg [31:0] wdata_hold;
    reg [3:0]  wstrb_hold;
    reg        aw_pending;
    reg        w_pending;
    reg        op_busy;
    reg        op_done;
    reg        op_error;
    reg        aes_start;
    reg        sha_start;
    reg        cha_start;
    integer    i;

    wire [127:0] aes_plaintext = {buf_reg[3], buf_reg[2], buf_reg[1], buf_reg[0]};
    wire [127:0] aes_key       = {buf_reg[7], buf_reg[6], buf_reg[5], buf_reg[4]};
    wire [511:0] sha_block     = {buf_reg[0], buf_reg[1], buf_reg[2], buf_reg[3], buf_reg[4], buf_reg[5], buf_reg[6], buf_reg[7],
                                  buf_reg[8], buf_reg[9], buf_reg[10], buf_reg[11], buf_reg[12], buf_reg[13], buf_reg[14], buf_reg[15]};
    wire [255:0] cha_key       = {buf_reg[15], buf_reg[14], buf_reg[13], buf_reg[12], buf_reg[11], buf_reg[10], buf_reg[9], buf_reg[8]};
    wire [31:0]  cha_counter   = buf_reg[16];
    wire [95:0]  cha_nonce     = {buf_reg[19], buf_reg[18], buf_reg[17]};

    wire aes_busy;
    wire aes_done;
    wire [127:0] aes_ciphertext;
    wire sha_busy;
    wire sha_done;
    wire [255:0] sha_digest;
    wire cha_busy;
    wire cha_done;
    wire [511:0] cha_keystream;

    assign s_axi_awready = !aw_pending;
    assign s_axi_wready  = !w_pending;
    assign s_axi_arready = !s_axi_rvalid;

    aes128_core u_aes (
        .clk(clk),
        .rst_n(rst_n),
        .start(aes_start),
        .plaintext(aes_plaintext),
        .key(aes_key),
        .busy(aes_busy),
        .done(aes_done),
        .ciphertext(aes_ciphertext)
    );

    sha256_core u_sha256 (
        .clk(clk),
        .rst_n(rst_n),
        .start(sha_start),
        .block(sha_block),
        .busy(sha_busy),
        .done(sha_done),
        .digest(sha_digest)
    );

    chacha20_core u_chacha20 (
        .clk(clk),
        .rst_n(rst_n),
        .start(cha_start),
        .key(cha_key),
        .counter(cha_counter),
        .nonce(cha_nonce),
        .busy(cha_busy),
        .done(cha_done),
        .keystream(cha_keystream)
    );

    function [31:0] read_reg;
        input [31:0] addr;
        integer idx;
        begin
            if (addr == REG_CTRL)
                read_reg = ctrl_reg;
            else if (addr == REG_STATUS)
                read_reg = {29'd0, op_error, op_done, op_busy};
            else if (addr == REG_ALGO_SEL)
                read_reg = algo_sel_reg;
            else if ((addr >= REG_BUF_BASE) && (addr < (REG_BUF_BASE + 32*4))) begin
                idx = (addr - REG_BUF_BASE) >> 2;
                read_reg = buf_reg[idx];
            end else
                read_reg = 32'hdead_beef;
        end
    endfunction

    task write_reg;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer idx;
        reg [31:0] merged;
        begin
            if (addr == REG_CTRL) begin
                merged = ctrl_reg;
                if (strb[0]) merged[7:0]   = data[7:0];
                if (strb[1]) merged[15:8]  = data[15:8];
                if (strb[2]) merged[23:16] = data[23:16];
                if (strb[3]) merged[31:24] = data[31:24];
                ctrl_reg <= merged & 32'hffff_fffe;
                if (data[0] && !op_busy) begin
                    op_done <= 1'b0;
                    op_error <= 1'b0;
                    case (algo_sel_reg[1:0])
                        ALGO_AES:    aes_start <= 1'b1;
                        ALGO_SHA256: sha_start <= 1'b1;
                        ALGO_CHACHA: cha_start <= 1'b1;
                        default: begin
                            op_error <= 1'b1;
                            op_busy <= 1'b0;
                        end
                    endcase
                    if (algo_sel_reg[1:0] <= ALGO_CHACHA)
                        op_busy <= 1'b1;
                end
            end else if (addr == REG_STATUS) begin
                if (data[1]) op_done <= 1'b0;
                if (data[2]) op_error <= 1'b0;
            end else if (addr == REG_ALGO_SEL) begin
                algo_sel_reg <= data;
            end else if ((addr >= REG_BUF_BASE) && (addr < (REG_BUF_BASE + 32*4))) begin
                idx = (addr - REG_BUF_BASE) >> 2;
                merged = buf_reg[idx];
                if (strb[0]) merged[7:0]   = data[7:0];
                if (strb[1]) merged[15:8]  = data[15:8];
                if (strb[2]) merged[23:16] = data[23:16];
                if (strb[3]) merged[31:24] = data[31:24];
                buf_reg[idx] <= merged;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= 32'd0;
            algo_sel_reg <= 32'd0;
            awaddr_hold <= 32'd0;
            araddr_hold <= 32'd0;
            wdata_hold <= 32'd0;
            wstrb_hold <= 4'd0;
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'd0;
            op_busy <= 1'b0;
            op_done <= 1'b0;
            op_error <= 1'b0;
            aes_start <= 1'b0;
            sha_start <= 1'b0;
            cha_start <= 1'b0;
            for (i = 0; i < 32; i = i + 1)
                buf_reg[i] <= 32'd0;
        end else begin
            aes_start <= 1'b0;
            sha_start <= 1'b0;
            cha_start <= 1'b0;

            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_hold <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                wdata_hold <= s_axi_wdata;
                wstrb_hold <= s_axi_wstrb;
                w_pending <= 1'b1;
            end
            if (aw_pending && w_pending && !s_axi_bvalid) begin
                write_reg(awaddr_hold[7:0], wdata_hold, wstrb_hold);
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                s_axi_bvalid <= 1'b1;
            end
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                araddr_hold <= s_axi_araddr;
                s_axi_rdata <= read_reg(s_axi_araddr[7:0]);
                s_axi_rvalid <= 1'b1;
            end
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

            if (aes_done) begin
                buf_reg[20] <= aes_ciphertext[31:0];
                buf_reg[21] <= aes_ciphertext[63:32];
                buf_reg[22] <= aes_ciphertext[95:64];
                buf_reg[23] <= aes_ciphertext[127:96];
                op_busy <= 1'b0;
                op_done <= 1'b1;
            end
            if (sha_done) begin
                buf_reg[24] <= sha_digest[31:0];
                buf_reg[25] <= sha_digest[63:32];
                buf_reg[26] <= sha_digest[95:64];
                buf_reg[27] <= sha_digest[127:96];
                buf_reg[28] <= sha_digest[159:128];
                buf_reg[29] <= sha_digest[191:160];
                buf_reg[30] <= sha_digest[223:192];
                buf_reg[31] <= sha_digest[255:224];
                op_busy <= 1'b0;
                op_done <= 1'b1;
            end
            if (cha_done) begin
                for (i = 0; i < 16; i = i + 1)
                    buf_reg[i] <= cha_keystream[i*32 +: 32];
                op_busy <= 1'b0;
                op_done <= 1'b1;
            end
        end
    end
endmodule
