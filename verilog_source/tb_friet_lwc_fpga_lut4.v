/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module tb_friet_lwc_fpga_lut4
#(parameter G_PERIOD = 1000,
parameter G_MAXIMUM_LINE_LENGTH_FILES = 10000,
parameter G_MAXIMUM_BUFFER_SIZE_ARRAY = 2048,
parameter G_FNAME_AEAD_KAT = "../data_tests/LWC_AEAD_KAT_256_128.txt",
parameter G_MAXIMUM_NUMBER_OF_TESTS = 2000,
parameter G_SIMULATION_ENABLE_DUMP = 1, // 1 - True, 0 - False
parameter G_SKIP_AEAD_TEST = 0, // 1 - True, 0 - False
parameter ASYNC_RSTN = 0,  // 0 - Synchronous reset in high, 1 - Asynchrouns reset in low.
parameter G_PWIDTH = 32,
parameter G_SWIDTH = 32,
parameter G_MAXIMUM_DATA_SEGMENT_SIZE = 2**15+1,
parameter G_SEGMENT_SIZE_BITS = 16,
parameter G_HASH_SIZE_WORDS = 8,
parameter G_TAG_SIZE_WORDS = 4,
parameter G_SKIPPING_CYCLES_TESTS_MAX = 3
);

reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_key_enc;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_nonce_enc;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_pt_enc;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_ad_enc;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_output_ct_enc;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] true_output_ct_enc;

reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_key_dec;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_nonce_dec;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_ct_dec;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_input_ad_dec;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] test_output_pt_dec;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] true_output_pt_dec;

reg dut_rst;
reg [(G_PWIDTH - 1):0] dut_pdi_data;
wire dut_pdi_ready;
reg dut_pdi_valid;
reg [(G_SWIDTH - 1):0] dut_sdi_data;
wire dut_sdi_ready;
reg dut_sdi_valid;
wire [(G_PWIDTH - 1):0] dut_do_data;
wire dut_do_valid;
wire dut_do_last;
reg dut_do_ready;

reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] pdi_buffer;
integer pdi_buffer_length_bits;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] sdi_buffer;
integer sdi_buffer_length_bits;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] true_do_buffer;
integer true_do_buffer_length_bits;
reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] test_do_buffer;

reg clk;
reg test_error = 1'b0;
reg test_verification = 1'b0;

localparam tb_delay = G_PERIOD/2;
localparam tb_delay_read = 3*G_PERIOD/4;

friet_lwc_fpga_lut4
dut
(
    .rst(dut_rst),
    .clk(clk),
    .pdi_data(dut_pdi_data),
    .pdi_ready(dut_pdi_ready),
    .pdi_valid(dut_pdi_valid),
    .sdi_data(dut_sdi_data),
    .sdi_ready(dut_sdi_ready),
    .sdi_valid(dut_sdi_valid),
    .do_data(dut_do_data),
    .do_valid(dut_do_valid),
    .do_last(dut_do_last),
    .do_ready(dut_do_ready)
);

initial begin : clock_generator
    clk <= 1'b1;
    forever begin
        #(G_PERIOD/2);
        clk <= ~clk;
    end
end

task add_instruction_to_buffer;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_in;
    input integer buffer_in_length_bits;
    input integer buffer_width;
    input [7:0] instruction;
    output [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_out;
    output integer buffer_out_length_bits;
    reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] temp_buffer_out;
    integer temp_i, temp_j;
    begin
        temp_buffer_out = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        for (temp_i = 0; temp_i < buffer_in_length_bits; temp_i = temp_i + 1) begin
            temp_buffer_out[temp_i] = buffer_in[temp_i];
        end
        temp_buffer_out[temp_i +: 8] = instruction[7:0];
        temp_i = temp_i + 8;
        for (temp_j = 8; temp_j < buffer_width; temp_j = temp_j + 8) begin
            temp_buffer_out[temp_i +: 8] = 8'h00;
            temp_i = temp_i + 8;
        end
        buffer_out = temp_buffer_out;
        buffer_out_length_bits = temp_i;
    end
endtask

task add_status_to_buffer;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_in;
    input integer buffer_in_length_bits;
    input integer buffer_width;
    input [7:0] status;
    output [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_out;
    output integer buffer_out_length_bits;
    reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] temp_buffer_out;
    integer temp_i, temp_j;
    begin
        temp_buffer_out = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        for (temp_i = 0; temp_i < buffer_in_length_bits; temp_i = temp_i + 1) begin
            temp_buffer_out[temp_i] = buffer_in[temp_i];
        end
        temp_buffer_out[temp_i +: 8] = status[7:0];
        temp_i = temp_i + 8;
        for (temp_j = 8; temp_j < buffer_width; temp_j = temp_j + 8) begin
            temp_buffer_out[temp_i +: 8] = 8'h00;
            temp_i = temp_i + 8;
        end
        buffer_out = temp_buffer_out;
        buffer_out_length_bits = temp_i;
    end
endtask

task add_header_to_buffer;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_in;
    input integer buffer_in_length_bits;
    input integer buffer_width;
    input [31:0] header;
    output [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_out;
    output integer buffer_out_length_bits;
    reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] temp_buffer_out;
    integer temp_i, temp_j;
    begin
        temp_buffer_out = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        for (temp_i = 0; temp_i < buffer_in_length_bits; temp_i = temp_i + 1) begin
            temp_buffer_out[temp_i] = buffer_in[temp_i];
        end
        for (temp_j = 0; temp_j < 32; temp_j = temp_j + 8) begin
            temp_buffer_out[temp_i +: 8] = header[(32 - (temp_j + 8)) +: 8];
            temp_i = temp_i + 8;
        end
        buffer_out = temp_buffer_out;
        buffer_out_length_bits = temp_i;
    end
endtask

task add_data_to_buffer;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_in;
    input integer buffer_in_length_bits;
    input integer buffer_width;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] data_in;
    input integer data_in_iter;
    input integer data_in_length_bits;
    output [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] buffer_out;
    output integer buffer_out_length_bits;
    reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):0] temp_buffer_out;
    integer temp_i, temp_j, temp_z;
    begin
        temp_buffer_out = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        for (temp_i = 0; temp_i < buffer_in_length_bits; temp_i = temp_i + 1) begin
            temp_buffer_out[temp_i] = buffer_in[temp_i];
        end
        temp_j = 0;
        while (temp_j < data_in_length_bits) begin
            for (temp_z = 0; temp_z < buffer_width; temp_z = temp_z + 8) begin
                if(temp_j < data_in_length_bits) begin
                    temp_buffer_out[temp_i +: 8] = data_in[(temp_j+data_in_iter) +: 8];
                    temp_i = temp_i + 8;
                    temp_j = temp_j + 8;
                end else begin
                    temp_buffer_out[temp_i +: 8] = 8'h00;
                    temp_i = temp_i + 8;
                end
            end
        end
        buffer_out = temp_buffer_out;
        buffer_out_length_bits = temp_i;
    end
endtask

task send_pdi_sdi_buffers_receive_do;
    input integer skipping_cycles;
    output integer time_cycles;
    integer pdi_iter, sdi_iter, do_iter;
    integer state_pdi_sending, state_sdi_sending, state_do_receiving;
    integer state_pdi_sending_skipping, state_sdi_sending_skipping, state_do_receiving_skipping;
    reg last_block;
    integer temp_j;
    integer temp_time_cycles;
    begin
        pdi_iter = 0;
        sdi_iter = 0;
        do_iter = 0;
        state_pdi_sending = 0;
        state_sdi_sending = 0;
        state_do_receiving = 0;
        state_pdi_sending_skipping = 0;
        state_sdi_sending_skipping = 0;
        state_do_receiving_skipping = 0;
        temp_time_cycles = 0;
        while((pdi_iter < pdi_buffer_length_bits) || (sdi_iter < sdi_buffer_length_bits) || (do_iter < true_do_buffer_length_bits) || (state_do_receiving != 0) || (state_sdi_sending != 0) || (state_pdi_sending != 0)) begin
            if((pdi_iter < pdi_buffer_length_bits) || (state_pdi_sending != 0)) begin
                if(state_pdi_sending == 0) begin
                    for(temp_j = 0; (temp_j < G_PWIDTH); temp_j = temp_j + 8) begin
                        if((pdi_iter < pdi_buffer_length_bits)) begin
                            dut_pdi_data[(G_PWIDTH - (temp_j+8)) +: 8] = pdi_buffer[pdi_iter +: 8];
                            pdi_iter = pdi_iter + 8;
                        end else begin
                            dut_pdi_data[(G_PWIDTH - (temp_j+8)) +: 8] = 0;
                        end
                    end
                    dut_pdi_valid = 1;
                    if(dut_pdi_ready == 0) begin
                        state_pdi_sending = 1;
                    end else begin
                        if(skipping_cycles > 0) begin
                            state_pdi_sending = 2;
                            state_pdi_sending_skipping = 0;
                        end else begin
                            state_pdi_sending = 0;
                        end
                    end
                end else if(state_pdi_sending == 1) begin
                    if(dut_pdi_ready == 0) begin
                        state_pdi_sending = 1;
                    end else begin
                        if(skipping_cycles > 0) begin
                            state_pdi_sending = 2;
                            state_pdi_sending_skipping = 0;
                        end else begin
                            state_pdi_sending = 0;
                        end
                    end
                end else if(state_pdi_sending == 2) begin
                    dut_pdi_data = 0;
                    dut_pdi_valid = 0;
                    if(state_pdi_sending_skipping < skipping_cycles) begin
                        state_pdi_sending_skipping = state_pdi_sending_skipping + 1;
                    end else begin
                        state_pdi_sending = 0;
                    end
                end else begin
                    state_pdi_sending = 0;
                end
            end else begin
                dut_pdi_data = 0;
                dut_pdi_valid = 0;
            end
            if((sdi_iter < sdi_buffer_length_bits) || (state_sdi_sending != 0)) begin
                if(state_sdi_sending == 0) begin
                    for(temp_j = 0; (temp_j < G_SWIDTH); temp_j = temp_j + 8) begin
                        if((sdi_iter < sdi_buffer_length_bits)) begin
                            dut_sdi_data[(G_SWIDTH - (temp_j+8)) +: 8] = sdi_buffer[sdi_iter +: 8];
                            sdi_iter = sdi_iter + 8;
                        end else begin
                            dut_sdi_data[(G_SWIDTH - (temp_j+8)) +: 8] = 0;
                        end
                    end
                    dut_sdi_valid = 1;
                    if(dut_sdi_ready == 0) begin
                        state_sdi_sending = 1;
                    end else begin
                        if(skipping_cycles > 0) begin
                            state_sdi_sending = 2;
                            state_sdi_sending_skipping = 0;
                        end else begin
                            state_sdi_sending = 0;
                        end
                    end
                end else if(state_sdi_sending == 1) begin
                    if(dut_sdi_ready == 0) begin
                        state_sdi_sending = 1;
                    end else begin
                        if(skipping_cycles > 0) begin
                            state_sdi_sending = 2;
                            state_sdi_sending_skipping = 0;
                        end else begin
                            state_sdi_sending = 0;
                        end
                    end
                end else if(state_sdi_sending == 2) begin
                    dut_sdi_data = 0;
                    dut_sdi_valid = 0;
                    if(state_sdi_sending_skipping < skipping_cycles) begin
                        state_sdi_sending_skipping = state_sdi_sending_skipping + 1;
                    end else begin
                        state_sdi_sending = 0;
                    end
                end else begin
                    state_sdi_sending = 0;
                end
            end else begin
                dut_sdi_data = 0;
                dut_sdi_valid = 0;
            end
            if((do_iter < true_do_buffer_length_bits) || (state_do_receiving != 0)) begin
                if(state_do_receiving == 0) begin
                    dut_do_ready = 1;
                    if(dut_do_valid == 0) begin
                        state_do_receiving = 0;
                    end else begin
                        last_block = dut_do_last;
                        for(temp_j = 0; (temp_j < G_PWIDTH); temp_j = temp_j + 8) begin
                            test_do_buffer[do_iter +: 8] = dut_do_data[(G_PWIDTH - (temp_j + 8)) +: 8];
                            do_iter = do_iter + 8;
                        end
                        state_do_receiving = 0;
                        if(state_do_receiving_skipping < skipping_cycles) begin
                            state_do_receiving_skipping = state_do_receiving_skipping + 1;
                            state_do_receiving = 1;
                        end else begin
                            state_do_receiving_skipping = 0;
                            state_do_receiving = 0;
                        end
                    end
                end else if(state_do_receiving == 1) begin
                    dut_do_ready = 0;
                    if(state_do_receiving_skipping < skipping_cycles) begin
                        state_do_receiving_skipping = state_do_receiving_skipping + 1;
                        state_do_receiving = 1;
                    end else begin
                        state_do_receiving_skipping = 0;
                        state_do_receiving = 0;
                    end
                end
            end else begin
                dut_do_ready = 0;
            end
            #(G_PERIOD);
            temp_time_cycles = temp_time_cycles + 1;
        end
    dut_pdi_data = 0;
    dut_pdi_valid = 0;
    dut_sdi_data = 0;
    dut_sdi_valid = 0;
    dut_do_ready = 0;
    time_cycles = temp_time_cycles;
    end
endtask

task dut_aead_encrypt;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] key_in;
    input integer key_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] nonce_in;
    input integer nonce_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] associated_data_in;
    input integer associated_data_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] plaintext_in;
    input integer plaintext_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] ciphertext_out;
    input integer ciphertext_out_size_bytes;
    input integer tag_out_size_bytes;
    integer temp_key_in_amount_sent_bytes, temp_key_in_amount_remaining_bytes, temp_key_in_amount_to_send_bytes;
    integer temp_nonce_in_amount_sent_bytes, temp_nonce_in_amount_remaining_bytes, temp_nonce_in_amount_to_send_bytes;
    integer temp_associated_data_in_amount_sent_bytes, temp_associated_data_in_amount_remaining_bytes, temp_associated_data_in_amount_to_send_bytes;
    integer temp_plaintext_in_amount_sent_bytes, temp_plaintext_in_amount_remaining_bytes, temp_plaintext_in_amount_to_send_bytes;
    integer temp_ciphertext_out_amount_received_bytes, temp_ciphertext_out_amount_remaining_bytes;
    reg [31:0] temp_header;
    reg [7:0] temp_command, temp_status;
    reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] temp_ciphertext_out;
    integer temp_i, temp_j, temp_error, time_cycles;
    begin
        pdi_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        pdi_buffer_length_bits = 0;
        sdi_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        sdi_buffer_length_bits = 0;
        true_do_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        true_do_buffer_length_bits = 0;
        test_do_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        #(G_PERIOD);
        // Command to activate key
        temp_command[7:4] = 4'b0111;
        temp_command[3:0] = 4'b0000;
        add_instruction_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_command, pdi_buffer, pdi_buffer_length_bits);
        // Command to load key
        temp_command[7:4] = 4'b0100;
        temp_command[3:0] = 4'b0000;
        add_instruction_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, temp_command, sdi_buffer, sdi_buffer_length_bits);
        
        temp_key_in_amount_sent_bytes = 0;
        temp_key_in_amount_remaining_bytes = key_in_size_bytes - temp_key_in_amount_sent_bytes;
        temp_key_in_amount_to_send_bytes = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_key_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send key header
        // New key header
        // header type (key message)
        temp_header[31 : 28] = 4'b1100;
        // header incomplete block of key
        temp_header[27] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((temp_key_in_amount_remaining_bytes) > 0) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_key_in_amount_to_send_bytes;
        add_header_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, temp_header, sdi_buffer, sdi_buffer_length_bits);
        // Send key data
        add_data_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, key_in, temp_key_in_amount_sent_bytes*8, temp_key_in_amount_to_send_bytes*8, sdi_buffer, sdi_buffer_length_bits);
        temp_key_in_amount_sent_bytes = temp_key_in_amount_sent_bytes + temp_key_in_amount_to_send_bytes;
        while(temp_key_in_amount_sent_bytes < key_in_size_bytes) begin
            temp_key_in_amount_remaining_bytes = key_in_size_bytes - temp_key_in_amount_sent_bytes;
            temp_key_in_amount_to_send_bytes = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_key_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // Send key header
            // New key header
            // header type (key message)
            temp_header[31 : 28] = 4'b1100;
            // header incomplete block of key
            temp_header[27] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((temp_key_in_amount_remaining_bytes) > 0) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_key_in_amount_to_send_bytes;
            add_header_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, temp_header, sdi_buffer, sdi_buffer_length_bits);
            // Send key data
            add_data_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, key_in, temp_key_in_amount_sent_bytes*8, temp_key_in_amount_to_send_bytes*8, sdi_buffer, sdi_buffer_length_bits);
            temp_key_in_amount_sent_bytes = temp_key_in_amount_sent_bytes + temp_key_in_amount_to_send_bytes;
        end 
        // Command to start encryption
        temp_command[7:4] = 4'b0010;
        temp_command[3:0] = 4'b0000;
        add_instruction_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_command, pdi_buffer, pdi_buffer_length_bits);
        
        temp_nonce_in_amount_sent_bytes = 0;
        temp_nonce_in_amount_remaining_bytes = nonce_in_size_bytes - temp_nonce_in_amount_sent_bytes;
        temp_nonce_in_amount_to_send_bytes = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_nonce_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send nonce header
        // New nonce header
        // header type (nonce message)
        temp_header[31 : 28] = 4'b1101;
        // header incomplete block of nonce
        temp_header[27] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((associated_data_in_size_bytes == 0) && (plaintext_in_size_bytes == 0) && (temp_nonce_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = 1'b0;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_nonce_in_amount_to_send_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Send nonce data
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, nonce_in, temp_nonce_in_amount_sent_bytes*8, temp_nonce_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        temp_nonce_in_amount_sent_bytes = temp_nonce_in_amount_sent_bytes + temp_nonce_in_amount_to_send_bytes;
        while(temp_nonce_in_amount_sent_bytes < nonce_in_size_bytes) begin
            temp_nonce_in_amount_remaining_bytes = nonce_in_size_bytes - temp_nonce_in_amount_sent_bytes;
            temp_nonce_in_amount_to_send_bytes = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_nonce_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // Send nonce header
            // New nonce header
            // header type (nonce message)
            temp_header[31 : 28] = 4'b1101;
            // header incomplete block of nonce
            temp_header[27] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((associated_data_in_size_bytes == 0) && (plaintext_in_size_bytes == 0) && (temp_nonce_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = 1'b0;
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_nonce_in_amount_to_send_bytes;
            add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
            // Send nonce data
            add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, nonce_in, temp_nonce_in_amount_sent_bytes*8, temp_nonce_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
            temp_nonce_in_amount_sent_bytes = temp_nonce_in_amount_sent_bytes + temp_nonce_in_amount_to_send_bytes;
        end
        
        temp_associated_data_in_amount_sent_bytes = 0;
        temp_associated_data_in_amount_remaining_bytes = associated_data_in_size_bytes - temp_associated_data_in_amount_sent_bytes;
        temp_associated_data_in_amount_to_send_bytes = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_associated_data_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send associated data header
        // New associated header
        // header type (associated data message)
        temp_header[31 : 28] = 4'b0001;
        // header incomplete block of associated data
        temp_header[27] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((associated_data_in_size_bytes > 0) && (temp_associated_data_in_amount_sent_bytes == 0) && (plaintext_in_size_bytes == 0)) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = 1'b0;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_associated_data_in_amount_to_send_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Send associated data
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, associated_data_in, temp_associated_data_in_amount_sent_bytes*8, temp_associated_data_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        temp_associated_data_in_amount_sent_bytes = temp_associated_data_in_amount_sent_bytes + temp_associated_data_in_amount_to_send_bytes;
        while(temp_associated_data_in_amount_sent_bytes < associated_data_in_size_bytes) begin
            temp_associated_data_in_amount_remaining_bytes = associated_data_in_size_bytes - temp_associated_data_in_amount_sent_bytes;
            temp_associated_data_in_amount_to_send_bytes = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_associated_data_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // Send associated data header
            // New associated header
            // header type (associated data message)
            temp_header[31 : 28] = 4'b0001;
            // header incomplete block of associated data
            temp_header[27] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((associated_data_in_size_bytes > 0) && (temp_associated_data_in_amount_sent_bytes == 0) && (plaintext_in_size_bytes == 0)) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = 1'b0;
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_associated_data_in_amount_to_send_bytes;
            add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
            // Send associated data
            add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, associated_data_in, temp_associated_data_in_amount_sent_bytes*8, temp_associated_data_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
            temp_associated_data_in_amount_sent_bytes = temp_associated_data_in_amount_sent_bytes + temp_associated_data_in_amount_to_send_bytes;
        end
        
        temp_plaintext_in_amount_sent_bytes = 0;
        temp_ciphertext_out_amount_received_bytes = 0;
        temp_plaintext_in_amount_remaining_bytes = plaintext_in_size_bytes - temp_plaintext_in_amount_sent_bytes;
        temp_ciphertext_out_amount_remaining_bytes = ciphertext_out_size_bytes - temp_ciphertext_out_amount_received_bytes;
        temp_plaintext_in_amount_to_send_bytes = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_plaintext_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send plaintext data header
        // New plaintext header
        // header type (plaintext data message)
        temp_header[31 : 28] = 4'b0100;
        // header incomplete block of plaintext
        temp_header[27] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((plaintext_in_size_bytes > 0) && (temp_plaintext_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_plaintext_in_amount_to_send_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Receive ciphertext header
        temp_header[31 : 28] = 4'b0101;
        temp_header[27] = 1'b0;
        temp_header[26] = 1'b0;
        temp_header[25] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        temp_header[24] = 1'b0;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_plaintext_in_amount_to_send_bytes;
        add_header_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, temp_header, true_do_buffer, true_do_buffer_length_bits);
        // Send plaintext data and receive ciphertext
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, plaintext_in, temp_plaintext_in_amount_sent_bytes*8, temp_plaintext_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        temp_plaintext_in_amount_sent_bytes = temp_plaintext_in_amount_sent_bytes + temp_plaintext_in_amount_to_send_bytes;
        add_data_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, ciphertext_out, temp_ciphertext_out_amount_received_bytes*8, temp_plaintext_in_amount_to_send_bytes*8, true_do_buffer, true_do_buffer_length_bits);
        temp_ciphertext_out_amount_received_bytes = temp_ciphertext_out_amount_received_bytes + temp_plaintext_in_amount_to_send_bytes;
        while(temp_plaintext_in_amount_sent_bytes < plaintext_in_size_bytes) begin
            temp_plaintext_in_amount_remaining_bytes = plaintext_in_size_bytes - temp_plaintext_in_amount_sent_bytes;
            temp_ciphertext_out_amount_remaining_bytes = ciphertext_out_size_bytes - temp_ciphertext_out_amount_received_bytes;
            temp_plaintext_in_amount_to_send_bytes = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_plaintext_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // New plaintext header
            // header type (plaintext data message)
            temp_header[31 : 28] = 4'b0100;
            // header incomplete block of plaintext
            temp_header[27] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((plaintext_in_size_bytes > 0) && (temp_plaintext_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_plaintext_in_amount_to_send_bytes;
            add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
            // Receive ciphertext header
            temp_header[31 : 28] = 4'b0101;
            temp_header[27] = 1'b0;
            temp_header[26] = 1'b0;
            temp_header[25] = (((temp_plaintext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            temp_header[24] = 1'b0;
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_plaintext_in_amount_to_send_bytes;
            add_header_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, temp_header, true_do_buffer, true_do_buffer_length_bits);
            // Send plaintext data and receive ciphertext
            add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, plaintext_in, temp_plaintext_in_amount_sent_bytes*8, temp_plaintext_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
            temp_plaintext_in_amount_sent_bytes = temp_plaintext_in_amount_sent_bytes + temp_plaintext_in_amount_to_send_bytes;
            add_data_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, ciphertext_out, temp_ciphertext_out_amount_received_bytes*8, temp_plaintext_in_amount_to_send_bytes*8, true_do_buffer, true_do_buffer_length_bits);
            temp_ciphertext_out_amount_received_bytes = temp_ciphertext_out_amount_received_bytes + temp_plaintext_in_amount_to_send_bytes;
        end
        
        // Receive tag header
        temp_ciphertext_out_amount_remaining_bytes = ciphertext_out_size_bytes - temp_ciphertext_out_amount_received_bytes;
        temp_header[31 : 28] = 4'b1000;
        temp_header[27 : 24] = 4'b0011;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_ciphertext_out_amount_remaining_bytes;
        add_header_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, temp_header, true_do_buffer, true_do_buffer_length_bits);
        // Receive tag
        add_data_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, ciphertext_out, temp_ciphertext_out_amount_received_bytes*8, temp_ciphertext_out_amount_remaining_bytes*8, true_do_buffer, true_do_buffer_length_bits);
        
        // Receive status
        temp_status[7:0] = 8'hE0;
        add_status_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, temp_status, true_do_buffer, true_do_buffer_length_bits);
        
        // Send buffers
        #(G_PERIOD);
        for (temp_j = 0; temp_j < G_SKIPPING_CYCLES_TESTS_MAX; temp_j = temp_j + 1) begin
            send_pdi_sdi_buffers_receive_do(temp_j, time_cycles);
            #(G_PERIOD);
            if(temp_j == 0) begin
                $display("The test took %d cycles\n", time_cycles);
            end
            #(G_PERIOD);
            temp_error = 1'b0;
            for (temp_i = 0; temp_i < true_do_buffer_length_bits; temp_i = temp_i + 1) begin
                if(test_do_buffer[temp_i] != true_do_buffer[temp_i])begin
                    temp_error = 1'b1;
                end
            end
            test_verification <= 1'b1;
            #(G_PERIOD);
            if (temp_error == 1'b1) begin
                test_error <= 1'b1;
                $display("The expected output did not match the received output\n");
            end else begin
                test_error <= 1'b0;
            end
            #(G_PERIOD);
            test_error <= 1'b0;
            test_verification <= 1'b0;
            #(G_PERIOD);    
        end
    end
endtask

task dut_aead_decrypt;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] key_in;
    input integer key_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] nonce_in;
    input integer nonce_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] associated_data_in;
    input integer associated_data_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] ciphertext_in;
    input integer ciphertext_in_size_bytes;
    input [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] plaintext_out;
    input integer plaintext_out_size_bytes;
    input [7:0] true_tag_status;
    integer temp_key_in_amount_sent_bytes, temp_key_in_amount_remaining_bytes, temp_key_in_amount_to_send_bytes;
    integer temp_nonce_in_amount_sent_bytes, temp_nonce_in_amount_remaining_bytes, temp_nonce_in_amount_to_send_bytes;
    integer temp_associated_data_in_amount_sent_bytes, temp_associated_data_in_amount_remaining_bytes, temp_associated_data_in_amount_to_send_bytes;
    integer temp_ciphertext_in_amount_sent_bytes, temp_ciphertext_in_amount_remaining_bytes, temp_ciphertext_in_amount_to_send_bytes;
    integer temp_plaintext_out_amount_received_bytes, temp_plaintext_out_amount_remaining_bytes;
    reg [31:0] temp_header;
    reg [7:0] temp_command, temp_status;
    reg [(G_MAXIMUM_BUFFER_SIZE_ARRAY - 1):0] temp_plaintext_out;
    integer temp_i, temp_j, temp_error, time_cycles;
    begin
        pdi_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        pdi_buffer_length_bits = 0;
        sdi_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        sdi_buffer_length_bits = 0;
        true_do_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        true_do_buffer_length_bits = 0;
        test_do_buffer = {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
        #(G_PERIOD);
        // Command to activate key
        temp_command[7:4] = 4'b0111;
        temp_command[3:0] = 4'b0000;
        add_instruction_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_command, pdi_buffer, pdi_buffer_length_bits);
        // Command to load key
        temp_command[7:4] = 4'b0100;
        temp_command[3:0] = 4'b0000;
        add_instruction_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_PWIDTH, temp_command, sdi_buffer, sdi_buffer_length_bits);
        
        temp_key_in_amount_sent_bytes = 0;
        temp_key_in_amount_remaining_bytes = key_in_size_bytes - temp_key_in_amount_sent_bytes;
        temp_key_in_amount_to_send_bytes = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_key_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send key header
        // New key header
        // header type (key message)
        temp_header[31 : 28] = 4'b1100;
        // header incomplete block of key
        temp_header[27] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((temp_key_in_amount_remaining_bytes) > 0) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_key_in_amount_to_send_bytes;
        add_header_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, temp_header, sdi_buffer, sdi_buffer_length_bits);
        // Send key data
        add_data_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, key_in, temp_key_in_amount_sent_bytes*8, temp_key_in_amount_to_send_bytes*8, sdi_buffer, sdi_buffer_length_bits);
        temp_key_in_amount_sent_bytes = temp_key_in_amount_sent_bytes + temp_key_in_amount_to_send_bytes;
        while(temp_key_in_amount_sent_bytes < key_in_size_bytes) begin
            temp_key_in_amount_remaining_bytes = key_in_size_bytes - temp_key_in_amount_sent_bytes;
            temp_key_in_amount_to_send_bytes = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_key_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // Send key header
            // New key header
            // header type (key message)
            temp_header[31 : 28] = 4'b1100;
            // header incomplete block of key
            temp_header[27] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((temp_key_in_amount_remaining_bytes) > 0) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = (((temp_key_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_key_in_amount_to_send_bytes;
            add_header_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, temp_header, sdi_buffer, sdi_buffer_length_bits);
            // Send key data
            add_data_to_buffer(sdi_buffer, sdi_buffer_length_bits, G_SWIDTH, key_in, temp_key_in_amount_sent_bytes*8, temp_key_in_amount_to_send_bytes*8, sdi_buffer, sdi_buffer_length_bits);
            temp_key_in_amount_sent_bytes = temp_key_in_amount_sent_bytes + temp_key_in_amount_to_send_bytes;
        end 
        // Command to start decryption
        temp_command[7:4] = 4'b0011;
        temp_command[3:0] = 4'b0000;
        add_instruction_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_command, pdi_buffer, pdi_buffer_length_bits);
        
        temp_nonce_in_amount_sent_bytes = 0;
        temp_nonce_in_amount_remaining_bytes = nonce_in_size_bytes - temp_nonce_in_amount_sent_bytes;
        temp_nonce_in_amount_to_send_bytes = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_nonce_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send nonce header
        // New nonce header
        // header type (nonce message)
        temp_header[31 : 28] = 4'b1101;
        // header incomplete block of nonce
        temp_header[27] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((associated_data_in_size_bytes == 0) && (plaintext_out_size_bytes == 0) && (temp_nonce_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = 1'b0;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_nonce_in_amount_to_send_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Send nonce data
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, nonce_in, temp_nonce_in_amount_sent_bytes*8, temp_nonce_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        temp_nonce_in_amount_sent_bytes = temp_nonce_in_amount_sent_bytes + temp_nonce_in_amount_to_send_bytes;
        while(temp_nonce_in_amount_sent_bytes < nonce_in_size_bytes) begin
            temp_nonce_in_amount_remaining_bytes = nonce_in_size_bytes - temp_nonce_in_amount_sent_bytes;
            temp_nonce_in_amount_to_send_bytes = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_nonce_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // Send nonce header
            // New nonce header
            // header type (nonce message)
            temp_header[31 : 28] = 4'b1101;
            // header incomplete block of nonce
            temp_header[27] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((associated_data_in_size_bytes == 0) && (plaintext_out_size_bytes == 0) && (temp_nonce_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_nonce_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = 1'b0;
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_nonce_in_amount_to_send_bytes;
            add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
            // Send nonce data
            add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, nonce_in, temp_nonce_in_amount_sent_bytes*8, temp_nonce_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
            temp_nonce_in_amount_sent_bytes = temp_nonce_in_amount_sent_bytes + temp_nonce_in_amount_to_send_bytes;
        end
        
        temp_associated_data_in_amount_sent_bytes = 0;
        temp_associated_data_in_amount_remaining_bytes = associated_data_in_size_bytes - temp_associated_data_in_amount_sent_bytes;
        temp_associated_data_in_amount_to_send_bytes = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_associated_data_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send associated data header
        // New associated header
        // header type (associated data message)
        temp_header[31 : 28] = 4'b0001;
        // header incomplete block of associated data
        temp_header[27] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((associated_data_in_size_bytes > 0) && (temp_associated_data_in_amount_sent_bytes == 0) && (plaintext_out_size_bytes == 0)) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = 1'b0;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_associated_data_in_amount_to_send_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Send associated data
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, associated_data_in, temp_associated_data_in_amount_sent_bytes*8, temp_associated_data_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        temp_associated_data_in_amount_sent_bytes = temp_associated_data_in_amount_sent_bytes + temp_associated_data_in_amount_to_send_bytes;
        while(temp_associated_data_in_amount_sent_bytes < associated_data_in_size_bytes) begin
            temp_associated_data_in_amount_remaining_bytes = associated_data_in_size_bytes - temp_associated_data_in_amount_sent_bytes;
            temp_associated_data_in_amount_to_send_bytes = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_associated_data_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // Send associated data header
            // New associated header
            // header type (associated data message)
            temp_header[31 : 28] = 4'b0001;
            // header incomplete block of associated data
            temp_header[27] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((associated_data_in_size_bytes > 0) && (temp_associated_data_in_amount_sent_bytes == 0) && (plaintext_out_size_bytes == 0)) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_associated_data_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = 1'b0;
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_associated_data_in_amount_to_send_bytes;
            add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
            // Send associated data
            add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, associated_data_in, temp_associated_data_in_amount_sent_bytes*8, temp_associated_data_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
            temp_associated_data_in_amount_sent_bytes = temp_associated_data_in_amount_sent_bytes + temp_associated_data_in_amount_to_send_bytes;
        end
        
        temp_ciphertext_in_amount_sent_bytes = 0;
        temp_plaintext_out_amount_received_bytes = 0;
        temp_ciphertext_in_amount_remaining_bytes = plaintext_out_size_bytes - temp_ciphertext_in_amount_sent_bytes;
        temp_plaintext_out_amount_remaining_bytes = plaintext_out_size_bytes - temp_plaintext_out_amount_received_bytes;
        temp_ciphertext_in_amount_to_send_bytes = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_ciphertext_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
        // Send ciphertext data header
        // New ciphertext header
        // header type (ciphertext data message)
        temp_header[31 : 28] = 4'b0101;
        // header incomplete block of ciphertext
        temp_header[27] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
        // header end of input (active low)
        temp_header[26] = (((plaintext_out_size_bytes > 0) && (temp_ciphertext_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
        // header end of type (active high)
        temp_header[25] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        // header last (active high)
        temp_header[24] = 1'b0;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_ciphertext_in_amount_to_send_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Receive plaintext header
        temp_header[31 : 28] = 4'b0100;
        temp_header[27] = 1'b0;
        temp_header[26] = 1'b0;
        temp_header[25] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        temp_header[24] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_ciphertext_in_amount_to_send_bytes;
        add_header_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, temp_header, true_do_buffer, true_do_buffer_length_bits);
        // Send ciphertext data and receive plaintext
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, ciphertext_in, temp_ciphertext_in_amount_sent_bytes*8, temp_ciphertext_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        temp_ciphertext_in_amount_sent_bytes = temp_ciphertext_in_amount_sent_bytes + temp_ciphertext_in_amount_to_send_bytes;
        add_data_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, plaintext_out, temp_plaintext_out_amount_received_bytes*8, temp_ciphertext_in_amount_to_send_bytes*8, true_do_buffer, true_do_buffer_length_bits);
        temp_plaintext_out_amount_received_bytes = temp_plaintext_out_amount_received_bytes + temp_ciphertext_in_amount_to_send_bytes;
        while(temp_ciphertext_in_amount_sent_bytes < plaintext_out_size_bytes) begin
            temp_ciphertext_in_amount_remaining_bytes = plaintext_out_size_bytes - temp_ciphertext_in_amount_sent_bytes;
            temp_plaintext_out_amount_remaining_bytes = plaintext_out_size_bytes - temp_plaintext_out_amount_received_bytes;
            temp_ciphertext_in_amount_to_send_bytes = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_ciphertext_in_amount_remaining_bytes)) & (2**G_SEGMENT_SIZE_BITS-1);
            // New ciphertext header
            // header type (ciphertext data message)
            temp_header[31 : 28] = 4'b0101;
            // header incomplete block of ciphertext
            temp_header[27] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b1 : 1'b0);
            // header end of input (active low)
            temp_header[26] = (((plaintext_out_size_bytes > 0) && (temp_ciphertext_in_amount_sent_bytes == 0)) ? 1'b1 : 1'b0);
            // header end of type (active high)
            temp_header[25] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            // header last (active high)
            temp_header[24] = 1'b0;
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_ciphertext_in_amount_to_send_bytes;
            add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
            // Receive plaintext header
            temp_header[31 : 28] = 4'b0100;
            temp_header[27] = 1'b0;
            temp_header[26] = 1'b0;
            temp_header[25] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            temp_header[24] = (((temp_ciphertext_in_amount_remaining_bytes) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1'b0 : 1'b1);
            temp_header[23:16] = {8{1'b0}};
            temp_header[15:0] = temp_ciphertext_in_amount_to_send_bytes;
            add_header_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, temp_header, true_do_buffer, true_do_buffer_length_bits);
            // Send ciphertext data and receive plaintext
            add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, ciphertext_in, temp_ciphertext_in_amount_sent_bytes*8, temp_ciphertext_in_amount_to_send_bytes*8, pdi_buffer, pdi_buffer_length_bits);
            temp_ciphertext_in_amount_sent_bytes = temp_ciphertext_in_amount_sent_bytes + temp_ciphertext_in_amount_to_send_bytes;
            add_data_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, plaintext_out, temp_plaintext_out_amount_received_bytes*8, temp_ciphertext_in_amount_to_send_bytes*8, true_do_buffer, true_do_buffer_length_bits);
            temp_plaintext_out_amount_received_bytes = temp_plaintext_out_amount_received_bytes + temp_ciphertext_in_amount_to_send_bytes;
        end
        
        temp_ciphertext_in_amount_remaining_bytes = ciphertext_in_size_bytes - temp_ciphertext_in_amount_sent_bytes;
        // Send tag header
         // header type (tag data message)
        temp_header[31 : 28] = 4'b1000;
        // header incomplete block of tag
        temp_header[27] = 1'b0;
        // header end of input (active low)
        temp_header[26] = 1'b0;
        // header end of type (active high)
        temp_header[25] = 1'b1;
        // header last (active high)
        temp_header[24] = 1'b1;
        temp_header[23:16] = {8{1'b0}};
        temp_header[15:0] = temp_ciphertext_in_amount_remaining_bytes;
        add_header_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, temp_header, pdi_buffer, pdi_buffer_length_bits);
        // Send tag
        add_data_to_buffer(pdi_buffer, pdi_buffer_length_bits, G_PWIDTH, ciphertext_in, temp_ciphertext_in_amount_sent_bytes*8, temp_ciphertext_in_amount_remaining_bytes*8, pdi_buffer, pdi_buffer_length_bits);
        
        // Receive status
        add_status_to_buffer(true_do_buffer, true_do_buffer_length_bits, G_PWIDTH, true_tag_status, true_do_buffer, true_do_buffer_length_bits);
        
        // Send buffers
        #(G_PERIOD);
        for (temp_j = 0; temp_j < G_SKIPPING_CYCLES_TESTS_MAX; temp_j = temp_j + 1) begin
            send_pdi_sdi_buffers_receive_do(temp_j, time_cycles);
            #(G_PERIOD);
            if(temp_j == 0) begin
                $display("The test took %d cycles\n", time_cycles);
            end
            #(G_PERIOD);
            temp_error = 1'b0;
            for (temp_i = 0; temp_i < true_do_buffer_length_bits; temp_i = temp_i + 1) begin
                if(test_do_buffer[temp_i] != true_do_buffer[temp_i])begin
                    temp_error = 1'b1;
                end
            end
            test_verification <= 1'b1;
            #(G_PERIOD);
            if (temp_error == 1'b1) begin
                test_error <= 1'b1;
                $display("The expected output did not match the received output\n");
            end else begin
                test_error <= 1'b0;
            end
            #(G_PERIOD);
            test_error <= 1'b0;
            test_verification <= 1'b0;
            #(G_PERIOD);    
        end
    end
endtask


task read_until_get_character;
    input integer file_read;
    input integer character_to_be_found;
    integer temp_text;
    begin
        temp_text = $fgetc(file_read);
        while((temp_text != character_to_be_found) && (!$feof(file_read))) begin
            temp_text = $fgetc(file_read);
        end
    end
endtask

task read_ignore_character;
    input integer file_read;
    input integer character_to_be_ignored;
    output integer last_character;
    integer temp_text;
    begin
        temp_text = $fgetc(file_read);
        while((temp_text == character_to_be_ignored) && (!$feof(file_read))) begin
            temp_text = $fgetc(file_read);
        end
        last_character = temp_text;
    end
endtask

task decode_hex_character;
    input integer a;
    output [3:0] value;
    begin
        if((a >= "0") && (a <= "9")) begin
            value = a - "0";
        end else if((a >= "A") && (a <= "F")) begin
            value = a - "A" + 4'd10;
        end else if((a >= "a") && (a <= "f")) begin
            value = a - "a" + 4'd10;
        end else begin
            value = 4'b0000;
        end
    end
endtask

integer aead_file;
integer temp_text1;
integer count;
integer key_size;
integer nonce_size;
integer pt_size;
integer ad_size;
integer ct_size;
integer status_ram_file;
integer test_iterator;
reg tag_verification;
initial begin
    if(ASYNC_RSTN == 0) begin
        dut_rst <= 1'b1;
    end else begin
        dut_rst <= 1'b0;
    end
    dut_pdi_data <= {G_PWIDTH{1'b0}};
    dut_pdi_valid <= 1'b0;
    dut_sdi_data <= {G_SWIDTH{1'b0}};
    dut_sdi_valid <= 1'b0;
    dut_do_ready <= 1'b0;
    test_error <= 1'b0;
    test_verification <= 1'b0;
    test_input_key_enc   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_nonce_enc <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_pt_enc    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_ad_enc    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_output_ct_enc   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    true_output_ct_enc   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_key_dec   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_nonce_dec <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_ct_dec    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_input_ad_dec    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_output_pt_dec   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    true_output_pt_dec   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    pdi_buffer           <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    sdi_buffer           <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    test_do_buffer       <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    true_do_buffer       <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
    count = 0;
    #(G_PERIOD*10);
    if(ASYNC_RSTN == 0) begin
        dut_rst <= 1'b0;
    end else begin
        dut_rst <= 1'b1;
    end
    #(G_PERIOD);
    #(tb_delay);
    if(G_SKIP_AEAD_TEST == 0) begin
        $display("Start of the aead test");
        aead_file = $fopen(G_FNAME_AEAD_KAT, "r");
        while(!$feof(aead_file)) begin
            read_until_get_character(aead_file, "=");
            status_ram_file = $fscanf(aead_file, "%d", count);
            $display("Test number : %d", count);
            #(G_PERIOD);
            test_error <= 1'b0;
            test_verification <= 1'b0;
            test_input_key_enc   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_nonce_enc <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_pt_enc    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_ad_enc    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_output_ct_enc   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            true_output_ct_enc   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_key_dec   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_nonce_dec <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_ct_dec    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_input_ad_dec    <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            test_output_pt_dec   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            true_output_pt_dec   <= {G_MAXIMUM_BUFFER_SIZE_ARRAY{1'b0}};
            #(G_PERIOD);
            // Read key
            read_until_get_character(aead_file, "=");
            read_ignore_character(aead_file, " ", temp_text1);
            key_size = 0;
            while((temp_text1 != "\n") && (temp_text1 != 13)) begin
                decode_hex_character(temp_text1, test_input_key_enc[7:4]);
                temp_text1 = $fgetc(aead_file);
                if((temp_text1 != "\n") && (temp_text1 != 13)) begin
                    decode_hex_character(temp_text1, test_input_key_enc[3:0]);
                    temp_text1 = $fgetc(aead_file);
                end
                test_input_key_enc = {test_input_key_enc[7:0], test_input_key_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                key_size = key_size + 1;
            end
            if(key_size > 0) begin
                test_iterator = G_MAXIMUM_BUFFER_SIZE_ARRAY;
                while (test_iterator > key_size) begin
                    test_input_key_enc = {test_input_key_enc[7:0], test_input_key_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                    test_iterator = test_iterator - 1;
                end
            end
            // Read nonce
            read_until_get_character(aead_file, "=");
            read_ignore_character(aead_file, " ", temp_text1);
            nonce_size = 0;
            while((temp_text1 != "\n") && (temp_text1 != 13)) begin
                decode_hex_character(temp_text1, test_input_nonce_enc[7:4]);
                temp_text1 = $fgetc(aead_file);
                if((temp_text1 != "\n") && (temp_text1 != 13)) begin
                    decode_hex_character(temp_text1, test_input_nonce_enc[3:0]);
                    temp_text1 = $fgetc(aead_file);
                end
                test_input_nonce_enc = {test_input_nonce_enc[7:0], test_input_nonce_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                nonce_size = nonce_size + 1;
            end
            if(nonce_size > 0) begin
                test_iterator = G_MAXIMUM_BUFFER_SIZE_ARRAY;
                while (test_iterator > nonce_size) begin
                    test_input_nonce_enc = {test_input_nonce_enc[7:0], test_input_nonce_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                    test_iterator = test_iterator - 1;
                end
            end
            // Read PT
            read_until_get_character(aead_file, "=");
            read_ignore_character(aead_file, " ", temp_text1);
            pt_size = 0;
            while((temp_text1 != "\n") && (temp_text1 != 13)) begin
                decode_hex_character(temp_text1, test_input_pt_enc[7:4]);
                temp_text1 = $fgetc(aead_file);
                if((temp_text1 != "\n") && (temp_text1 != 13)) begin
                    decode_hex_character(temp_text1, test_input_pt_enc[3:0]);
                    temp_text1 = $fgetc(aead_file);
                end
                test_input_pt_enc = {test_input_pt_enc[7:0], test_input_pt_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                pt_size = pt_size + 1;
            end
            if(pt_size > 0) begin
                test_iterator = G_MAXIMUM_BUFFER_SIZE_ARRAY;
                while (test_iterator > pt_size) begin
                    test_input_pt_enc = {test_input_pt_enc[7:0], test_input_pt_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                    test_iterator = test_iterator - 1;
                end
            end
            // Read AD
            read_until_get_character(aead_file, "=");
            read_ignore_character(aead_file, " ", temp_text1);
            ad_size = 0;
            while((temp_text1 != "\n") && (temp_text1 != 13)) begin
                decode_hex_character(temp_text1, test_input_ad_enc[7:4]);
                temp_text1 = $fgetc(aead_file);
                if((temp_text1 != "\n") && (temp_text1 != 13)) begin
                    decode_hex_character(temp_text1, test_input_ad_enc[3:0]);
                    temp_text1 = $fgetc(aead_file);
                end
                test_input_ad_enc = {test_input_ad_enc[7:0], test_input_ad_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                ad_size = ad_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(ad_size > 0) begin
                test_iterator = G_MAXIMUM_BUFFER_SIZE_ARRAY;
                while (test_iterator > ad_size) begin
                    test_input_ad_enc = {test_input_ad_enc[7:0], test_input_ad_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                    test_iterator = test_iterator - 1;
                end
            end
            // Read CT
            read_until_get_character(aead_file, "=");
            read_ignore_character(aead_file, " ", temp_text1);
            ct_size = 0;
            while((temp_text1 != "\n") && (temp_text1 != 13)) begin
                decode_hex_character(temp_text1, true_output_ct_enc[7:4]);
                temp_text1 = $fgetc(aead_file);
                if((temp_text1 != "\n") && (temp_text1 != 13)) begin
                    decode_hex_character(temp_text1, true_output_ct_enc[3:0]);
                    temp_text1 = $fgetc(aead_file);
                end
                true_output_ct_enc = {true_output_ct_enc[7:0], true_output_ct_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                ct_size = ct_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(ct_size > 0) begin
                test_iterator = G_MAXIMUM_BUFFER_SIZE_ARRAY;
                while (test_iterator > ct_size) begin
                    true_output_ct_enc = {true_output_ct_enc[7:0], true_output_ct_enc[(G_MAXIMUM_BUFFER_SIZE_ARRAY-1):8]};
                    test_iterator = test_iterator - 1;
                end
            end
            dut_aead_encrypt(test_input_key_enc, key_size, test_input_nonce_enc, nonce_size, test_input_ad_enc, ad_size, test_input_pt_enc, pt_size, true_output_ct_enc, ct_size, G_TAG_SIZE_WORDS*4);
            
            // Decryption test
            test_input_key_dec = test_input_key_enc;
            test_input_nonce_dec = test_input_nonce_enc;
            test_input_ad_dec = test_input_ad_enc;
            test_input_ct_dec = true_output_ct_enc;
            true_output_pt_dec = test_input_pt_enc;
            
            dut_aead_decrypt(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, ct_size, true_output_pt_dec, pt_size, 8'hE0);
            
            // Wrong decryption test
            test_input_key_dec = test_input_key_enc;
            test_input_nonce_dec = test_input_nonce_enc;
            test_input_ad_dec = test_input_ad_enc;
            test_input_ct_dec = true_output_ct_enc;
            // Invert 1 bit
            test_input_ct_dec[pt_size*8] = ~true_output_ct_enc[pt_size*8];
            
            dut_aead_decrypt(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, ct_size, true_output_pt_dec, pt_size, 8'hF0);
            
            
            read_ignore_character(aead_file, "\n", temp_text1);
        end
        $fclose(aead_file);
        $display("End of the aead test.");
    end
    $display("End of the test.");
    disable clock_generator;
    #(G_PERIOD);
end

generate
if(G_SIMULATION_ENABLE_DUMP == 1'b1) begin
    initial
    begin
        $dumpfile("tb_friet_lwc_fpga_lut4_dump");
        $dumpvars(0, tb_friet_lwc_fpga_lut4);
        $dumpvars(0, tb_friet_lwc_fpga_lut4.dut);
    end
end
endgenerate

endmodule