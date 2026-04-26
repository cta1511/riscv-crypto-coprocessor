`timescale 1ns / 1ps

module axi_lite_crossbar (
    input wire        clk,
    input wire        rst_n,
    input wire        m_awvalid,
    output wire       m_awready,
    input wire [31:0] m_awaddr,
    input wire [2:0]  m_awprot,
    input wire        m_wvalid,
    output wire       m_wready,
    input wire [31:0] m_wdata,
    input wire [3:0]  m_wstrb,
    output wire       m_bvalid,
    input wire        m_bready,
    input wire        m_arvalid,
    output wire       m_arready,
    input wire [31:0] m_araddr,
    input wire [2:0]  m_arprot,
    output wire       m_rvalid,
    input wire        m_rready,
    output wire [31:0] m_rdata,
    output wire       rom_awvalid,
    input wire        rom_awready,
    output wire [31:0] rom_awaddr,
    output wire       rom_wvalid,
    input wire        rom_wready,
    output wire [31:0] rom_wdata,
    output wire [3:0]  rom_wstrb,
    input wire        rom_bvalid,
    output wire       rom_bready,
    output wire       rom_arvalid,
    input wire        rom_arready,
    output wire [31:0] rom_araddr,
    input wire        rom_rvalid,
    output wire       rom_rready,
    input wire [31:0] rom_rdata,
    output wire       ram_awvalid,
    input wire        ram_awready,
    output wire [31:0] ram_awaddr,
    output wire       ram_wvalid,
    input wire        ram_wready,
    output wire [31:0] ram_wdata,
    output wire [3:0]  ram_wstrb,
    input wire        ram_bvalid,
    output wire       ram_bready,
    output wire       ram_arvalid,
    input wire        ram_arready,
    output wire [31:0] ram_araddr,
    input wire        ram_rvalid,
    output wire       ram_rready,
    input wire [31:0] ram_rdata,
    output wire       cry_awvalid,
    input wire        cry_awready,
    output wire [31:0] cry_awaddr,
    output wire       cry_wvalid,
    input wire        cry_wready,
    output wire [31:0] cry_wdata,
    output wire [3:0]  cry_wstrb,
    input wire        cry_bvalid,
    output wire       cry_bready,
    output wire       cry_arvalid,
    input wire        cry_arready,
    output wire [31:0] cry_araddr,
    input wire        cry_rvalid,
    output wire       cry_rready,
    input wire [31:0] cry_rdata
);
    localparam SEL_ROM = 2'd0;
    localparam SEL_RAM = 2'd1;
    localparam SEL_CRY = 2'd2;

    reg [1:0] wr_sel;
    reg [1:0] rd_sel;
    reg       wr_active;
    reg       rd_active;

    wire [1:0] aw_sel = (m_awaddr[31:28] == 4'h0) ? SEL_ROM :
                        (m_awaddr[31:28] == 4'h1) ? SEL_RAM : SEL_CRY;
    wire [1:0] ar_sel = (m_araddr[31:28] == 4'h0) ? SEL_ROM :
                        (m_araddr[31:28] == 4'h1) ? SEL_RAM : SEL_CRY;

    assign rom_awvalid = m_awvalid && (aw_sel == SEL_ROM) && !wr_active;
    assign ram_awvalid = m_awvalid && (aw_sel == SEL_RAM) && !wr_active;
    assign cry_awvalid = m_awvalid && (aw_sel == SEL_CRY) && !wr_active;
    assign rom_wvalid  = m_wvalid  && (aw_sel == SEL_ROM) && !wr_active;
    assign ram_wvalid  = m_wvalid  && (aw_sel == SEL_RAM) && !wr_active;
    assign cry_wvalid  = m_wvalid  && (aw_sel == SEL_CRY) && !wr_active;
    assign rom_awaddr = m_awaddr;
    assign ram_awaddr = m_awaddr - 32'h1000_0000;
    assign cry_awaddr = m_awaddr - 32'h2000_0000;
    assign rom_wdata = m_wdata;
    assign ram_wdata = m_wdata;
    assign cry_wdata = m_wdata;
    assign rom_wstrb = m_wstrb;
    assign ram_wstrb = m_wstrb;
    assign cry_wstrb = m_wstrb;
    assign m_awready = (aw_sel == SEL_ROM) ? rom_awready :
                       (aw_sel == SEL_RAM) ? ram_awready : cry_awready;
    assign m_wready  = (aw_sel == SEL_ROM) ? rom_wready :
                       (aw_sel == SEL_RAM) ? ram_wready : cry_wready;
    assign m_bvalid  = (wr_sel == SEL_ROM) ? rom_bvalid :
                       (wr_sel == SEL_RAM) ? ram_bvalid : cry_bvalid;
    assign rom_bready = m_bready && (wr_sel == SEL_ROM);
    assign ram_bready = m_bready && (wr_sel == SEL_RAM);
    assign cry_bready = m_bready && (wr_sel == SEL_CRY);

    assign rom_arvalid = m_arvalid && (ar_sel == SEL_ROM) && !rd_active;
    assign ram_arvalid = m_arvalid && (ar_sel == SEL_RAM) && !rd_active;
    assign cry_arvalid = m_arvalid && (ar_sel == SEL_CRY) && !rd_active;
    assign rom_araddr = m_araddr;
    assign ram_araddr = m_araddr - 32'h1000_0000;
    assign cry_araddr = m_araddr - 32'h2000_0000;
    assign m_arready = (ar_sel == SEL_ROM) ? rom_arready :
                       (ar_sel == SEL_RAM) ? ram_arready : cry_arready;
    assign m_rvalid = (rd_sel == SEL_ROM) ? rom_rvalid :
                      (rd_sel == SEL_RAM) ? ram_rvalid : cry_rvalid;
    assign m_rdata  = (rd_sel == SEL_ROM) ? rom_rdata :
                      (rd_sel == SEL_RAM) ? ram_rdata : cry_rdata;
    assign rom_rready = m_rready && (rd_sel == SEL_ROM);
    assign ram_rready = m_rready && (rd_sel == SEL_RAM);
    assign cry_rready = m_rready && (rd_sel == SEL_CRY);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_sel <= SEL_ROM;
            rd_sel <= SEL_ROM;
            wr_active <= 1'b0;
            rd_active <= 1'b0;
        end else begin
            if (!wr_active && m_awvalid && m_awready)
                wr_sel <= aw_sel;
            if (!wr_active && m_wvalid && m_wready)
                wr_active <= 1'b1;
            if (m_bvalid && m_bready)
                wr_active <= 1'b0;

            if (!rd_active && m_arvalid && m_arready) begin
                rd_sel <= ar_sel;
                rd_active <= 1'b1;
            end
            if (m_rvalid && m_rready)
                rd_active <= 1'b0;
        end
    end
endmodule
