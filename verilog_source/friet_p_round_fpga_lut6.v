/**
 Implementation by Pedro Maat C. Massolino,
 hereby denoted as "the implementer".

 To the extent possible under law, the implementer has waived all copyright
 and related or neighboring rights to the source code in this file.
 http://creativecommons.org/publicdomain/zero/1.0/
*/
/* verilator lint_off UNOPTFLAT */
`default_nettype    none

(* dont_touch = "yes" *) module friet_p_round_fpga_lut6
(
    input wire [511:0] state,
    input wire [4:0] rc_c,
    input wire [4:0] rc_d,
    output wire [511:0] new_state
);

wire [127:0] a;
wire [127:0] b;
wire [127:0] c;
wire [127:0] d;

assign a = state[127:0];
assign b = state[255:128];
assign c = state[383:256];
assign d = state[511:384];

(* dont_touch = "yes" *) wire [127:0] temp_before_epsilon_a;
(* dont_touch = "yes" *) wire [127:0] temp_before_epsilon_b;
(* dont_touch = "yes" *) wire [127:0] temp_before_epsilon_c;
(* dont_touch = "yes" *) wire [127:0] temp_before_epsilon_d;

generate
    genvar gen_j;
    for (gen_j = 0; gen_j < 128; gen_j = gen_j + 1) begin: before_epsilon
        if((gen_j == 80) || (gen_j == 84) || (gen_j == 88) || (gen_j == 92)) begin: before_epsilon_with_rc_1
            assign temp_before_epsilon_a[gen_j] = a[gen_j] ^ (c[(gen_j-80+128) % 128] ^ (rc_c[((gen_j-80) / 4)] & (~rc_c[4])) ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_b[gen_j] = b[gen_j] ^ (a[(gen_j-1+128) % 128]) ^ (c[(gen_j-80+128) % 128] ^ (rc_c[((gen_j-80) / 4)] & (~rc_c[4])) ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_c[(gen_j-80+128) % 128] = (c[(gen_j-80+128) % 128] ^ (rc_c[((gen_j-80) / 4)] & (~rc_c[4])) ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_d[(gen_j-80+128) % 128] = d[(gen_j-80+128) % 128] ^ (rc_d[((gen_j-80) / 4)] & (~rc_d[4]));
        end else if((gen_j == 96) || (gen_j == 100) || (gen_j == 104) || (gen_j == 108)) begin: before_epsilon_with_rc_2
            assign temp_before_epsilon_a[gen_j] = a[gen_j] ^ (c[(gen_j-80+128) % 128] ^ (rc_c[((gen_j-96) / 4)] & (rc_c[4])) ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_b[gen_j] = b[gen_j] ^ (a[(gen_j-1+128) % 128]) ^ (c[(gen_j-80+128) % 128] ^ (rc_c[((gen_j-96) / 4)] & (rc_c[4])) ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_c[(gen_j-80+128) % 128] = (c[(gen_j-80+128) % 128] ^ (rc_c[((gen_j-96) / 4)] & (rc_c[4])) ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_d[(gen_j-80+128) % 128] = d[(gen_j-80+128) % 128] ^ (rc_d[((gen_j-96) / 4)] & (rc_d[4]));
        end else begin: before_epsilon_without_rc
            assign temp_before_epsilon_a[gen_j] = a[gen_j] ^ (c[(gen_j-80+128) % 128] ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_b[gen_j] = b[gen_j] ^ (a[(gen_j-1+128) % 128]) ^ (c[(gen_j-80+128) % 128] ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_c[(gen_j-80+128) % 128] = (c[(gen_j-80+128) % 128] ^ a[(gen_j-80-1+128) % 128]);
            assign temp_before_epsilon_d[(gen_j-80+128) % 128] = d[(gen_j-80+128) % 128];
        end
    end
endgenerate

generate
    for (gen_j = 0; gen_j < 128; gen_j = gen_j + 1) begin: after_epsilon
        assign new_state[gen_j]     = temp_before_epsilon_d[gen_j] ^ (temp_before_epsilon_a[(gen_j-67+128) % 128] & temp_before_epsilon_b[(gen_j-36+128) % 128]);
        assign new_state[128+gen_j] = temp_before_epsilon_b[gen_j];
        assign new_state[256+gen_j] = temp_before_epsilon_a[gen_j];
        assign new_state[384+gen_j] = temp_before_epsilon_c[gen_j] ^ (temp_before_epsilon_a[(gen_j-67+128) % 128] & temp_before_epsilon_b[(gen_j-36+128) % 128]);
    end
endgenerate

endmodule
/* verilator lint_on UNOPTFLAT */