/**
 Implementation by Pedro Maat C. Massolino,
 hereby denoted as "the implementer".

 To the extent possible under law, the implementer has waived all copyright
 and related or neighboring rights to the source code in this file.
 http://creativecommons.org/publicdomain/zero/1.0/
*/
`default_nettype    none

module friet_p_round_asic
(
    input wire [511:0] state,
    input wire [4:0] rc_c,
    input wire [4:0] rc_d,
    output wire [511:0] new_state
);

wire [127:0] temp_a;
wire [127:0] temp_b;
wire [127:0] temp_c;
wire [127:0] temp_d;

(* keep *) wire n_rc_c_4;
(* keep *) wire n_rc_d_4;
(* keep *) wire [127:0] temp_first_mix_1;
(* keep *) wire [127:0] temp_first_mix_2;
(* keep *) wire [127:0] temp_second_mix_1;
(* keep *) wire [127:0] temp_second_mix_2;
(* keep *) wire [127:0] temp_non_linear_1;
(* keep *) wire [127:0] temp_non_linear_2;

assign temp_a = state[127:0];
assign temp_b = state[255:128];
assign temp_c[3:1]    = state[259:257];
assign temp_c[7:5]    = state[263:261];
assign temp_c[11:9]   = state[267:265];
assign temp_c[15:13]  = state[271:269];
assign temp_c[19:17]  = state[275:273];
assign temp_c[23:21]  = state[279:277];
assign temp_c[27:25]  = state[283:281];
assign temp_c[127:29] = state[383:285];
assign temp_d[3:1]    = state[387:385];
assign temp_d[7:5]    = state[391:389];
assign temp_d[11:9]   = state[395:393];
assign temp_d[15:13]  = state[399:397];
assign temp_d[19:17]  = state[403:401];
assign temp_d[23:21]  = state[407:405];
assign temp_d[27:25]  = state[411:409];
assign temp_d[127:29] = state[511:413];

(* keep_hierarchy *) not NRC_C_ENABLE(n_rc_c_4, rc_c[4]);
(* keep_hierarchy *) not NRC_D_ENABLE(n_rc_d_4, rc_d[4]);

generate
    genvar gen_j;
    for (gen_j = 0; gen_j < 4; gen_j = gen_j + 1) begin: c_d_with_rc
        (* keep_hierarchy *) friet_p_xaon_gate XRC_C_gen_j(temp_c[4*gen_j], n_rc_c_4, rc_c[gen_j], state[4*gen_j+256]);
        (* keep_hierarchy *) friet_p_xaon_gate XRC_C_gen_j_16(temp_c[4*gen_j+16], rc_c[4], rc_c[gen_j], state[4*gen_j+16+256]);
        (* keep_hierarchy *) friet_p_xaon_gate XRC_D_gen_j(temp_d[4*gen_j], n_rc_d_4, rc_d[gen_j], state[4*gen_j+384]);
        (* keep_hierarchy *) friet_p_xaon_gate XRC_D_gen_j_16(temp_d[4*gen_j+16], rc_d[4], rc_d[gen_j], state[4*gen_j+16+384]);
    end
endgenerate

// First mixing step

generate
    for (gen_j = 0; gen_j < 128; gen_j = gen_j + 1) begin: first_mix_1_2
        (* keep_hierarchy *) xor XFM_1_gen_j(temp_first_mix_1[gen_j], temp_a[(gen_j-1+128) % 128], temp_c[gen_j]);
        (* keep_hierarchy *) xor XFM_2_gen_j(temp_first_mix_2[gen_j], temp_a[(gen_j-1+128) % 128], temp_b[gen_j]);
    end
endgenerate

// Second mixing step

generate
    for (gen_j = 0; gen_j < 128; gen_j = gen_j + 1) begin: second_mix_1_2
        (* keep_hierarchy *) xor XSM_1_gen_j(temp_second_mix_1[gen_j], temp_first_mix_1[(gen_j-80+128) % 128], temp_a[gen_j]);
        (* keep_hierarchy *) xor XSM_2_gen_j(temp_second_mix_2[gen_j], temp_first_mix_1[(gen_j-80+128) % 128], temp_first_mix_2[gen_j]);
    end
endgenerate

// Non linear step

generate
    for (gen_j = 0; gen_j < 128; gen_j = gen_j + 1) begin: non_linear_1_2
        (* keep_hierarchy *) friet_p_xaon_gate XNL_1_gen_j(temp_non_linear_1[gen_j], temp_second_mix_1[(gen_j-67+128) % 128], temp_second_mix_2[(gen_j-36+128) % 128], temp_d[gen_j]);
        (* keep_hierarchy *) friet_p_xaon_gate XNL_2_gen_j(temp_non_linear_2[gen_j], temp_second_mix_1[(gen_j-67+128) % 128], temp_second_mix_2[(gen_j-36+128) % 128], temp_first_mix_1[gen_j]);
    end
endgenerate

assign new_state[127:0]   = temp_non_linear_1;
assign new_state[255:128] = temp_second_mix_2;
assign new_state[383:256] = temp_second_mix_1;
assign new_state[511:384] = temp_non_linear_2;

endmodule