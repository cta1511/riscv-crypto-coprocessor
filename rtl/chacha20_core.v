`timescale 1ns / 1ps

module chacha20_core #(
    parameter LATENCY = 24
) (
    input wire         clk,
    input wire         rst_n,
    input wire         start,
    input wire [255:0] key,
    input wire [31:0]  counter,
    input wire [95:0]  nonce,
    output reg         busy,
    output reg         done,
    output reg [511:0] keystream
);
    reg [31:0] x [0:15];
    reg [31:0] in_state [0:15];
    reg [511:0] chacha_result;
    reg [7:0] countdown;
    integer i;
    integer round;

    function [31:0] rotl32;
        input [31:0] x_in;
        input integer n;
        begin
            rotl32 = (x_in << n) | (x_in >> (32-n));
        end
    endfunction

    task quarter_round;
        inout [31:0] a;
        inout [31:0] b;
        inout [31:0] c;
        inout [31:0] d;
        begin
            a = a + b; d = rotl32(d ^ a, 16);
            c = c + d; b = rotl32(b ^ c, 12);
            a = a + b; d = rotl32(d ^ a, 8);
            c = c + d; b = rotl32(b ^ c, 7);
        end
    endtask

    always @(*) begin
        in_state[0]  = 32'h61707865;
        in_state[1]  = 32'h3320646e;
        in_state[2]  = 32'h79622d32;
        in_state[3]  = 32'h6b206574;
        in_state[4]  = key[31:0];
        in_state[5]  = key[63:32];
        in_state[6]  = key[95:64];
        in_state[7]  = key[127:96];
        in_state[8]  = key[159:128];
        in_state[9]  = key[191:160];
        in_state[10] = key[223:192];
        in_state[11] = key[255:224];
        in_state[12] = counter;
        in_state[13] = nonce[31:0];
        in_state[14] = nonce[63:32];
        in_state[15] = nonce[95:64];

        for (i = 0; i < 16; i = i + 1)
            x[i] = in_state[i];

        for (round = 0; round < 10; round = round + 1) begin
            quarter_round(x[0], x[4], x[8],  x[12]);
            quarter_round(x[1], x[5], x[9],  x[13]);
            quarter_round(x[2], x[6], x[10], x[14]);
            quarter_round(x[3], x[7], x[11], x[15]);
            quarter_round(x[0], x[5], x[10], x[15]);
            quarter_round(x[1], x[6], x[11], x[12]);
            quarter_round(x[2], x[7], x[8],  x[13]);
            quarter_round(x[3], x[4], x[9],  x[14]);
        end

        for (i = 0; i < 16; i = i + 1)
            x[i] = x[i] + in_state[i];

        chacha_result = {
            x[15], x[14], x[13], x[12], x[11], x[10], x[9], x[8],
            x[7],  x[6],  x[5],  x[4],  x[3],  x[2],  x[1], x[0]
        };
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            countdown <= 8'd0;
            keystream <= 512'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                countdown <= LATENCY[7:0];
                keystream <= chacha_result;
            end else if (busy) begin
                if (countdown > 8'd1) begin
                    countdown <= countdown - 8'd1;
                end else begin
                    countdown <= 8'd0;
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule
