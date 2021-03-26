/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

/* verilator lint_off UNOPTFLAT */

module friet_p_rounds_simple_asic
#(parameter ASYNC_RSTN = 0,// 0 - Synchronous reset in high, 1 - Asynchrouns reset in low.
parameter COMBINATIONAL_ROUNDS = 1 // The number of unrolled rounds in the Friet permutation (Values allowed : 1,2,3,4,6,8,12)
)
(
    input wire clk,
    input wire arstn,
    input wire [2:0] oper,
    input wire [127:0] din,
    input wire [4:0] din_size,
    input wire din_last,
    input wire din_valid,
    output wire din_ready,
    output wire [127:0] dout,
    output wire dout_valid,
    input wire dout_ready,
    output wire [4:0] dout_size,
    output wire dout_last,
    output wire fault_detected
);

localparam [4:0] master_round_constant  = 5'b01111;
localparam [4:0] last_round_constant_23 = 5'b11001;
localparam [4:0] last_round_constant_22 = 5'b01100;
localparam [4:0] last_round_constant_21 = 5'b10110;
localparam [4:0] last_round_constant_20 = 5'b01011;
localparam [4:0] last_round_constant_18 = 5'b01010;
localparam [4:0] last_round_constant_16 = 5'b01110;
localparam [4:0] last_round_constant_12 = 5'b00001;
localparam [4:0] last_round_constant = (COMBINATIONAL_ROUNDS == 1)  ? last_round_constant_23 :
                                       (COMBINATIONAL_ROUNDS == 2)  ? last_round_constant_22 :
                                       (COMBINATIONAL_ROUNDS == 3)  ? last_round_constant_21 :
                                       (COMBINATIONAL_ROUNDS == 4)  ? last_round_constant_20 :
                                       (COMBINATIONAL_ROUNDS == 6)  ? last_round_constant_18 :
                                       (COMBINATIONAL_ROUNDS == 8)  ? last_round_constant_16 :
                                       (COMBINATIONAL_ROUNDS == 12) ? last_round_constant_12 :
                                       master_round_constant;

reg int_din_ready;
wire int_dout_valid;

reg padding_bit_b;
reg [129:0] din_padding;
reg [129:0] din_padding_parity;
reg [127:0] din_mask;
wire [127:0] din_masked;
wire [129:0] din_padding_xor_state;
wire [127:0] din_xor_state_masked;
wire [129:0] din_absorb_enc;
wire [129:0] din_absorb_dec;

(* keep *) wire [127:0] din_padding_xor_state_parity;
(* keep *) wire [127:0] din_absorb_enc_parity;
(* keep *) wire [127:0] din_absorb_dec_din_xor_state;
(* keep *) wire [127:0] din_absorb_dec_din_xor_state_masked;
(* keep *) wire [127:0] din_absorb_dec_parity;

reg [127:0] reg_dout, next_dout;
reg [4:0] reg_dout_size, next_dout_size;
reg reg_dout_last, next_dout_last;

(* keep *) reg [511:0] reg_state, next_state;

(* keep *) reg [511:0] friet_p_round_state_initial;
(* keep *) wire [511:0] friet_p_round_state[0:(COMBINATIONAL_ROUNDS-1)];
(* keep *) wire [511:0] friet_p_round_new_state[0:(COMBINATIONAL_ROUNDS-1)];
(* keep *) reg [4:0] friet_p_round_rc_c_initial;
(* keep *) reg [4:0] friet_p_round_rc_d_initial;
(* keep *) wire [4:0] friet_p_round_rc_c[0:(COMBINATIONAL_ROUNDS-1)];
(* keep *) wire [4:0] friet_p_round_rc_d[0:(COMBINATIONAL_ROUNDS-1)];
(* keep *) wire [4:0] friet_p_round_new_rc_c[0:(COMBINATIONAL_ROUNDS-1)];
(* keep *) wire [4:0] friet_p_round_new_rc_d[0:(COMBINATIONAL_ROUNDS-1)];

(* keep *) reg [4:0] reg_friet_p_round_rc_c, next_friet_p_round_rc_c;
(* keep *) reg [4:0] reg_friet_p_round_rc_d, next_friet_p_round_rc_d;

(* keep *) reg reg_fault_detected, next_fault_detected;
(* keep *) wire [127:0] computed_parity;
(* keep *) reg internal_new_fault_detected;

wire din_valid_and_ready;
wire dout_valid_and_ready;
reg reg_computing_permutation, next_computing_permutation;
reg reg_has_data_out, next_has_data_out;

assign din_valid_and_ready = din_valid & int_din_ready;
assign dout_valid_and_ready = int_dout_valid & dout_ready;

generate
    if (ASYNC_RSTN != 0) begin : use_asynchrnous_reset_zero_enable
        always @(posedge clk or negedge arstn) begin
            if (arstn == 1'b0) begin
                reg_computing_permutation <= 1'b0;
                reg_has_data_out <= 1'b0;
                reg_friet_p_round_rc_c <= last_round_constant;
                reg_friet_p_round_rc_d <= last_round_constant;
                reg_fault_detected <= 1'b0;
            end else begin
                reg_computing_permutation <= next_computing_permutation;
                reg_has_data_out <= next_has_data_out;
                reg_friet_p_round_rc_c <= next_friet_p_round_rc_c;
                reg_friet_p_round_rc_d <= next_friet_p_round_rc_d;
                reg_fault_detected <= next_fault_detected;
            end
        end
    end else begin
        always @(posedge clk) begin
            if (arstn == 1'b1) begin
                reg_computing_permutation <= 1'b0;
                reg_has_data_out <= 1'b0;
                reg_friet_p_round_rc_c <= last_round_constant;
                reg_friet_p_round_rc_d <= last_round_constant;
                reg_fault_detected <= 1'b0;
            end else begin
                reg_computing_permutation <= next_computing_permutation;
                reg_has_data_out <= next_has_data_out;
                reg_friet_p_round_rc_c <= next_friet_p_round_rc_c;
                reg_friet_p_round_rc_d <= next_friet_p_round_rc_d;
                reg_fault_detected <= next_fault_detected;
            end
        end
    end
endgenerate

always @(posedge clk) begin
    reg_state <= next_state;
    reg_dout <= next_dout;
    reg_dout_size <= next_dout_size;
    reg_dout_last <= next_dout_last;
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption, Squeeze and permute, Absorb directly, Absorb encryption no output, Absorb decryption no output
            3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110 : begin
                next_state = friet_p_round_new_state[COMBINATIONAL_ROUNDS-1];
            end
            // Init state
            3'b000 : begin
                next_state = {512{1'b0}};
            end
            // Reserved
            3'b111 : begin
                next_state = reg_state;
            end
            default : begin
                next_state = {512{1'bx}};
            end
        endcase
    end else if((din_valid_and_ready == 1'b0) && (reg_computing_permutation == 1'b1)) begin
        next_state = friet_p_round_new_state[COMBINATIONAL_ROUNDS-1];
    end else if((din_valid_and_ready == 1'b0) && (reg_computing_permutation == 1'b0)) begin
        next_state = reg_state;
    end else begin
        next_state = {512{1'bx}};
    end
end

always @(*) begin
    case (oper)
        // Absorb directly
        3'b100 : begin
            if(din_last == 1'b1) begin
                padding_bit_b = 1'b1;
            end else if(din_last == 1'b0) begin
                padding_bit_b = 1'b0;
            end else begin
                padding_bit_b = 1'bx;
            end
        end
        // Absorb encryption, Absorb decryption, Absorb encryption no output, Absorb decryption no output
        3'b001, 3'b010, 3'b101,3'b110 : begin
            if(din_last == 1'b1) begin
                padding_bit_b = 1'b0;
            end else if(din_last == 1'b0) begin
                padding_bit_b = 1'b1;
            end else begin
                padding_bit_b = 1'bx;
            end
        end
        // Init State, Squeeze
        3'b000, 3'b011 : begin
            padding_bit_b = 1'b0;
        end
        // Reserved
        3'b111 : begin
            padding_bit_b = 1'b0;
        end
        default : begin
            padding_bit_b = 1'bx;
        end
    endcase
end

always @(*) begin
    case(din_size)
        5'b00000 : begin
            din_padding[7:0]     = {7'b0000001,padding_bit_b};
            din_padding[129:8]   = {122{1'b0}};
            din_mask[127:0]      = {16{8'h00}};
            din_padding_parity[1:0] = {1'b1,padding_bit_b};
            din_padding_parity[127:2] = {126{1'b0}};
        end                     
        5'b00001 : begin        
            din_padding[7:0]     = {8{1'b0}};
            din_padding[15:8]    = {7'b0000001,padding_bit_b};
            din_padding[129:16]  = {114{1'b0}};
            din_mask[7:0]        = {1{8'hFF}};
            din_mask[127:8]      = {15{8'h00}};
            din_padding_parity[7:0] = {8{1'b0}};
            din_padding_parity[9:8] = {1'b1,padding_bit_b};
            din_padding_parity[127:10] = {118{1'b0}};
        end                     
        5'b00010 : begin        
            din_padding[15:0]    = {16{1'b0}};
            din_padding[23:16]   = {7'b0000001,padding_bit_b};
            din_padding[129:24]  = {106{1'b0}};
            din_mask[15:0]       = {2{8'hFF}};
            din_mask[127:16]     = {14{8'h00}};
            din_padding_parity[15:0]   = {16{1'b0}};
            din_padding_parity[17:16]  = {1'b1,padding_bit_b};
            din_padding_parity[127:18] = {110{1'b0}};
        end                     
        5'b00011 : begin        
            din_padding[23:0]    = {24{1'b0}};
            din_padding[31:24]   = {7'b0000001,padding_bit_b};
            din_padding[129:32]  = {98{1'b0}};
            din_mask[23:0]       = {3{8'hFF}};
            din_mask[127:24]     = {13{8'h00}};
            din_padding_parity[23:0]   = {24{1'b0}};
            din_padding_parity[25:24]  = {1'b1,padding_bit_b};
            din_padding_parity[127:26] = {102{1'b0}};
        end                     
        5'b00100 : begin        
            din_padding[31:0]    = {32{1'b0}};
            din_padding[39:32]   = {7'b0000001,padding_bit_b};
            din_padding[129:40]  = {90{1'b0}};
            din_mask[31:0]       = {4{8'hFF}};
            din_mask[127:32]     = {12{8'h00}};
            din_padding_parity[31:0]   = {32{1'b0}};
            din_padding_parity[33:32]  = {1'b1,padding_bit_b};
            din_padding_parity[127:34] = {94{1'b0}};
        end                     
        5'b00101 : begin        
            din_padding[39:0]    = {40{1'b0}};
            din_padding[47:40]   = {7'b0000001,padding_bit_b};
            din_padding[129:48]  = {82{1'b0}};
            din_mask[39:0]       = {5{8'hFF}};
            din_mask[127:40]     = {11{8'h00}};
            din_padding_parity[39:0]   = {40{1'b0}};
            din_padding_parity[41:40]  = {1'b1,padding_bit_b};
            din_padding_parity[127:42] = {86{1'b0}};
        end                     
        5'b00110 : begin        
            din_padding[47:0]    = {48{1'b0}};
            din_padding[55:48]   = {7'b0000001,padding_bit_b};
            din_padding[129:56]  = {74{1'b0}};
            din_mask[47:0]       = {6{8'hFF}};
            din_mask[127:48]     = {10{8'h00}};
            din_padding_parity[47:0]   = {48{1'b0}};
            din_padding_parity[49:48]  = {1'b1,padding_bit_b};
            din_padding_parity[127:50] = {78{1'b0}};
        end                     
        5'b00111 : begin        
            din_padding[55:0]    = {56{1'b0}};
            din_padding[63:56]   = {7'b0000001,padding_bit_b};
            din_padding[129:64]  = {66{1'b0}};
            din_mask[55:0]       = {7{8'hFF}};
            din_mask[127:56]     = {9{8'h00}};
            din_padding_parity[55:0]   = {56{1'b0}};
            din_padding_parity[57:56]  = {1'b1,padding_bit_b};
            din_padding_parity[127:58] = {70{1'b0}};
        end                     
        5'b01000 : begin        
            din_padding[63:0]    = {64{1'b0}};
            din_padding[71:64]   = {7'b0000001,padding_bit_b};
            din_padding[129:72]  = {58{1'b0}};
            din_mask[63:0]       = {8{8'hFF}};
            din_mask[127:64]     = {8{8'h00}};
            din_padding_parity[63:0]   = {64{1'b0}};
            din_padding_parity[65:64]  = {1'b1,padding_bit_b};
            din_padding_parity[127:66] = {62{1'b0}};
        end                     
        5'b01001 : begin        
            din_padding[71:0]    = {72{1'b0}};
            din_padding[79:72]   = {7'b0000001,padding_bit_b};
            din_padding[129:80]  = {50{1'b0}};
            din_mask[71:0]       = {9{8'hFF}};
            din_mask[127:72]     = {7{8'h00}};
            din_padding_parity[71:0]   = {72{1'b0}};
            din_padding_parity[73:72]  = {1'b1,padding_bit_b};
            din_padding_parity[127:74] = {54{1'b0}};
        end                     
        5'b01010 : begin        
            din_padding[79:0]    = {80{1'b0}};
            din_padding[87:80]   = {7'b0000001,padding_bit_b};
            din_padding[129:88]  = {42{1'b0}};
            din_mask[79:0]       = {10{8'hFF}};
            din_mask[127:80]     = {6{8'h00}};
            din_padding_parity[79:0]   = {80{1'b0}};
            din_padding_parity[81:80]  = {1'b1,padding_bit_b};
            din_padding_parity[127:82] = {46{1'b0}};
        end                     
        5'b01011 : begin        
            din_padding[87:0]    = {88{1'b0}};
            din_padding[95:88]   = {7'b0000001,padding_bit_b};
            din_padding[129:96]  = {34{1'b0}};
            din_mask[87:0]       = {11{8'hFF}};
            din_mask[127:88]     = {5{8'h00}};
            din_padding_parity[87:0]   = {88{1'b0}};
            din_padding_parity[89:88]  = {1'b1,padding_bit_b};
            din_padding_parity[127:90] = {38{1'b0}};
        end
        5'b01100 : begin
            din_padding[95:0]    = {96{1'b0}};
            din_padding[103:96]  = {7'b0000001,padding_bit_b};
            din_padding[129:104] = {26{1'b0}};
            din_mask[95:0]       = {12{8'hFF}};
            din_mask[127:96]     = {4{8'h00}};
            din_padding_parity[95:0]   = {96{1'b0}};
            din_padding_parity[97:96]  = {1'b1,padding_bit_b};
            din_padding_parity[127:98] = {30{1'b0}};
        end
        5'b01101 : begin
            din_padding[103:0]    = {104{1'b0}};
            din_padding[111:104]  = {7'b0000001,padding_bit_b};
            din_padding[129:112]  = {18{1'b0}};
            din_mask[103:0]       = {13{8'hFF}};
            din_mask[127:104]     = {3{8'h00}};
            din_padding_parity[103:0]   = {104{1'b0}};
            din_padding_parity[105:104] = {1'b1,padding_bit_b};
            din_padding_parity[127:106] = {22{1'b0}};
        end
        5'b01110 : begin
            din_padding[111:0]    = {112{1'b0}};
            din_padding[119:112]  = {7'b0000001,padding_bit_b};
            din_padding[129:120]  = {10{1'b0}};
            din_mask[111:0]       = {14{8'hFF}};
            din_mask[127:112]     = {2{8'h00}};
            din_padding_parity[111:0]   = {112{1'b0}};
            din_padding_parity[113:112] = {1'b1,padding_bit_b};
            din_padding_parity[127:114] = {14{1'b0}};
        end
        5'b01111 : begin
            din_padding[119:0]    = {120{1'b0}};
            din_padding[127:120]  = {7'b0000001,padding_bit_b};
            din_padding[129:128]  = {2{1'b0}};
            din_mask[119:0]       = {15{8'hFF}};
            din_mask[127:120]     = {1{8'h00}};
            din_padding_parity[119:0]   = {120{1'b0}};
            din_padding_parity[121:120] = {1'b1,padding_bit_b};
            din_padding_parity[127:122] = {6{1'b0}};
        end
        5'b10000 : begin
            din_padding[129:0]    = {{1'b1},padding_bit_b,{128{1'b0}}};
            din_mask[127:0]       = {16{8'hFF}};
            din_padding_parity[1:0] = {1'b1,padding_bit_b};
            din_padding_parity[127:2] = {126{1'b0}};
        end
        5'b10001,5'b10010,5'b10011,5'b10100,5'b10101,5'b10110,5'b10111,5'b11000,5'b11001,5'b11010,5'b11011,5'b11100,5'b11101,5'b11110,5'b11111 : begin
            din_padding[129:0]    = {{1'b1},padding_bit_b,{128{1'b0}}};
            din_mask[127:0]       = {16{8'hFF}};
            din_padding_parity[1:0] = {1'b1,padding_bit_b};
            din_padding_parity[127:2] = {126{1'b0}};
        end
        default : begin
            din_padding[129:0]    = {130{1'bx}};
            din_mask[127:0]       = {128{1'bx}};
            din_padding_parity[127:0] = {128{1'bx}};
        end
    endcase
end

generate
    genvar gen_i;
    for (gen_i = 0; gen_i < 128; gen_i = gen_i + 1) begin: din_xor

        assign din_masked[gen_i] = din[gen_i] & din_mask[gen_i];
        assign din_padding_xor_state[gen_i] = din_padding[gen_i] ^ reg_state[gen_i];
        assign din_xor_state_masked[gen_i] = (din[gen_i] ^ reg_state[gen_i]) & din_mask[gen_i];
        assign din_absorb_enc[gen_i] = din_masked[gen_i] ^ din_padding_xor_state[gen_i];
        assign din_absorb_dec[gen_i] = din_xor_state_masked[gen_i] ^ din_padding_xor_state[gen_i];

        (* keep_hierarchy *) xor din_xor_state_1_gen_i (din_padding_xor_state_parity[gen_i], din_padding_parity[gen_i], reg_state[gen_i+384]);
        (* keep_hierarchy *) xor din_enc_1_gen_i (din_absorb_enc_parity[gen_i], din_masked[gen_i], din_padding_xor_state_parity[gen_i]);
        (* keep_hierarchy *) xor din_dec_1_gen_i (din_absorb_dec_din_xor_state[gen_i], din[gen_i], reg_state[gen_i]);
        (* keep_hierarchy *) and din_dec_2_gen_i (din_absorb_dec_din_xor_state_masked[gen_i], din_mask[gen_i], din_absorb_dec_din_xor_state[gen_i]);
        (* keep_hierarchy *) xor din_dec_3_gen_i (din_absorb_dec_parity[gen_i], din_padding_xor_state_parity[gen_i], din_absorb_dec_din_xor_state_masked[gen_i]);
    end
endgenerate
assign din_padding_xor_state[128] = din_padding[128] ^ reg_state[128];
assign din_padding_xor_state[129] = din_padding[129] ^ reg_state[129];
assign din_absorb_enc[128] = din_padding_xor_state[128];
assign din_absorb_enc[129] = din_padding_xor_state[129];
assign din_absorb_dec[128] = din_padding_xor_state[128];
assign din_absorb_dec[129] = din_padding_xor_state[129];


always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption, Squeeze and permute, Absorb directly, Absorb encryption no output, Absorb decryption no output
            3'b001, 3'b010, 3'b011, 3'b100, 3'b101,3'b110  : begin
                if((oper == 3'b010) || (oper == 3'b110)) begin
                    friet_p_round_state_initial[129:0]   = din_absorb_dec;
                    friet_p_round_state_initial[511:384] = din_absorb_dec_parity;
                end else begin
                    friet_p_round_state_initial[129:0]   = din_absorb_enc;
                    friet_p_round_state_initial[511:384] = din_absorb_enc_parity;
                end
                friet_p_round_state_initial[383:130]   = reg_state[383:130];
            end
            // Init State
            3'b000 : begin
                friet_p_round_state_initial = reg_state;
            end
            // Reserved
            3'b111 : begin
                friet_p_round_state_initial = reg_state;
            end
            default : begin
                friet_p_round_state_initial = {512{1'bx}};
            end
        endcase
    end else if(din_valid_and_ready == 1'b0) begin
        friet_p_round_state_initial = reg_state;
    end else begin
        friet_p_round_state_initial = {512{1'bx}};
    end
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption, Squeeze and permute, Absorb directly, Absorb encryption no output, Absorb decryption no output
            3'b001, 3'b010, 3'b011, 3'b100, 3'b101,3'b110 : begin
                next_friet_p_round_rc_c = friet_p_round_new_rc_c[COMBINATIONAL_ROUNDS-1];
                next_friet_p_round_rc_d = friet_p_round_new_rc_d[COMBINATIONAL_ROUNDS-1];
            end
            // Init State
            3'b000 : begin 
                next_friet_p_round_rc_c = reg_friet_p_round_rc_c;
                next_friet_p_round_rc_d = reg_friet_p_round_rc_d;
            end
            // Reserved
            3'b111 : begin 
                next_friet_p_round_rc_c = reg_friet_p_round_rc_c;
                next_friet_p_round_rc_d = reg_friet_p_round_rc_d;
            end
            default : begin
                next_friet_p_round_rc_c = {5{1'bx}};
                next_friet_p_round_rc_d = {5{1'bx}};
            end
        endcase
    end else if((din_valid_and_ready == 1'b0) && (reg_computing_permutation == 1'b1)) begin
        next_friet_p_round_rc_c = friet_p_round_new_rc_c[COMBINATIONAL_ROUNDS-1];
        next_friet_p_round_rc_d = friet_p_round_new_rc_d[COMBINATIONAL_ROUNDS-1];
    end else if((din_valid_and_ready == 1'b0) && (reg_computing_permutation == 1'b0)) begin
        next_friet_p_round_rc_c = reg_friet_p_round_rc_c;
        next_friet_p_round_rc_d = reg_friet_p_round_rc_d;
    end else begin
        next_friet_p_round_rc_c = {5{1'bx}};
        next_friet_p_round_rc_d = {5{1'bx}};
    end
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption, Squeeze and permute, Absorb directly, Absorb encryption no output, Absorb decryption no output
            3'b001, 3'b010, 3'b011, 3'b100, 3'b101,3'b110 : begin
                friet_p_round_rc_c_initial = master_round_constant;
                friet_p_round_rc_d_initial = master_round_constant;
            end
            // Init State, Squeeze
            3'b000 : begin 
                friet_p_round_rc_c_initial = reg_friet_p_round_rc_c;
                friet_p_round_rc_d_initial = reg_friet_p_round_rc_d;
            end
            // Reserved
            3'b111 : begin 
                friet_p_round_rc_c_initial = reg_friet_p_round_rc_c;
                friet_p_round_rc_d_initial = reg_friet_p_round_rc_d;
            end
            default : begin
                friet_p_round_rc_c_initial = {5{1'bx}};
                friet_p_round_rc_d_initial = {5{1'bx}};
            end
        endcase
    end else if(din_valid_and_ready == 1'b0) begin
        friet_p_round_rc_c_initial = reg_friet_p_round_rc_c;
        friet_p_round_rc_d_initial = reg_friet_p_round_rc_d;
    end else begin
        friet_p_round_rc_c_initial = {5{1'bx}};
        friet_p_round_rc_d_initial = {5{1'bx}};
    end
end

reg is_last_rc;

always @(*) begin
    if(reg_friet_p_round_rc_c == last_round_constant) begin
        is_last_rc = 1'b1;
    end else if(reg_friet_p_round_rc_c != last_round_constant) begin
        is_last_rc = 1'b0;
    end else begin
        is_last_rc = 1'bx;
    end
end

assign friet_p_round_state[0] = friet_p_round_state_initial;
assign friet_p_round_rc_c[0] = friet_p_round_rc_c_initial;
assign friet_p_round_rc_d[0] = friet_p_round_rc_d_initial;

generate
    genvar gen_j;
    for (gen_j = 0; gen_j < COMBINATIONAL_ROUNDS; gen_j = gen_j + 1) begin: all_combinational_rounds
        (* keep_hierarchy *)
        friet_p_round_asic friet_p_round_gen_j(
            .state(friet_p_round_state[gen_j]),
            .rc_c(friet_p_round_rc_c[gen_j]),
            .rc_d(friet_p_round_rc_d[gen_j]),
            .new_state(friet_p_round_new_state[gen_j])
        );
        
        (* keep_hierarchy *)
        friet_p_rc rc_c_gen_j(
            .rc(friet_p_round_rc_c[gen_j]),
            .new_rc(friet_p_round_new_rc_c[gen_j])
        );
        (* keep_hierarchy *)
        friet_p_rc rc_d_gen_j(
            .rc(friet_p_round_rc_d[gen_j]),
            .new_rc(friet_p_round_new_rc_d[gen_j])
        );
        
        if(gen_j > 0) begin: all_combinational_rounds_next_iteration
            assign friet_p_round_state[gen_j] = friet_p_round_new_state[gen_j-1];
            assign friet_p_round_rc_c[gen_j]  = friet_p_round_new_rc_c[gen_j-1];
            assign friet_p_round_rc_d[gen_j]  = friet_p_round_new_rc_d[gen_j-1];
        end
    end
endgenerate

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption, Squeeze and permute, Absorb directly, Absorb encryption no output, Absorb decryption no output
            3'b001, 3'b010, 3'b011, 3'b100, 3'b101,3'b110 : begin
                next_computing_permutation = 1'b1;
            end
            // Init State
            3'b000 : begin 
                 next_computing_permutation = 1'b0;
            end
            // Reserved
            3'b111 : begin 
                 next_computing_permutation = 1'b0;
            end
            default : begin
                next_computing_permutation = 1'bx;
            end
        endcase
    end else if((din_valid_and_ready == 1'b0) && (reg_computing_permutation == 1'b1)) begin
        if(is_last_rc == 1'b1) begin
            next_computing_permutation = 1'b0;
        end else if(is_last_rc == 1'b0) begin
            next_computing_permutation = reg_computing_permutation;
        end else begin
            next_computing_permutation = 1'bx;
        end
    end else if((din_valid_and_ready == 1'b0) && (reg_computing_permutation == 1'b0)) begin
        next_computing_permutation = reg_computing_permutation;
    end else begin
        next_computing_permutation = 1'bx;
    end
end

always @(*) begin
    if(reg_computing_permutation == 1'b1) begin
        int_din_ready = 1'b0;
    end else if((reg_computing_permutation == 1'b0) && (reg_has_data_out == 1'b1)) begin
        int_din_ready = dout_ready;
    end else if((reg_computing_permutation == 1'b0) && (reg_has_data_out == 1'b0)) begin
        int_din_ready = 1'b1;
    end else begin
        int_din_ready = 1'bx;
    end
end

always @(*) begin
    case({din_valid_and_ready, dout_valid_and_ready})
        2'b11 : begin
            case (oper)
                // Absorb encryption, Absorb decryption, Squeeze and permute
                3'b001, 3'b010, 3'b011 : begin
                    next_has_data_out = 1'b1;
                end
                // Init State, Absorb none, Absorb encryption no output, Absorb decryption no output
                3'b000, 3'b100, 3'b101, 3'b110 : begin 
                    next_has_data_out = 1'b0;
                end
                // Reserved
                3'b111 : begin 
                    next_has_data_out = 1'b0;
                end
                default : begin
                    next_has_data_out = 1'bx;
                end
            endcase
        end
        2'b10 : begin
            case (oper)
                // Absorb encryption, Absorb decryption, Squeeze and permute
                3'b001, 3'b010, 3'b011 : begin
                    next_has_data_out = 1'b1;
                end
                // Init State, Absorb none, Absorb encryption no output, Absorb decryption no output
                3'b000, 3'b100, 3'b101, 3'b110 : begin 
                    next_has_data_out = reg_has_data_out;
                end
                // Reserved
                3'b111 : begin
                    next_has_data_out = reg_has_data_out;
                end
                default : begin
                    next_has_data_out = 1'bx;
                end
            endcase
        end
        2'b01 : begin
            next_has_data_out = 1'b0;
        end
        2'b00 : begin
            next_has_data_out = reg_has_data_out;
        end
        default : begin
            next_has_data_out = 1'bx;
        end
    endcase
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption
            3'b001, 3'b010 : begin
                next_dout = din_xor_state_masked;
            end
            // Squeeze and permute
            3'b011 : begin
                next_dout = reg_state[127:0];
            end
            // Init State, Absorb none, Absorb encryption no output, Absorb decryption no output
            3'b000, 3'b100, 3'b101, 3'b110 : begin 
                next_dout = reg_dout;
            end
            // Reserved
            3'b111 : begin 
                next_dout = reg_dout;
            end
            default : begin
                next_dout = {128{1'bx}};
            end
        endcase
    end else if(din_valid_and_ready == 1'b0) begin
        next_dout = reg_dout;
    end else begin
        next_dout = {128{1'bx}};
    end
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption
            3'b001, 3'b010 : begin
                next_dout_size = din_size;
            end
            // Squeeze and permute, Squeeze
            3'b011 : begin
                next_dout_size = 5'b10000;
            end
            // Init State, Absorb none, Absorb encryption no output, Absorb decryption no output
            3'b000, 3'b100, 3'b101, 3'b110 : begin 
                next_dout_size = 5'b00000;
            end
            // Reserved
            3'b111 : begin
                next_dout_size = din_size;
            end
            default : begin
                next_dout_size = {5{1'bx}};
            end
        endcase
    end else if(din_valid_and_ready == 1'b0) begin
        next_dout_size = reg_dout_size;
    end else begin
        next_dout_size = {5{1'bx}};
    end
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption
            3'b001, 3'b010, 3'b011 : begin
                next_dout_last = din_last;
            end
            // Init State, Absorb none, Absorb encryption no output, Absorb decryption no output
            3'b000, 3'b100, 3'b101, 3'b110 : begin 
                next_dout_last = 1'b0;
            end
            // Reserved
            3'b111 : begin 
                next_dout_last = din_last;
            end
            default : begin
                next_dout_last = 1'bx;
            end
        endcase
    end else if(din_valid_and_ready == 1'b0) begin
        next_dout_last = reg_dout_last;
    end else begin
        next_dout_last = 1'bx;
    end
end

assign computed_parity = reg_state[127:0] ^ reg_state[255:128] ^ reg_state[383:256] ^ reg_state[511:384];

always @(*) begin
    if(computed_parity != 128'b0) begin
        internal_new_fault_detected = 1'b1;
    end else if(computed_parity == 128'b0) begin
        internal_new_fault_detected = 1'b0;
    end else begin
        internal_new_fault_detected = 1'bx;
    end
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        case (oper)
            // Absorb encryption, Absorb decryption, Squeeze and permute, Absorb none, Absorb encryption no output, Absorb decryption no output
            3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110 : begin
                next_fault_detected = reg_fault_detected | internal_new_fault_detected;
            end
            // Init State
            3'b000 : begin 
                next_fault_detected = 1'b0;
            end
            // Reserved
            3'b111 : begin 
                next_fault_detected = reg_fault_detected | internal_new_fault_detected;
            end
            default : begin
                next_fault_detected = 1'bx;
            end
        endcase
    end else if(din_valid_and_ready == 1'b0) begin
        next_fault_detected = reg_fault_detected | internal_new_fault_detected;
    end else begin
        next_fault_detected = 1'bx;
    end
end

assign int_dout_valid = reg_has_data_out;

assign din_ready = int_din_ready;
assign dout_valid = int_dout_valid;
assign dout = reg_dout;
assign dout_size = reg_dout_size;
assign dout_last = reg_dout_last;
assign fault_detected = reg_fault_detected;

endmodule

/* verilator lint_on UNOPTFLAT */