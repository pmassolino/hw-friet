/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

module friet_stream_state_machine
#(parameter ASYNC_RSTN = 1,
parameter KEY_AE_TAG_SIZE_LENGTH = 1,   // The counter length to fit both key and tag size
parameter [KEY_AE_TAG_SIZE_LENGTH-1:0] KEY_TAG_SIZE = 1'd1, // Key tag size in words of 128 bits. The number is one smaller, for example 0 is 1 word.
parameter [KEY_AE_TAG_SIZE_LENGTH-1:0] AE_TAG_SIZE = 1'd1  // AE Tag size in words of 128 bits. The number is one smaller, for example 0 is 1 word.
)
(
    input wire clk,
    input wire arstn,
    // Buffer in
    input wire din_last,
    input wire din_valid_and_ready,
    output wire buffer_in_rst,
    output wire buffer_in_din_oper,
    input wire buffer_in_size_full,
    input wire buffer_in_next_size_full,
    // Instruction bus
    input wire [3:0] inst,
    input wire inst_valid_and_ready,
    output wire inst_ready,
    input wire [3:0] reg_inst,
    // Permutation core
    input wire p_core_din_valid_and_ready,
    output wire [1:0] p_core_din_oper,
    output wire [2:0] p_core_oper,
    output wire sm_p_core_din_last,
    input wire p_core_dout_valid_and_ready,
    // Buffer out
    input wire buffer_out_dout_last,
    output wire buffer_out_rst,
    output wire [1:0] buffer_out_din_oper,
    // Tag compare register
    input wire reg_compare_tag_valid_and_ready,
    output wire reg_compare_tag_rst,
    output wire reg_compare_tag_enable,
    // Counter tag size
    output wire reg_ctr_tag_size_rst,
    output wire [1:0] reg_ctr_tag_size_oper,
    input wire is_reg_ctr_tag_size_zero,
    input wire is_reg_ctr_tag_size_one,
    // Dout
    input wire dout_valid_and_ready,
    output wire [1:0] dout_oper
);

reg reg_buffer_in_rst, next_buffer_in_rst;
reg reg_buffer_in_din_oper, next_buffer_in_din_oper;
reg reg_inst_ready, next_inst_ready;
reg [1:0] reg_p_core_din_oper, next_p_core_din_oper;
reg [2:0] reg_p_core_oper, next_p_core_oper;
reg reg_sm_p_core_din_last, next_sm_p_core_din_last;
reg reg_buffer_out_rst, next_buffer_out_rst;
reg [1:0] reg_buffer_out_din_oper, next_buffer_out_din_oper;
reg reg_reg_compare_tag_rst, next_reg_compare_tag_rst;
reg reg_reg_compare_tag_enable, next_reg_compare_tag_enable;
reg reg_reg_ctr_tag_size_rst, next_reg_ctr_tag_size_rst;
reg [1:0] reg_reg_ctr_tag_size_oper, next_reg_ctr_tag_size_oper;
reg [1:0] reg_dout_oper, next_dout_oper;


localparam s_reset = 8'h00, s_idle = 8'h01,
           s_key_0 = 8'h10, s_key_1 = 8'h11, s_key_2 = 8'h12,
           s_enc_dec_0 = 8'h20, s_enc_dec_1 = 8'h21, s_enc_dec_2 = 8'h22, s_enc_dec_3 = 8'h23, s_enc_dec_4 = 8'h24, s_enc_dec_5 = 8'h25, s_enc_dec_6 = 8'h26, 
           s_enc_8 = 8'h28, s_enc_9 = 8'h29, s_enc_10 = 8'h2A, s_enc_11 = 8'h2B, s_enc_12 = 8'h2C,
           s_dec_8 = 8'h38, s_dec_9 = 8'h39, s_dec_10 = 8'h3A, s_dec_11 = 8'h3B, s_dec_12 = 8'h3C, s_dec_13 = 8'h3D, s_dec_14 = 8'h3E, s_dec_15 = 8'h3F, s_dec_16 = 8'h40, s_dec_17 = 8'h41, s_dec_18 = 8'h42
           ;
reg[7:0] actual_state, next_state;

generate
    if (ASYNC_RSTN != 0) begin : use_asynchrnous_reset_zero_enable
        always @(posedge clk or negedge arstn) begin
            if (arstn == 1'b0) begin
                actual_state <= s_reset;
                reg_buffer_in_rst <= 1'b1;
                reg_buffer_in_din_oper <= 1'b0;
                reg_inst_ready <= 1'b0;
                reg_p_core_din_oper <= 2'b00;
                reg_p_core_oper <= 3'b000;
                reg_sm_p_core_din_last <= 1'b0;
                reg_buffer_out_rst <= 1'b1;
                reg_buffer_out_din_oper <= 2'b00;
                reg_reg_compare_tag_rst <= 1'b0;
                reg_reg_compare_tag_enable <= 1'b0;
                reg_reg_ctr_tag_size_rst <= 1'b0;
                reg_reg_ctr_tag_size_oper <= 2'b00;
                reg_dout_oper <= 2'b00;
            end else begin
                actual_state <= next_state;
                reg_buffer_in_rst <= next_buffer_in_rst;
                reg_buffer_in_din_oper <= next_buffer_in_din_oper;
                reg_inst_ready <= next_inst_ready;
                reg_p_core_din_oper <= next_p_core_din_oper;
                reg_p_core_oper <= next_p_core_oper;
                reg_sm_p_core_din_last <= next_sm_p_core_din_last;
                reg_buffer_out_rst <= next_buffer_out_rst;
                reg_buffer_out_din_oper <= next_buffer_out_din_oper;
                reg_reg_compare_tag_rst <= next_reg_compare_tag_rst;
                reg_reg_compare_tag_enable <= next_reg_compare_tag_enable;
                reg_reg_ctr_tag_size_rst <= next_reg_ctr_tag_size_rst;
                reg_reg_ctr_tag_size_oper <= next_reg_ctr_tag_size_oper;
                reg_dout_oper <= next_dout_oper;
            end
        end
    end else begin : use_synchrnous_reset
        always @(posedge clk) begin
            if (arstn == 1'b1) begin
                actual_state <= s_reset;
                reg_buffer_in_rst <= 1'b1;
                reg_buffer_in_din_oper <= 1'b0;
                reg_inst_ready <= 1'b0;
                reg_p_core_din_oper <= 2'b00;
                reg_p_core_oper <= 3'b000;
                reg_sm_p_core_din_last <= 1'b0;
                reg_buffer_out_rst <= 1'b1;
                reg_buffer_out_din_oper <= 2'b00;
                reg_reg_compare_tag_rst <= 1'b0;
                reg_reg_compare_tag_enable <= 1'b0;
                reg_reg_ctr_tag_size_rst <= 1'b0;
                reg_reg_ctr_tag_size_oper <= 2'b00;
                reg_dout_oper <= 2'b00;
            end else begin
                actual_state <= next_state;
                reg_buffer_in_rst <= next_buffer_in_rst;
                reg_buffer_in_din_oper <= next_buffer_in_din_oper;
                reg_inst_ready <= next_inst_ready;
                reg_p_core_din_oper <= next_p_core_din_oper;
                reg_p_core_oper <= next_p_core_oper;
                reg_sm_p_core_din_last <= next_sm_p_core_din_last;
                reg_buffer_out_rst <= next_buffer_out_rst;
                reg_buffer_out_din_oper <= next_buffer_out_din_oper;
                reg_reg_compare_tag_rst <= next_reg_compare_tag_rst;
                reg_reg_compare_tag_enable <= next_reg_compare_tag_enable;
                reg_reg_ctr_tag_size_rst <= next_reg_ctr_tag_size_rst;
                reg_reg_ctr_tag_size_oper <= next_reg_ctr_tag_size_oper;
                reg_dout_oper <= next_dout_oper;
            end
        end
    end
endgenerate


always @(*) begin
    next_buffer_in_rst = 1'b0;
    next_buffer_in_din_oper = 1'b0;
    next_inst_ready = 1'b0;
    next_p_core_din_oper = 2'b00;
    next_p_core_oper = 3'b000;
    next_sm_p_core_din_last = 1'b0;
    next_buffer_out_rst = 1'b0;
    next_buffer_out_din_oper = 2'b00;
    next_reg_compare_tag_rst = 1'b0;
    next_reg_compare_tag_enable = 1'b0;
    next_reg_ctr_tag_size_rst = 1'b0;
    next_reg_ctr_tag_size_oper = 2'b00;
    next_dout_oper = 2'b00;
    case(next_state)
        s_reset : begin
            next_buffer_in_rst = 1'b1;
            next_buffer_in_din_oper = 1'b1;
            next_buffer_out_rst = 1'b1;
            next_reg_ctr_tag_size_rst = 1'b1;
        end
        s_idle : begin
            next_inst_ready = 1'b1;
            next_buffer_in_din_oper = 1'b1;
        end
        // Init state;
        s_key_0 : begin
            next_p_core_din_oper = 2'b10;
            next_buffer_in_din_oper = 1'b1;
        end
        // Absorb Key words
        s_key_1 : begin
            next_p_core_oper = 3'b100;
        end
        // Absorb last key word
        s_key_2 : begin
            next_p_core_oper = 3'b100;
            next_buffer_in_din_oper = 1'b1;
        end
        // Absorb nonce
        s_enc_dec_0 : begin
            next_reg_compare_tag_rst = 1'b1;
            next_p_core_oper = 3'b101;
        end
        // Absorb last nonce word
        s_enc_dec_1 : begin
            next_p_core_oper = 3'b101;
            next_buffer_in_din_oper = 1'b1;
            next_reg_ctr_tag_size_oper = 2'b01;
        end
        // Squeeze and permute
        s_enc_dec_2 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_reg_ctr_tag_size_oper = 2'b11;
        end
        // Last squeeze and permute
        s_enc_dec_3 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_sm_p_core_din_last = 1'b1;
        end
        // Wait Key Tag to be sent
        s_enc_dec_4 : begin
            next_buffer_in_din_oper = 1'b1;
            //next_buffer_out_din_oper = 2'b10;
        end
        // Absorb AD words
        s_enc_dec_5 : begin
            next_p_core_oper = 3'b100;
        end
        // Absorb AD last word
        s_enc_dec_6 : begin
            next_p_core_oper = 3'b100;
            next_buffer_in_din_oper = 1'b1;
        end
        // Absorb PT words
        s_enc_8 : begin
            next_p_core_oper = 3'b001;
        end
        // Absorb PT last word
        s_enc_9 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_oper = 3'b001;
            next_reg_ctr_tag_size_oper = 2'b01;
        end
        // Generate Tag
        s_enc_10 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_reg_ctr_tag_size_oper = 2'b11;
        end
        // Last generate Tag
        s_enc_11 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_sm_p_core_din_last = 1'b1;
        end
        // Wait Tag to be sent
        s_enc_12 : begin
            next_buffer_in_din_oper = 1'b1;
        end
        // Absorb CT words
        s_dec_8 : begin
            next_p_core_oper = 3'b010;
        end
        // Absorb CT last word
        s_dec_9 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_oper = 3'b010;
            next_reg_ctr_tag_size_oper = 2'b01;
        end
        // Generate tag and receive other tag
        s_dec_10 : begin
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_reg_ctr_tag_size_oper = 2'b11;
        end
        // Tag has been generated first, wait for buffer
        s_dec_11 : begin
            next_p_core_din_oper = 2'b01;
            next_buffer_out_din_oper = 2'b11;
        end
        // Buffer is already full, wait for tag
        s_dec_12 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_reg_ctr_tag_size_oper = 2'b11;
        end
        // Both available perform tag comparison
        s_dec_13 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b11;
            next_buffer_out_din_oper = 2'b11;
            next_reg_compare_tag_enable = 1'b1;
        end
        // Generate last tag and receive other tag
        s_dec_14 : begin
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_sm_p_core_din_last = 1'b1;
        end
        // Last tag has been generated first, wait for buffer
        s_dec_15 : begin
            next_p_core_din_oper = 2'b01;
            next_buffer_out_din_oper = 2'b11;
        end
        // Buffer is already full, wait for last tag
        s_dec_16 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b10;
            next_p_core_oper = 3'b011;
            next_sm_p_core_din_last = 1'b1;
        end
        // Both available perform last tag comparison
        s_dec_17 : begin
            next_buffer_in_din_oper = 1'b1;
            next_p_core_din_oper = 2'b11;
            next_buffer_out_din_oper = 2'b11;
            next_reg_compare_tag_enable = 1'b1;
        end
        // Send tag comparison
        s_dec_18 : begin
            next_buffer_in_din_oper = 1'b1;
            next_dout_oper = 2'b11;
        end
        default : begin
            ;
        end
    endcase
end

always @(*) begin
    case(actual_state)
        s_reset : begin
            next_state = s_idle;
        end
        s_idle : begin
            if(inst_valid_and_ready == 1'b1) begin
                case(inst)
                    4'b0010, 4'b0011: begin
                        next_state = s_enc_dec_0;
                    end
                    4'b0100, 4'b0111: begin
                        next_state = s_key_0;
                    end
                    default : begin
                        next_state = s_reset;
                    end
                endcase
            end else begin
                next_state = s_idle;
            end
        end
        // Init state
        s_key_0 : begin
            if(p_core_din_valid_and_ready == 1'b1) begin
                next_state = s_key_1;
            end else begin
                next_state = s_key_0;
            end
        end
        // Absorb Key words
        s_key_1 : begin
            if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                next_state = s_key_2;
            end else begin
                next_state = s_key_1;
            end
        end
        // Absorb Key last word
        s_key_2 : begin
            if(p_core_din_valid_and_ready == 1'b1) begin
                next_state = s_idle;
            end else begin
                next_state = s_key_2;
            end
        end
        // Absorb nonce words
        s_enc_dec_0 : begin
            if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                next_state = s_enc_dec_1;
            end else begin
                next_state = s_enc_dec_0;
            end
        end
        // Absorb nonce last word
        s_enc_dec_1 : begin
            if(p_core_din_valid_and_ready == 1'b1) begin
                if(KEY_TAG_SIZE > 0) begin
                    next_state = s_enc_dec_2;
                end else begin
                    next_state = s_enc_dec_3;
                end
            end else begin
                next_state = s_enc_dec_1;
            end
        end
        // Squeeze and permute
        s_enc_dec_2 : begin
            if((p_core_din_valid_and_ready == 1'b1) && (is_reg_ctr_tag_size_one == 1'b1)) begin
                next_state = s_enc_dec_3;
            end else begin
                next_state = s_enc_dec_2;
            end
        end
        // Last squeeze and permute
        s_enc_dec_3 : begin
            if((p_core_din_valid_and_ready == 1'b1)) begin
                next_state = s_enc_dec_4;
            end else begin
                next_state = s_enc_dec_3;
            end
        end
        // Wait key tag to be sent
        s_enc_dec_4 : begin
            if(p_core_dout_valid_and_ready == 1'b1) begin
                next_state = s_enc_dec_5;
            end else begin
                next_state = s_enc_dec_4;
            end
        end
        // Absorb AD words
        s_enc_dec_5 : begin
            if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                next_state = s_enc_dec_6;
            end else begin
                next_state = s_enc_dec_5;
            end
        end
        // Absorb AD last word
        s_enc_dec_6 : begin
            if(p_core_din_valid_and_ready == 1'b1) begin
                if(reg_inst == 4'b0010) begin
                    next_state = s_enc_8;
                end else begin
                    next_state = s_dec_8;
                end
            end else begin
                next_state = s_enc_dec_6;
            end
        end
        // Absorb PT words
        s_enc_8 : begin
            if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                next_state = s_enc_9;
            end else begin
                next_state = s_enc_8;
            end
        end
        // Absorb PT last word
        s_enc_9 : begin
            if(p_core_din_valid_and_ready == 1'b1) begin
                if(AE_TAG_SIZE > 0) begin
                    next_state = s_enc_10;
                end else begin
                    next_state = s_enc_11;
                end
            end else begin
                next_state = s_enc_9;
            end
        end
        // Generate Tag
        s_enc_10 : begin
            if((p_core_din_valid_and_ready == 1'b1) && (is_reg_ctr_tag_size_one == 1'b1)) begin
                next_state = s_enc_11;
            end else begin
                next_state = s_enc_10;
            end
        end
        // Generate Last Tag
        s_enc_11 : begin
            if((p_core_din_valid_and_ready == 1'b1)) begin
                next_state = s_enc_12;
            end else begin
                next_state = s_enc_11;
            end
        end
        // Wait Tag to be sent
        s_enc_12 : begin
            if((dout_valid_and_ready == 1'b1) && (buffer_out_dout_last == 1'b1)) begin
                next_state = s_idle;
            end else begin
                next_state = s_enc_12;
            end
        end
        // Absorb CT words
        s_dec_8 : begin
            if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                next_state = s_dec_9;
            end else begin
                next_state = s_dec_8;
            end
        end
        // Absorb CT last word
        s_dec_9 : begin
            if(p_core_din_valid_and_ready == 1'b1) begin
                if(AE_TAG_SIZE > 0) begin
                    next_state = s_dec_10;
                end else begin
                    next_state = s_dec_14;
                end
            end else begin
                next_state = s_dec_9;
            end
        end
        // Generate last tag and receive other tag
        s_dec_10 : begin
            if((p_core_din_valid_and_ready == 1'b1) && (buffer_in_next_size_full == 1'b1)) begin
                // Both finished at the same time
                next_state = s_dec_13;
            end else if((p_core_din_valid_and_ready == 1'b1)) begin
                // Tag has been generated first, wait for buffer
                next_state = s_dec_11;
            end else if((buffer_in_next_size_full == 1'b1)) begin
                // Buffer is full and Tag still cannot be generated.
                next_state = s_dec_12;
            end else begin
                next_state = s_dec_10;
            end
        end
        // Tag has been generated first, wait for buffer
        s_dec_11 : begin
            if((buffer_in_next_size_full == 1'b1)) begin
                // Finished
                next_state = s_dec_13;
            end else begin
                next_state = s_dec_11;
            end
        end
        // Buffer is already full, wait for tag
        s_dec_12 : begin
            if((p_core_din_valid_and_ready == 1'b1)) begin
                // Finished
                next_state = s_dec_13;
            end else begin
                next_state = s_dec_12;
            end
        end
        // Both available perform tag comparison
        s_dec_13 : begin
            if((reg_compare_tag_valid_and_ready == 1'b1)) begin
                if(is_reg_ctr_tag_size_zero == 1'b1) begin
                    next_state = s_dec_14;
                end else begin
                    next_state = s_dec_10;
                end
            end else begin
                next_state = s_dec_13;
            end
        end
        // Generate last tag and receive other tag
        s_dec_14 : begin
            if((p_core_din_valid_and_ready == 1'b1) && (din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                // Both finished at the same time
                next_state = s_dec_17;
            end else if((p_core_din_valid_and_ready == 1'b1)) begin
                // Tag has been generated first, wait for buffer
                next_state = s_dec_15;
            end else if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                // Buffer is full and Tag still cannot be generated.
                next_state = s_dec_16;
            end else begin
                next_state = s_dec_14;
            end
        end
        // Tag has been generated first, wait for buffer
        s_dec_15 : begin
            if((din_valid_and_ready == 1'b1) && (din_last == 1'b1)) begin
                // Finished
                next_state = s_dec_17;
            end else begin
                next_state = s_dec_15;
            end
        end
        // Buffer is already full, wait for tag
        s_dec_16 : begin
            if((p_core_din_valid_and_ready == 1'b1)) begin
                // Finished
                next_state = s_dec_17;
            end else begin
                next_state = s_dec_16;
            end
        end
        // Both available perform tag comparison
        s_dec_17 : begin
            if((reg_compare_tag_valid_and_ready == 1'b1)) begin
                next_state = s_dec_18;
            end else begin
                next_state = s_dec_17;
            end
        end
        // Send tag comparison
        s_dec_18 : begin
            if(dout_valid_and_ready == 1'b1) begin
                next_state = s_idle;
            end else begin
                next_state = s_dec_18;
            end
        end
        default : begin
            next_state = s_reset;
        end
    endcase
end

assign buffer_in_rst = reg_buffer_in_rst;
assign buffer_in_din_oper = reg_buffer_in_din_oper;
assign inst_ready = reg_inst_ready;
assign p_core_din_oper = reg_p_core_din_oper;
assign p_core_oper = reg_p_core_oper;
assign sm_p_core_din_last = reg_sm_p_core_din_last;
assign buffer_out_rst = reg_buffer_out_rst;
assign buffer_out_din_oper = reg_buffer_out_din_oper;
assign reg_compare_tag_rst = reg_reg_compare_tag_rst;
assign reg_compare_tag_enable = reg_reg_compare_tag_enable;
assign reg_ctr_tag_size_rst = reg_reg_ctr_tag_size_rst;
assign reg_ctr_tag_size_oper = reg_reg_ctr_tag_size_oper;
assign dout_oper = reg_dout_oper;

endmodule