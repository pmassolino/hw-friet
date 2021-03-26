/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

module friet_lwc_state_machine
#(parameter ASYNC_RSTN = 1,
parameter G_PWIDTH = 32,
parameter G_SWIDTH = 32)
(
    input wire clk,
    input wire rst,
    // PDI bus buffer
    input wire [(G_PWIDTH-1):(G_PWIDTH-4)] pdi_data,
    input wire pdi_valid_and_ready,
    output wire [1:0] pdi_oper,
    output wire sm_pdi_ready,
    output wire pdi_buffer_rst,
    // SDI bus buffer
    input wire [(G_SWIDTH-1):(G_SWIDTH-4)] sdi_data,
    input wire sdi_valid_and_ready,
    output wire sdi_oper,
    output wire sm_sdi_ready,
    output wire sdi_buffer_rst,
    // temp data
    output wire reg_buffer_dout_size_enable,
    input wire temp_valid_and_ready,
    output wire [1:0] temp_data_oper,
    output wire sm_temp_ready,
    // Cipher core
    output wire cipher_din_oper,
    input wire cipher_din_ready,
    input wire cipher_inst_ready,
    input wire cipher_dout_last,
    input wire cipher_dout_valid,
    input wire cipher_dout_ready,
    // Data size counter
    output wire [1:0] reg_data_size_oper,
    input wire is_reg_data_size_less_equal_four,
    input wire is_reg_data_size_load_zero,
    // Instruction register
    input wire [3:0] reg_inst,
    output wire reg_inst_enable,
    // Segment type register
    input wire reg_segment_end_of_type,
    output wire reg_segment_end_of_type_enable,
    // DO bus buffer
    input wire do_buffer_din_valid_and_ready,
    output wire do_buffer_rst,
    output wire [2:0] do_buffer_din_type,
    input wire do_valid_and_ready
);

reg [1:0] reg_pdi_oper, next_pdi_oper;
reg reg_sm_pdi_ready, next_sm_pdi_ready;
reg reg_pdi_buffer_rst, next_pdi_buffer_rst;
reg reg_sdi_oper, next_sdi_oper;
reg reg_sm_sdi_ready, next_sm_sdi_ready;
reg reg_sdi_buffer_rst, next_sdi_buffer_rst;
reg reg_reg_buffer_dout_size_enable, next_reg_buffer_dout_size_enable;
reg [1:0] reg_temp_data_oper, next_temp_data_oper;
reg reg_cipher_din_oper, next_cipher_din_oper;
reg reg_sm_temp_ready, next_sm_temp_ready;
reg reg_cipher_inst_valid, next_cipher_inst_valid;
reg [1:0] reg_reg_data_size_oper, next_reg_data_size_oper;
reg reg_reg_inst_enable, next_reg_inst_enable;
reg reg_reg_segment_end_of_type_enable, next_reg_segment_end_of_type_enable;
reg reg_do_buffer_rst, next_do_buffer_rst;
reg [2:0] reg_do_buffer_din_type, next_do_buffer_din_type;

localparam LWC_API_INSTRUCTION_AUTHENTICATED_ENCRYPTION = 4'b0010;
localparam LWC_API_INSTRUCTION_AUTHENTICATED_DECRYPTION = 4'b0011;
localparam LWC_API_INSTRUCTION_LOAD_KEY                 = 4'b0100;
localparam LWC_API_INSTRUCTION_ACTIVATE_KEY             = 4'b0111;
localparam LWC_API_INSTRUCTION_HASH                     = 4'b1000;

localparam s_reset = 12'h000, s_instruction = 12'h001,
           s_key_0 = 12'h100, s_key_1 = 12'h101, s_key_2 = 12'h102, s_key_3 = 12'h103, s_key_4 = 12'h104, s_key_5 = 12'h105,
           s_enc_dec_0 = 12'h200, s_enc_dec_1 = 12'h201, s_enc_dec_2 = 12'h202, s_enc_dec_3 = 12'h203, s_enc_dec_4 = 12'h204, s_enc_dec_5 = 12'h205, s_enc_dec_6 = 12'h206, s_enc_dec_7 = 12'h207, s_enc_dec_8 = 12'h208, s_enc_dec_9 = 12'h209, s_enc_dec_10 = 12'h20A, s_enc_dec_11 = 12'h20B, s_enc_dec_12 = 12'h20C, s_enc_dec_13 = 12'h20D, s_enc_dec_14 = 12'h20E, s_enc_dec_15 = 12'h20F, s_enc_dec_16 = 12'h210,
           s_enc_17 = 12'h211, s_enc_18 = 12'h212, s_enc_19 = 12'h213, s_enc_20 = 12'h214,
           s_dec_17 = 12'h311, s_dec_18 = 12'h312, s_dec_19 = 12'h313, s_dec_20 = 12'h314, s_dec_21 = 12'h315, s_dec_22 = 12'h316, s_dec_23 = 12'h317;
reg[11:0] actual_state, next_state;

generate
    if (ASYNC_RSTN != 0) begin : use_asynchrnous_reset_zero_enable
        always @(posedge clk or negedge rst) begin
            if (rst == 1'b0) begin
                actual_state <= s_reset;
                reg_pdi_oper <= 2'b00;
                reg_sm_pdi_ready <= 1'b0;
                reg_pdi_buffer_rst <= 1'b1;
                reg_sdi_oper <= 1'b0;
                reg_sm_sdi_ready <= 1'b0;
                reg_sdi_buffer_rst <= 1'b1;
                reg_reg_buffer_dout_size_enable <= 1'b0;
                reg_sm_temp_ready <= 1'b0;
                reg_temp_data_oper <= 2'b00;
                reg_cipher_din_oper <= 1'b0;
                reg_reg_data_size_oper <= 2'b00;
                reg_reg_inst_enable <= 1'b0;
                reg_reg_segment_end_of_type_enable <= 1'b0;
                reg_do_buffer_rst <= 1'b1;
                reg_do_buffer_din_type <= 3'b000;
            end else begin
                actual_state <= next_state;
                reg_pdi_oper <= next_pdi_oper;
                reg_sm_pdi_ready <= next_sm_pdi_ready;
                reg_pdi_buffer_rst <= next_pdi_buffer_rst;
                reg_sdi_oper <= next_sdi_oper;
                reg_sm_sdi_ready <= next_sm_sdi_ready;
                reg_sdi_buffer_rst <= next_sdi_buffer_rst;
                reg_reg_buffer_dout_size_enable <= next_reg_buffer_dout_size_enable;
                reg_sm_temp_ready <= next_sm_temp_ready;
                reg_temp_data_oper <= next_temp_data_oper;
                reg_cipher_din_oper <= next_cipher_din_oper;
                reg_reg_data_size_oper <= next_reg_data_size_oper;
                reg_reg_inst_enable <= next_reg_inst_enable;
                reg_reg_segment_end_of_type_enable <= next_reg_segment_end_of_type_enable;
                reg_do_buffer_rst <= next_do_buffer_rst;
                reg_do_buffer_din_type <= next_do_buffer_din_type;
            end
        end
    end else begin : use_synchrnous_reset
        always @(posedge clk) begin
            if (rst == 1'b1) begin
                actual_state <= s_reset;
                reg_pdi_oper <= 2'b00;
                reg_sm_pdi_ready <= 1'b0;
                reg_pdi_buffer_rst <= 1'b1;
                reg_sdi_oper <= 1'b0;
                reg_sm_sdi_ready <= 1'b0;
                reg_sdi_buffer_rst <= 1'b1;
                reg_reg_buffer_dout_size_enable <= 1'b0;
                reg_sm_temp_ready <= 1'b0;
                reg_temp_data_oper <= 2'b00;
                reg_cipher_din_oper <= 1'b0;
                reg_reg_data_size_oper <= 2'b00;
                reg_reg_inst_enable <= 1'b0;
                reg_reg_segment_end_of_type_enable <= 1'b0;
                reg_do_buffer_rst <= 1'b1;
                reg_do_buffer_din_type <= 3'b000;
            end else begin
                actual_state <= next_state;
                reg_pdi_oper <= next_pdi_oper;
                reg_sm_pdi_ready <= next_sm_pdi_ready;
                reg_pdi_buffer_rst <= next_pdi_buffer_rst;
                reg_sdi_oper <= next_sdi_oper;
                reg_sm_sdi_ready <= next_sm_sdi_ready;
                reg_sdi_buffer_rst <= next_sdi_buffer_rst;
                reg_reg_buffer_dout_size_enable <= next_reg_buffer_dout_size_enable;
                reg_sm_temp_ready <= next_sm_temp_ready;
                reg_temp_data_oper <= next_temp_data_oper;
                reg_cipher_din_oper <= next_cipher_din_oper;
                reg_reg_data_size_oper <= next_reg_data_size_oper;
                reg_reg_inst_enable <= next_reg_inst_enable;
                reg_reg_segment_end_of_type_enable <= next_reg_segment_end_of_type_enable;
                reg_do_buffer_rst <= next_do_buffer_rst;
                reg_do_buffer_din_type <= next_do_buffer_din_type;
            end
        end
    end
endgenerate

always @(*) begin
    next_pdi_oper = 2'b00;
    next_sm_pdi_ready = 1'b0;
    next_pdi_buffer_rst = 1'b0;
    next_sdi_oper = 1'b0;
    next_sm_sdi_ready = 1'b0;
    next_sdi_buffer_rst = 1'b0;
    next_reg_buffer_dout_size_enable = 1'b0;
    next_sm_temp_ready = 1'b0;
    next_temp_data_oper = 2'b00;
    next_cipher_din_oper = 1'b0;
    next_reg_inst_enable = 1'b0;
    next_reg_data_size_oper = 2'b00;
    next_reg_segment_end_of_type_enable = 1'b0;
    next_do_buffer_rst = 1'b0;
    next_do_buffer_din_type = 3'b000;
    case(next_state)
        s_reset : begin
            next_pdi_buffer_rst = 1'b1;
            next_sdi_buffer_rst = 1'b1;
            next_do_buffer_rst = 1'b1;
        end
        s_instruction : begin
            next_reg_inst_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
            next_pdi_oper = 2'b01;
            next_pdi_buffer_rst = 1'b1;
            next_sdi_buffer_rst = 1'b1;
            next_do_buffer_rst = 1'b1;
        end
        // Receive key instruction on SDI
        s_key_0 : begin
            next_sm_sdi_ready = 1'b1;
            next_temp_data_oper = 2'b11;
            next_do_buffer_din_type = 3'b111;
        end
        // Receive key header on SDI
        s_key_1 : begin
            next_sdi_oper = 1'b1;
            next_sm_temp_ready = 1'b1;
            next_temp_data_oper = 2'b11;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Store key header and decide how to procceed
        s_key_2 : begin
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b11;
            next_sm_temp_ready = 1'b1;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Process key until the end
        s_key_3 : begin
            next_sdi_oper = 1'b1;
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b11;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Process last key
        s_key_4 : begin
            next_temp_data_oper = 2'b11;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Insert empty data block
        s_key_5 : begin
            next_sdi_buffer_rst = 1'b1;
            next_temp_data_oper = 2'b01;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Receive nonce header on PDI
        s_enc_dec_0 : begin
            next_pdi_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_temp_data_oper = 2'b10;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Store nonce header and decide how to procceed
        s_enc_dec_1 : begin
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Process nonce until the end
        s_enc_dec_2 : begin
            next_pdi_oper = 2'b10;
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Process last nonce
        s_enc_dec_3 : begin
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Insert empty data block
        s_enc_dec_4 : begin
            next_temp_data_oper = 2'b01;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Ignore key tag
        s_enc_dec_5 : begin
            next_do_buffer_din_type = 3'b011;
        end
        // Receive associated data header on PDI
        s_enc_dec_6 : begin
            next_pdi_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_temp_data_oper = 2'b10;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Store associated data header and decide how to procceed
        s_enc_dec_7 : begin
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Process associated data until the end
        s_enc_dec_8 : begin
            next_pdi_oper = 2'b10;
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Process last associated data
        s_enc_dec_9 : begin
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Insert empty data block
        s_enc_dec_10 : begin
            next_temp_data_oper = 2'b01;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Receive plaintext/ciphertext header on PDI
        s_enc_dec_11 : begin
            next_pdi_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_temp_data_oper = 2'b10;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Send plaintext/ciphertext header
        s_enc_dec_12 : begin
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b010;
        end
        // Process plaintext/ciphertext until the end
        s_enc_dec_13 : begin
            next_pdi_oper = 2'b10;
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
        end
        // Process last plaintext/ciphertext
        s_enc_dec_14 : begin
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
        end
        // Insert empty data block
        s_enc_dec_15 : begin
            next_temp_data_oper = 2'b01;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Split into tag generatation or tag verification
        s_enc_dec_16 : begin
            next_temp_data_oper = 2'b10;
        end
        // Send tag header
        s_enc_17 : begin
            next_do_buffer_din_type = 3'b100;
        end
        // Generate tag
        s_enc_18 : begin
        end
        // Send correct execution message
        s_enc_19 : begin
            next_do_buffer_din_type = 3'b101;
        end
        // Wait to receive correct execution message 
        s_enc_20 : begin
            next_do_buffer_din_type = 3'b111;
        end
        // Receive tag header on PDI
        s_dec_17 : begin
            next_pdi_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_temp_data_oper = 2'b10;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Store tag header and decide how to procceed
        s_dec_18 : begin
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_sm_temp_ready = 1'b1;
            next_reg_data_size_oper = 2'b01;
            next_reg_segment_end_of_type_enable = 1'b1;
            next_do_buffer_din_type = 3'b111;
        end
        // Process tag until the end
        s_dec_19 : begin
            next_pdi_oper = 2'b10;
            next_reg_buffer_dout_size_enable = 1'b1;
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
        end
        // Process last tag
        s_dec_20 : begin
            next_temp_data_oper = 2'b10;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
            next_do_buffer_din_type = 3'b111;
        end
        // Insert empty data block
        s_dec_21 : begin
            next_pdi_buffer_rst = 1'b1;
            next_temp_data_oper = 2'b01;
            next_cipher_din_oper = 1'b1;
            next_reg_data_size_oper = 2'b10;
        end
        // Send verification message
        s_dec_22 : begin
            next_do_buffer_din_type = 3'b110;
        end
        // Wait to receive correct execution message 
        s_dec_23 : begin
            next_do_buffer_din_type = 3'b111;
        end
        default : begin
            ;
        end
    endcase
end

always @(*) begin
    case(actual_state)
        s_reset : begin
            next_state = s_instruction;
        end
        s_instruction : begin
            if((pdi_valid_and_ready == 1'b1) && (cipher_inst_ready == 1'b1)) begin
                case(pdi_data[(G_PWIDTH-1):(G_PWIDTH-4)])
                    LWC_API_INSTRUCTION_AUTHENTICATED_ENCRYPTION, LWC_API_INSTRUCTION_AUTHENTICATED_DECRYPTION : begin
                        next_state = s_enc_dec_0;
                    end
                    LWC_API_INSTRUCTION_ACTIVATE_KEY : begin
                        next_state = s_key_0;
                    end
                    default : begin
                        next_state = s_reset;
                    end
                endcase
            end else begin
                next_state = s_instruction;
            end
        end
        // Receive key instruction on SDI
        s_key_0 : begin
            if((sdi_valid_and_ready == 1'b1)) begin
                case(sdi_data[(G_PWIDTH-1):(G_PWIDTH-4)])
                    LWC_API_INSTRUCTION_LOAD_KEY : begin
                        next_state = s_key_1;
                    end
                    default : begin
                        next_state = s_reset;
                    end
                endcase
            end else begin
                next_state = s_key_0;
            end
        end
        // Receive key header on SDI
        s_key_1 : begin
            if(sdi_valid_and_ready == 1'b1) begin
                next_state = s_key_2;
            end else begin
                next_state = s_key_1;
            end
        end
        // Store key header and decide how to procceed
        s_key_2 : begin
            if(is_reg_data_size_load_zero == 1'b1) begin
                next_state = s_key_5;
            end else begin
                next_state = s_key_3;
            end
        end
        // Process key until the end
        s_key_3 : begin
            if((sdi_valid_and_ready == 1'b1) && (is_reg_data_size_less_equal_four == 1'b1)) begin
                next_state = s_key_4;
            end else begin
                next_state = s_key_3;
            end
        end
        // Process last key
        s_key_4 : begin
            if((temp_valid_and_ready == 1'b1)) begin
                if(reg_segment_end_of_type == 1'b1) begin
                    next_state = s_instruction;
                end else begin
                    next_state = s_key_1;
                end
            end else begin
                next_state = s_key_4;
            end
        end
        // Insert empty data block
        s_key_5 : begin
            if((temp_valid_and_ready == 1'b1)) begin
                next_state = s_instruction;
            end else begin
                next_state = s_key_5;
            end
        end
        // Receive nonce header on PDI and write on registers
        s_enc_dec_0 : begin
            if(pdi_valid_and_ready == 1'b1) begin
                next_state = s_enc_dec_1;
            end else begin
                next_state = s_enc_dec_0;
            end
        end
        // Store nonce header and decide how to procceed
        s_enc_dec_1 : begin
            if(is_reg_data_size_load_zero == 1'b1) begin
                next_state = s_enc_dec_4;
            end else begin
                next_state = s_enc_dec_2;
            end
        end
        // Process nonce until the end
        s_enc_dec_2 : begin
            if((pdi_valid_and_ready == 1'b1) && (is_reg_data_size_less_equal_four == 1'b1)) begin
                next_state = s_enc_dec_3;
            end else begin
                next_state = s_enc_dec_2;
            end
        end
        // Process last nonce
        s_enc_dec_3 : begin
            if((temp_valid_and_ready == 1'b1)) begin
                if(reg_segment_end_of_type == 1'b1) begin
                    next_state = s_enc_dec_5;
                end else begin
                    next_state = s_enc_dec_0;
                end
            end else begin
                next_state = s_enc_dec_3;
            end
        end
        // Insert empty data block
        s_enc_dec_4 : begin
            if(temp_valid_and_ready == 1'b1) begin
                next_state = s_enc_dec_5;
            end else begin
                next_state = s_enc_dec_4;
            end
        end
        // Ignore key tag from cipher core
        s_enc_dec_5 : begin
            if((cipher_dout_valid == 1'b1) && (cipher_dout_last == 1'b1)) begin
                next_state = s_enc_dec_6;
            end else begin
                next_state = s_enc_dec_5;
            end
        end
        // Receive associated data header on PDI
        s_enc_dec_6 : begin
            if(pdi_valid_and_ready == 1'b1) begin
                next_state = s_enc_dec_7;
            end else begin
                next_state = s_enc_dec_6;
            end
        end
        // Store associated data header and decide how to procceed
        s_enc_dec_7 : begin
            if(is_reg_data_size_load_zero == 1'b1) begin
                next_state = s_enc_dec_10;
            end else begin
                next_state = s_enc_dec_8;
            end
        end
        // Process associated data until the end
        s_enc_dec_8 : begin
            if((pdi_valid_and_ready == 1'b1) && (is_reg_data_size_less_equal_four == 1'b1)) begin
                next_state = s_enc_dec_9;
            end else begin
                next_state = s_enc_dec_8;
            end
        end
        // Process last associated data
        s_enc_dec_9 : begin
            if(temp_valid_and_ready == 1'b1) begin
                if(reg_segment_end_of_type == 1'b1) begin
                    next_state = s_enc_dec_11;
                end else begin
                    next_state = s_enc_dec_6;
                end
            end else begin
                next_state = s_enc_dec_9;
            end
        end
        // Insert empty data block
        s_enc_dec_10 : begin
            if(cipher_din_ready == 1'b1) begin
                next_state = s_enc_dec_11;
            end else begin
                next_state = s_enc_dec_10;
            end
        end
        // Receive plaintext/ciphertext header on PDI
        s_enc_dec_11 : begin
            if(pdi_valid_and_ready == 1'b1) begin
                next_state = s_enc_dec_12;
            end else begin
                next_state = s_enc_dec_11;
            end
        end
        // Send plaintext/ciphertext header
        s_enc_dec_12 : begin
            if(is_reg_data_size_load_zero == 1'b1) begin
                next_state = s_enc_dec_15;
            end else begin
                next_state = s_enc_dec_13;
            end
        end
        // Process plaintext/ciphertext until the end
        s_enc_dec_13 : begin
            if((pdi_valid_and_ready == 1'b1) && (is_reg_data_size_less_equal_four == 1'b1)) begin
                next_state = s_enc_dec_14;
            end else begin
                next_state = s_enc_dec_13;
            end
        end
        // Process last plaintext/ciphertext
        s_enc_dec_14 : begin
            if(temp_valid_and_ready == 1'b1) begin
                next_state = s_enc_dec_16;
            end else begin
                next_state = s_enc_dec_14;
            end
        end
        // Insert empty data block
        s_enc_dec_15 : begin
            if(cipher_din_ready == 1'b1) begin
                if(reg_inst == LWC_API_INSTRUCTION_AUTHENTICATED_ENCRYPTION) begin
                    next_state = s_enc_17;
                end else begin
                    next_state = s_dec_17;
                end
            end else begin
                next_state = s_enc_dec_15;
            end
        end
        // Wait sending last plaintext/ciphertext and split into tag generatation or tag verification
        s_enc_dec_16 : begin
            if((cipher_dout_valid == 1'b1) && (cipher_dout_ready == 1'b1)  && (cipher_dout_last == 1'b1)) begin
                if(reg_segment_end_of_type == 1'b1) begin
                    if(reg_inst == LWC_API_INSTRUCTION_AUTHENTICATED_ENCRYPTION) begin
                        next_state = s_enc_17;
                    end else begin
                        next_state = s_dec_17;
                    end
                end else begin
                    next_state = s_enc_dec_11;
                end
            end else begin
                next_state = s_enc_dec_16;
            end
        end
        // Send tag header
        s_enc_17 : begin
            if(do_buffer_din_valid_and_ready == 1'b1) begin
                next_state = s_enc_18;
            end else begin
                next_state = s_enc_17;
            end
        end
        // Generate tag
        s_enc_18 : begin
            if((cipher_dout_last == 1'b1) && (cipher_dout_valid == 1'b1) && (cipher_dout_ready == 1'b1)) begin
                next_state = s_enc_19;
            end else begin
                next_state = s_enc_18;
            end
        end
        // Send correct execution message
        s_enc_19 : begin
            if(do_buffer_din_valid_and_ready == 1'b1) begin
                next_state = s_enc_20;
            end else begin
                next_state = s_enc_19;
            end
        end
        // Wait to receive correct execution message 
        s_enc_20 : begin
            if(do_valid_and_ready == 1'b1) begin
                next_state = s_reset;
            end else begin
                next_state = s_enc_20;
            end
        end
        // Receive tag header
        s_dec_17 : begin
            if(pdi_valid_and_ready == 1'b1) begin
                next_state = s_dec_18;
            end else begin
                next_state = s_dec_17;
            end
        end
        // Store tag header and decide how to procceed
        s_dec_18 : begin
            if(is_reg_data_size_load_zero == 1'b1) begin
                next_state = s_dec_21;
            end else begin
                next_state = s_dec_19;
            end
        end
        // Process tag until the end
        s_dec_19 : begin
            if((pdi_valid_and_ready == 1'b1) && (is_reg_data_size_less_equal_four == 1'b1)) begin
                next_state = s_dec_20;
            end else begin
                next_state = s_dec_19;
            end
        end
        // Process last tag
        s_dec_20 : begin
            if(temp_valid_and_ready == 1'b1) begin
                next_state = s_dec_22;
            end else begin
                next_state = s_dec_20;
            end
        end
        // Insert empty data block
        s_dec_21 : begin
            if(cipher_din_ready == 1'b1) begin
                next_state = s_dec_22;
            end else begin
                next_state = s_dec_21;
            end
        end
        // Send correct execution message
        s_dec_22 : begin
            if(do_buffer_din_valid_and_ready == 1'b1) begin
                next_state = s_dec_23;
            end else begin
                next_state = s_dec_22;
            end
        end
        // Wait to receive correct execution message 
        s_dec_23 : begin
            if(do_valid_and_ready == 1'b1) begin
                next_state = s_reset;
            end else begin
                next_state = s_dec_23;
            end
        end
        default : begin
            next_state = s_reset;
        end
    endcase
end

assign pdi_oper = reg_pdi_oper;
assign sm_pdi_ready = reg_sm_pdi_ready;
assign pdi_buffer_rst = reg_pdi_buffer_rst;
assign sdi_oper = reg_sdi_oper;
assign sm_sdi_ready = reg_sm_sdi_ready;
assign sdi_buffer_rst = reg_sdi_buffer_rst;
assign reg_buffer_dout_size_enable = reg_reg_buffer_dout_size_enable;
assign temp_data_oper = reg_temp_data_oper;
assign cipher_din_oper = reg_cipher_din_oper;
assign sm_temp_ready = reg_sm_temp_ready;
assign reg_data_size_oper = reg_reg_data_size_oper;
assign reg_inst_enable = reg_reg_inst_enable;
assign reg_segment_end_of_type_enable = reg_reg_segment_end_of_type_enable;
assign do_buffer_rst = reg_do_buffer_rst;
assign do_buffer_din_type = reg_do_buffer_din_type;

endmodule