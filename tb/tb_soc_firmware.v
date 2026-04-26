`timescale 1ns / 1ps

module tb_soc_firmware;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire trap_o;
    wire axi_read_o;
    wire axi_write_o;
    wire [31:0] fw_magic_o;
    wire [31:0] fw_passmask_o;
    wire [31:0] fw_stage_o;
    wire [31:0] fw_detail_o;

    always #5 clk = ~clk;

    riscv_crypto_soc dut (
        .clk(clk),
        .rst_n(rst_n),
        .trap_o(trap_o),
        .axi_read_o(axi_read_o),
        .axi_write_o(axi_write_o),
        .fw_magic_o(fw_magic_o),
        .fw_passmask_o(fw_passmask_o),
        .fw_stage_o(fw_stage_o),
        .fw_detail_o(fw_detail_o)
    );

    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        repeat (20000) begin
            @(posedge clk);
            if (fw_magic_o == 32'h600d0001) begin
                if (fw_passmask_o !== 32'h0000_0007) begin
                    $display("Firmware passmask mismatch: %h", fw_passmask_o);
                    $fatal(1);
                end
                if (trap_o !== 1'b0) begin
                    $display("Unexpected trap during firmware run");
                    $fatal(1);
                end
                $display("Firmware end-to-end test passed. magic=%h passmask=%h", fw_magic_o, fw_passmask_o);
                $finish;
            end
            if (fw_magic_o[31:16] == 16'hdead) begin
                $display("Firmware failure. magic=%h passmask=%h stage=%h detail=%h", fw_magic_o, fw_passmask_o, fw_stage_o, fw_detail_o);
                $display("crypto: busy=%0d done=%0d algo=%h ctrl=%h status=%h buf20=%h",
                    dut.u_crypto.op_busy, dut.u_crypto.op_done, dut.u_crypto.algo_sel_reg,
                    dut.u_crypto.ctrl_reg, {29'd0, dut.u_crypto.op_error, dut.u_crypto.op_done, dut.u_crypto.op_busy},
                    dut.u_crypto.buf_reg[20]);
                $fatal(1);
            end
        end

        $display("Firmware timeout. magic=%h passmask=%h stage=%h detail=%h", fw_magic_o, fw_passmask_o, fw_stage_o, fw_detail_o);
        $display("crypto: busy=%0d done=%0d algo=%h ctrl=%h status=%h aw=%0d w=%0d b=%0d ar=%0d r=%0d",
            dut.u_crypto.op_busy, dut.u_crypto.op_done, dut.u_crypto.algo_sel_reg, dut.u_crypto.ctrl_reg,
            {29'd0, dut.u_crypto.op_error, dut.u_crypto.op_done, dut.u_crypto.op_busy},
            dut.cry_awvalid, dut.cry_wvalid, dut.cry_bvalid, dut.cry_arvalid, dut.cry_rvalid);
        $display("buf0=%h buf4=%h buf20=%h aes_busy=%0d aes_done=%0d",
            dut.u_crypto.buf_reg[0], dut.u_crypto.buf_reg[4], dut.u_crypto.buf_reg[20],
            dut.u_crypto.aes_busy, dut.u_crypto.aes_done);
        $fatal(1);
    end
endmodule
