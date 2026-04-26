`timescale 1ns / 1ps

module tb_crypto_axi;
    reg clk = 1'b0;
    reg rst_n = 1'b0;

    reg         awvalid;
    wire        awready;
    reg [31:0]  awaddr;
    reg         wvalid;
    wire        wready;
    reg [31:0]  wdata;
    reg [3:0]   wstrb;
    wire        bvalid;
    reg         bready;
    reg         arvalid;
    wire        arready;
    reg [31:0]  araddr;
    wire        rvalid;
    reg         rready;
    wire [31:0] rdata;

    reg [31:0] status_word;
    reg [127:0] aes_result;
    reg [255:0] sha_result;
    reg [511:0] cha_result;
    integer i;

    localparam BASE = 32'h0000_0000;
    localparam REG_CTRL = BASE + 32'h00;
    localparam REG_STATUS = BASE + 32'h04;
    localparam REG_ALGO = BASE + 32'h08;
    localparam REG_BUF = BASE + 32'h10;

    always #5 clk = ~clk;

    crypto_coprocessor_axi dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_awaddr(awaddr),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_araddr(araddr),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .s_axi_rdata(rdata)
    );

    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            awaddr <= addr;
            wdata <= data;
            wstrb <= 4'hf;
            awvalid <= 1'b1;
            wvalid <= 1'b1;
            bready <= 1'b1;
            wait (awready && wready);
            @(posedge clk);
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            wait (bvalid);
            @(posedge clk);
            bready <= 1'b0;
        end
    endtask

    task axi_read;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            araddr <= addr;
            arvalid <= 1'b1;
            rready <= 1'b1;
            wait (arready);
            @(posedge clk);
            arvalid <= 1'b0;
            wait (rvalid);
            data = rdata;
            @(posedge clk);
            rready <= 1'b0;
        end
    endtask

    task wait_done;
        begin
            status_word = 32'd0;
            while (status_word[1] == 1'b0) begin
                axi_read(REG_STATUS, status_word);
            end
        end
    endtask

    initial begin
        awvalid = 0;
        awaddr = 0;
        wvalid = 0;
        wdata = 0;
        wstrb = 0;
        bready = 0;
        arvalid = 0;
        araddr = 0;
        rready = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // AES-128 Known Answer Test
        axi_write(REG_BUF + 32'h00, 32'hccddeeff);
        axi_write(REG_BUF + 32'h04, 32'h8899aabb);
        axi_write(REG_BUF + 32'h08, 32'h44556677);
        axi_write(REG_BUF + 32'h0c, 32'h00112233);
        axi_write(REG_BUF + 32'h10, 32'h0c0d0e0f);
        axi_write(REG_BUF + 32'h14, 32'h08090a0b);
        axi_write(REG_BUF + 32'h18, 32'h04050607);
        axi_write(REG_BUF + 32'h1c, 32'h00010203);
        axi_write(REG_ALGO, 32'd0);
        axi_write(REG_CTRL, 32'd1);
        wait_done;
        for (i = 0; i < 4; i = i + 1)
            axi_read(REG_BUF + 32'h50 + i*4, aes_result[i*32 +: 32]);
        if (aes_result !== 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("AES mismatch: %h", aes_result);
            $fatal(1);
        end

        axi_write(REG_STATUS, 32'h0000_0002);

        // SHA-256("abc") padded single block
        axi_write(REG_BUF + 32'h00, 32'h61626380);
        for (i = 1; i < 15; i = i + 1)
            axi_write(REG_BUF + i*4, 32'h00000000);
        axi_write(REG_BUF + 32'h3c, 32'h00000018);
        axi_write(REG_ALGO, 32'd1);
        axi_write(REG_CTRL, 32'd1);
        wait_done;
        for (i = 0; i < 8; i = i + 1)
            axi_read(REG_BUF + 32'h60 + i*4, sha_result[i*32 +: 32]);
        if (sha_result !== 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad) begin
            $display("SHA mismatch: %h", sha_result);
            $fatal(1);
        end

        axi_write(REG_STATUS, 32'h0000_0002);

        // ChaCha20 RFC8439 block test
        axi_write(REG_BUF + 32'h20, 32'h03020100);
        axi_write(REG_BUF + 32'h24, 32'h07060504);
        axi_write(REG_BUF + 32'h28, 32'h0b0a0908);
        axi_write(REG_BUF + 32'h2c, 32'h0f0e0d0c);
        axi_write(REG_BUF + 32'h30, 32'h13121110);
        axi_write(REG_BUF + 32'h34, 32'h17161514);
        axi_write(REG_BUF + 32'h38, 32'h1b1a1918);
        axi_write(REG_BUF + 32'h3c, 32'h1f1e1d1c);
        axi_write(REG_BUF + 32'h40, 32'h00000001);
        axi_write(REG_BUF + 32'h44, 32'h09000000);
        axi_write(REG_BUF + 32'h48, 32'h4a000000);
        axi_write(REG_BUF + 32'h4c, 32'h00000000);
        axi_write(REG_ALGO, 32'd2);
        axi_write(REG_CTRL, 32'd1);
        wait_done;
        for (i = 0; i < 16; i = i + 1)
            axi_read(REG_BUF + i*4, cha_result[i*32 +: 32]);
        if (cha_result !== 512'h4e3c50a2e883d0cbb94e16ded19c12b5a2028bd905d7c21409aa9f07466482d24e6cd4c39aaa22040368c033c7f4d1c7c47120a31fdd0f5015593bd1e4e7f110) begin
            $display("ChaCha mismatch: %h", cha_result);
            $fatal(1);
        end

        $display("All crypto AXI tests passed.");
        $finish;
    end
endmodule
