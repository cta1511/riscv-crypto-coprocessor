`timescale 1ns / 1ps

module sha256_core #(
    parameter LATENCY = 66
) (
    input wire         clk,
    input wire         rst_n,
    input wire         start,
    input wire [511:0] block,
    output reg         busy,
    output reg         done,
    output reg [255:0] digest
);
    reg [31:0] w [0:63];
    reg [31:0] k [0:63];
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] t1, t2;
    reg [255:0] sha_result;
    reg [7:0] countdown;
    integer i;

    function [31:0] rotr;
        input [31:0] x;
        input integer n;
        begin
            rotr = (x >> n) | (x << (32-n));
        end
    endfunction

    always @(*) begin
        k[0]=32'h428a2f98;  k[1]=32'h71374491;  k[2]=32'hb5c0fbcf;  k[3]=32'he9b5dba5;
        k[4]=32'h3956c25b;  k[5]=32'h59f111f1;  k[6]=32'h923f82a4;  k[7]=32'hab1c5ed5;
        k[8]=32'hd807aa98;  k[9]=32'h12835b01;  k[10]=32'h243185be; k[11]=32'h550c7dc3;
        k[12]=32'h72be5d74; k[13]=32'h80deb1fe; k[14]=32'h9bdc06a7; k[15]=32'hc19bf174;
        k[16]=32'he49b69c1; k[17]=32'hefbe4786; k[18]=32'h0fc19dc6; k[19]=32'h240ca1cc;
        k[20]=32'h2de92c6f; k[21]=32'h4a7484aa; k[22]=32'h5cb0a9dc; k[23]=32'h76f988da;
        k[24]=32'h983e5152; k[25]=32'ha831c66d; k[26]=32'hb00327c8; k[27]=32'hbf597fc7;
        k[28]=32'hc6e00bf3; k[29]=32'hd5a79147; k[30]=32'h06ca6351; k[31]=32'h14292967;
        k[32]=32'h27b70a85; k[33]=32'h2e1b2138; k[34]=32'h4d2c6dfc; k[35]=32'h53380d13;
        k[36]=32'h650a7354; k[37]=32'h766a0abb; k[38]=32'h81c2c92e; k[39]=32'h92722c85;
        k[40]=32'ha2bfe8a1; k[41]=32'ha81a664b; k[42]=32'hc24b8b70; k[43]=32'hc76c51a3;
        k[44]=32'hd192e819; k[45]=32'hd6990624; k[46]=32'hf40e3585; k[47]=32'h106aa070;
        k[48]=32'h19a4c116; k[49]=32'h1e376c08; k[50]=32'h2748774c; k[51]=32'h34b0bcb5;
        k[52]=32'h391c0cb3; k[53]=32'h4ed8aa4a; k[54]=32'h5b9cca4f; k[55]=32'h682e6ff3;
        k[56]=32'h748f82ee; k[57]=32'h78a5636f; k[58]=32'h84c87814; k[59]=32'h8cc70208;
        k[60]=32'h90befffa; k[61]=32'ha4506ceb; k[62]=32'hbef9a3f7; k[63]=32'hc67178f2;

        for (i = 0; i < 16; i = i + 1)
            w[i] = block[511 - i*32 -: 32];
        for (i = 16; i < 64; i = i + 1)
            w[i] = (rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >> 3)) +
                   w[i-16] +
                   (rotr(w[i-2], 17) ^ rotr(w[i-2], 19) ^ (w[i-2] >> 10)) +
                   w[i-7];

        a = 32'h6a09e667; b = 32'hbb67ae85; c = 32'h3c6ef372; d = 32'ha54ff53a;
        e = 32'h510e527f; f = 32'h9b05688c; g = 32'h1f83d9ab; h = 32'h5be0cd19;

        for (i = 0; i < 64; i = i + 1) begin
            t1 = h + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ ((~e) & g)) + k[i] + w[i];
            t2 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
            h = g;
            g = f;
            f = e;
            e = d + t1;
            d = c;
            c = b;
            b = a;
            a = t1 + t2;
        end

        sha_result = {
            a + 32'h6a09e667,
            b + 32'hbb67ae85,
            c + 32'h3c6ef372,
            d + 32'ha54ff53a,
            e + 32'h510e527f,
            f + 32'h9b05688c,
            g + 32'h1f83d9ab,
            h + 32'h5be0cd19
        };
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            countdown <= 8'd0;
            digest <= 256'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                countdown <= LATENCY[7:0];
                digest <= sha_result;
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
