`timescale 1ns / 1ps

module pynq_z2_top (
    input wire CLK125MHZ,
    input wire [3:0] BTN,
    input wire [1:0] SW,
    output wire [3:0] LED,
    output wire [7:0] JB
);
    reg [15:0] rst_sync = 16'hffff;
    reg [26:0] heartbeat_cnt = 27'd0;
    reg [23:0] activity_stretch = 24'd0;
    wire rst_n;
    wire soc_trap;
    wire soc_axi_read;
    wire soc_axi_write;
    wire [31:0] fw_magic;
    wire [31:0] fw_passmask;
    wire [31:0] fw_stage;
    wire [31:0] fw_detail;
    wire [3:0] led_system;
    wire [3:0] led_firmware;

    always @(posedge CLK125MHZ or posedge BTN[0]) begin
        if (BTN[0]) begin
            rst_sync <= 16'h0000;
        end else begin
            rst_sync <= {rst_sync[14:0], 1'b1};
        end
    end

    assign rst_n = rst_sync[15];

    always @(posedge CLK125MHZ) begin
        if (!rst_n) begin
            heartbeat_cnt <= 27'd0;
            activity_stretch <= 24'd0;
        end else begin
            heartbeat_cnt <= heartbeat_cnt + 27'd1;
            if (soc_axi_read || soc_axi_write)
                activity_stretch <= 24'hffffff;
            else if (activity_stretch != 24'd0)
                activity_stretch <= activity_stretch - 24'd1;
        end
    end

    riscv_crypto_soc u_soc (
        .clk(CLK125MHZ),
        .rst_n(rst_n),
        .trap_o(soc_trap),
        .axi_read_o(soc_axi_read),
        .axi_write_o(soc_axi_write),
        .fw_magic_o(fw_magic),
        .fw_passmask_o(fw_passmask),
        .fw_stage_o(fw_stage),
        .fw_detail_o(fw_detail)
    );

    assign led_system = { |activity_stretch, soc_trap, ~rst_n, heartbeat_cnt[26] };
    assign led_firmware = fw_passmask[3:0];
    assign LED = SW[0] ? led_firmware : led_system;

    // Expose simple observability on Pmod JB for scope/LA.
    assign JB[0] = CLK125MHZ;
    assign JB[1] = rst_n;
    assign JB[2] = soc_trap;
    assign JB[3] = soc_axi_read;
    assign JB[4] = soc_axi_write;
    assign JB[5] = heartbeat_cnt[24];
    assign JB[6] = fw_magic[0];
    assign JB[7] = fw_stage[0];
endmodule
