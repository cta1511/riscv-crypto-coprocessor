`timescale 1ns / 1ps

module axi_lite_rom #(
    parameter MEM_WORDS = 256,
    parameter INIT_FILE = "firmware/boot_rom.hex"
) (
    input wire        clk,
    input wire        rst_n,
    input wire        s_axi_awvalid,
    output wire       s_axi_awready,
    input wire [31:0] s_axi_awaddr,
    input wire        s_axi_wvalid,
    output wire       s_axi_wready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    output reg        s_axi_bvalid,
    input wire        s_axi_bready,
    input wire        s_axi_arvalid,
    output wire       s_axi_arready,
    input wire [31:0] s_axi_araddr,
    output reg        s_axi_rvalid,
    input wire        s_axi_rready,
    output reg [31:0] s_axi_rdata
);
    reg [31:0] mem [0:MEM_WORDS-1];
    integer i;
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'h00000013;
        $readmemh(INIT_FILE, mem);
    end

    assign s_axi_awready = !s_axi_bvalid;
    assign s_axi_wready  = !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'd0;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && s_axi_awready)
                s_axi_bvalid <= 1'b1;
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata <= mem[s_axi_araddr[31:2] % MEM_WORDS];
                s_axi_rvalid <= 1'b1;
            end
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end
endmodule

module axi_lite_ram #(
    parameter MEM_WORDS = 1024
) (
    input wire        clk,
    input wire        rst_n,
    input wire        s_axi_awvalid,
    output wire       s_axi_awready,
    input wire [31:0] s_axi_awaddr,
    input wire        s_axi_wvalid,
    output wire       s_axi_wready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    output reg        s_axi_bvalid,
    input wire        s_axi_bready,
    input wire        s_axi_arvalid,
    output wire       s_axi_arready,
    input wire [31:0] s_axi_araddr,
    output reg        s_axi_rvalid,
    input wire        s_axi_rready,
    output reg [31:0] s_axi_rdata,
    output wire [31:0] debug_word0,
    output wire [31:0] debug_word1,
    output wire [31:0] debug_word2,
    output wire [31:0] debug_word3
);
    reg [31:0] mem [0:MEM_WORDS-1];
    integer i;
    reg [31:0] wr_data;
    integer idx;

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'd0;
    end

    assign s_axi_awready = !s_axi_bvalid;
    assign s_axi_wready  = !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;
    assign debug_word0 = mem[0];
    assign debug_word1 = mem[1];
    assign debug_word2 = mem[2];
    assign debug_word3 = mem[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'd0;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && s_axi_awready) begin
                idx = s_axi_awaddr[31:2] % MEM_WORDS;
                wr_data = mem[idx];
                if (s_axi_wstrb[0]) wr_data[7:0]   = s_axi_wdata[7:0];
                if (s_axi_wstrb[1]) wr_data[15:8]  = s_axi_wdata[15:8];
                if (s_axi_wstrb[2]) wr_data[23:16] = s_axi_wdata[23:16];
                if (s_axi_wstrb[3]) wr_data[31:24] = s_axi_wdata[31:24];
                mem[idx] <= wr_data;
                s_axi_bvalid <= 1'b1;
            end
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata <= mem[s_axi_araddr[31:2] % MEM_WORDS];
                s_axi_rvalid <= 1'b1;
            end
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end
endmodule
