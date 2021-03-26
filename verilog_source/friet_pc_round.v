/**
 Implementation by Pedro Maat C. Massolino,
 hereby denoted as "the implementer".

 To the extent possible under law, the implementer has waived all copyright
 and related or neighboring rights to the source code in this file.
 http://creativecommons.org/publicdomain/zero/1.0/
*/
`default_nettype    none

/* verilator lint_off UNOPTFLAT */

module friet_pc_round
(
    input wire [383:0] state,
    input wire [4:0] rc,
    output wire [383:0] new_state
);

wire [127:0] temp_a;
wire [127:0] temp_b;
wire [127:0] temp_c;

wire [127:0] temp_t;
wire [127:0] temp_first_mix;

wire [127:0] temp_new_a;
wire [127:0] temp_new_b;
wire [127:0] temp_new_c;

assign temp_a = state[127:0];
assign temp_b = state[255:128];
 
assign temp_c[0]      = state[256] ^ (rc[0] & (~rc[4]));
assign temp_c[4]      = state[260] ^ (rc[1] & (~rc[4]));
assign temp_c[8]      = state[264] ^ (rc[2] & (~rc[4]));
assign temp_c[12]     = state[268] ^ (rc[3] & (~rc[4]));
assign temp_c[16]     = state[272] ^ (rc[0] & rc[4]);
assign temp_c[20]     = state[276] ^ (rc[1] & rc[4]);
assign temp_c[24]     = state[280] ^ (rc[2] & rc[4]);
assign temp_c[28]     = state[284] ^ (rc[3] & rc[4]);
assign temp_c[3:1]    = state[259:257];
assign temp_c[7:5]    = state[263:261];
assign temp_c[11:9]   = state[267:265];
assign temp_c[15:13]  = state[271:269];
assign temp_c[19:17]  = state[275:273];
assign temp_c[23:21]  = state[279:277];
assign temp_c[27:25]  = state[283:281];
assign temp_c[127:29] = state[383:285];

assign temp_t = temp_a ^ temp_b ^ temp_c;

// First mixing step

assign temp_first_mix[0]     = temp_a[127]   ^ temp_c[0];
assign temp_first_mix[127:1] = temp_a[126:0] ^ temp_c[127:1];

// Second mixing step

assign temp_new_c[79:0]   = temp_first_mix[127:48] ^ temp_a[79:0];
assign temp_new_c[127:80] = temp_first_mix[47:0]   ^ temp_a[127:80];

assign temp_new_b = temp_new_c ^ temp_first_mix ^ temp_t;

// Non linear step

assign temp_new_a[35:0]   = (temp_new_c[96:61]  & temp_new_b[127:92]) ^ temp_t[35:0];
assign temp_new_a[66:36]  = (temp_new_c[127:97] & temp_new_b[30:0])   ^ temp_t[66:36];
assign temp_new_a[127:67] = (temp_new_c[60:0]   & temp_new_b[91:31])  ^ temp_t[127:67];

assign new_state[127:0]   = temp_new_a;
assign new_state[255:128] = temp_new_b;
assign new_state[383:256] = temp_new_c;


endmodule
/* verilator lint_on UNOPTFLAT */