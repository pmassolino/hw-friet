/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
#include <stdio.h>
#include <string.h>
#include "Vfriet_stream_fpga_lut6.h"
#include "verilated.h"

#ifdef DUMP_TRACE_ON
#ifdef DUMP_TRACE_FST
#include "verilated_fst_c.h"
#else
#include "verilated_vcd_c.h"
#endif
#endif

#define MAX_SIMULATION_TICKS 1000000000   

#define G_MAXIMUM_BUFFER_SIZE_ARRAY 2048
#define G_MAXIMUM_MESSAGE_SIZE_HASH 1024
#define G_MAXIMUM_HASH_SIZE 32
#define G_MAXIMUM_KEY_SIZE 48
#define G_MAXIMUM_NONCE_SIZE 48
#define G_MAXIMUM_ASSOCIATED_DATA_SIZE 48
#define G_MAXIMUM_PLAINTEXT_SIZE 48
#define G_MAXIMUM_TAG_SIZE 48
#define G_MAXIMUM_KEY_TAG_SIZE 48
#define G_MAXIMUM_CIPHERTEXT_SIZE (G_MAXIMUM_KEY_TAG_SIZE + G_MAXIMUM_PLAINTEXT_SIZE + G_MAXIMUM_TAG_SIZE)

#define G_FNAME_AEAD_KAT "../data_tests/LWC_AEAD_KAT_256_128.txt"
#define G_FNAME_AEAD_INT "../data_tests/AEAD_INT_KAT.txt"
#define G_MAXIMUM_NUMBER_OF_TESTS 2000
#ifndef G_SKIP_KAT_AEAD_TEST
#define G_SKIP_KAT_AEAD_TEST 0 // 1 - True, 0 - False
#endif
#ifndef G_SKIP_INT_AEAD_TEST
#define G_SKIP_INT_AEAD_TEST 1 // 1 - True, 0 - False
#endif
#define ASYNC_RST 1
#define DIN_DOUT_WIDTH 32
#define SKIPPING_TESTS_MAX 32

class Testbench {
    public:
        vluint64_t time_count;
        int stop_time_enable;
        vluint64_t stop_time;
        int skipping_cycles;
        Vfriet_stream_fpga_lut6 *dut;
#ifdef DUMP_TRACE_ON
#ifdef DUMP_TRACE_FST
        VerilatedFstC* tfp;
#else
        VerilatedVcdC* tfp;
#endif
#endif
    
        Testbench(long long stop_time_value=-1, int skipping_cycles=0) {
            dut = new Vfriet_stream_fpga_lut6;
            time_count = 1;
            dut->clk = 0;
            this->skipping_cycles = skipping_cycles;
#ifdef DUMP_TRACE_ON
            if(stop_time_value != -1){
                stop_time_enable = 1;
                stop_time = stop_time_value;
            }
            else{
                stop_time_enable = 0;
                stop_time = 0;
            }
#ifdef DUMP_TRACE_FST
            tfp = new VerilatedFstC;
            dut->trace(tfp, 99);
            tfp->open("tb_friet_stream_fpga_lut6.fst");
#else
            tfp = new VerilatedVcdC;
            dut->trace(tfp, 99);
            tfp->open("tb_friet_stream_fpga_lut6.vcd");
#endif
#else
            stop_time_enable = 0;
            stop_time = 0;
#endif
        }
    
        ~Testbench(void) {
#ifdef DUMP_TRACE_ON
            tfp->flush();
            tfp->close();
            delete tfp;
            tfp = NULL;
#endif
            dut->final();
            delete dut;
            dut = NULL;
        }
        
        void reset(void) {
            int i;
            if(ASYNC_RST == 0){
                dut->arstn = 1;
            } else {
                dut->arstn = 0;
            }
            
            dut->arstn = 0;
            dut->din = 0;
            dut->din_size = 0;
            dut->din_last = 0;
            dut->din_valid = 0;
            dut->inst = 0;
            dut->inst_valid = 0;
            dut->dout_ready = 0;
            
            for(i = 0; i < 10; i++){
                clock_tick();
            }
            if(ASYNC_RST == 0){
                dut->arstn = 0;
            } else {
                dut->arstn = 1;
            }
            clock_tick();
        }
        
        void clock_tick(void){
            time_count++;
            dut->clk = 0;
            dut->eval();
#ifdef DUMP_TRACE_ON
            tfp->dump(time_count);
#endif
            time_count++;
            dut->clk = 1;
            dut->eval();
#ifdef DUMP_TRACE_ON
            tfp->dump(time_count);
            if((stop_time_enable != 0) && (time_count > stop_time)){
                tfp->flush();
                tfp->close();
                delete tfp;
                tfp = NULL;

                printf("Finishing simulation because stop time has been reached\n");
                dut->final();
                delete dut;
                dut = NULL;
                exit(1);
            }
#endif      
        }
        
        void send_instruction(int instruction){
            dut->inst = instruction;
            dut->inst_valid = 1;
            while(dut->inst_ready == 0){
                clock_tick();
            }
            clock_tick();
            dut->inst = 0;
            dut->inst_valid = 0;
        }
        
        void send_array(char * message_in, int message_in_length_bytes){
            int i, j;
            unsigned int temp_data;
            unsigned int temp_data_size;
            for(i = 0; i < (message_in_length_bytes-(DIN_DOUT_WIDTH/8));){
                temp_data = 0;
                temp_data_size = 0;
                for(j = 0; (j < DIN_DOUT_WIDTH); j += 8){
                    if((i < message_in_length_bytes)){
                        temp_data |= (((message_in[i]) & 0x00FF) << (j));
                        i++;
                        temp_data_size++;
                    }
                }
                dut->din = temp_data;
                dut->din_valid = 1;
                dut->din_size = temp_data_size;
                dut->din_last = 0;
                while(dut->din_ready == 0){
                    clock_tick();
                }
                clock_tick();
                for(j=0; j < skipping_cycles; j++){
                    dut->din = 0;
                    dut->din_valid = 0;
                    dut->din_size = 0;
                    dut->din_last = 0;
                    clock_tick();
                }
            }
            temp_data = 0;
            temp_data_size = 0;
            for(j = 0; (j < DIN_DOUT_WIDTH); j += 8){
                if((i < message_in_length_bytes)){
                    temp_data |= (((message_in[i]) & 0x00FF) << (j));
                    i++;
                    temp_data_size++;
                }
            }
            dut->din = temp_data;
            dut->din_valid = 1;
            dut->din_size = temp_data_size;
            dut->din_last = 1;
            while(dut->din_ready == 0){
                clock_tick();
            }
            clock_tick();
            for(j=0; j < skipping_cycles; j++){
                dut->din = 0;
                dut->din_valid = 0;
                dut->din_size = 0;
                dut->din_last = 0;
                clock_tick();
            }
            dut->din = 0;
            dut->din_valid = 0;
            dut->din_size = 0;
            dut->din_last = 0;
        }
        
        void receive_array(char * message_out, int maximum_message_out_length_bytes){
            int i, j;
            unsigned int temp_data;
            unsigned int temp_data_size;
            int last_block;
            
            last_block = 0;
            for(i = 0; (i < maximum_message_out_length_bytes) && (last_block == 0);){
                dut->dout_ready = 1;
                while(dut->dout_valid == 0){
                    clock_tick();
                }
                temp_data = dut->dout;
                temp_data_size = 0;
                last_block = dut->dout_last;
                for(j = 0; (j < DIN_DOUT_WIDTH); j += 8){
                    if(temp_data_size < dut->dout_size){
                        message_out[i] = (temp_data >> j) & 0x00FF;
                        i++;
                        temp_data_size++;
                    }
                }
                clock_tick();
                for(j=0; j < skipping_cycles; j++){
                    dut->dout_ready = 0;
                    clock_tick();
                }
            }
            dut->dout_ready = 0;
        }
        
        void send_receive_array(char * message_in, int message_in_length_bytes, char * message_out, int message_out_length_bytes){
            int i, j, z;
            unsigned int temp_data;
            unsigned int temp_data_size;
            int last_block;
            int state_sending = 0;
            int state_sending_skipping = 0;
            int state_receiving = 0;
            int state_receiving_skipping = 0;
            int first_message_sent = 1;
            int last_message_sent = 1;
            i = 0;
            z = 0;
            while((i < message_in_length_bytes) || (z < message_out_length_bytes) || (first_message_sent == 1) || (last_message_sent == 1) || (state_receiving != 0) || (state_sending != 0)){
                if((i < message_in_length_bytes) || (first_message_sent == 1) || (last_message_sent == 1) || (state_sending != 0)){
                    if(state_sending == 0){
                        temp_data = 0;
                        temp_data_size = 0;
                        if(i < (message_in_length_bytes-(DIN_DOUT_WIDTH/8))){
                            dut->din_last = 0;
                        }
                        else{
                            dut->din_last = 1;
                            last_message_sent = 0;
                        }
                        for(j = 0; (j < DIN_DOUT_WIDTH); j += 8){
                            if((i < message_in_length_bytes)){
                                temp_data |= (((message_in[i]) & 0x00FF) << (j));
                                i++;
                                temp_data_size++;
                            }
                        }
                        dut->din = temp_data;
                        dut->din_valid = 1;
                        dut->din_size = temp_data_size;
                        if(dut->din_ready == 0){
                            state_sending = 1;
                        }
                        else{
                            if(skipping_cycles > 0){
                                state_sending = 2;
                                state_sending_skipping = 0;
                            } else {
                                state_sending = 0;
                                first_message_sent = 0;
                            }
                        }
                    }
                    else if(state_sending == 1){
                        if(dut->din_ready == 0){
                            state_sending = 1;
                        }
                        else{
                            if(skipping_cycles > 0){
                                state_sending = 2;
                                state_sending_skipping = 0;
                            } else {
                                state_sending = 0;
                                first_message_sent = 0;
                            }
                        }
                    }
                    else if(state_sending == 2){
                        dut->din = 0;
                        dut->din_valid = 0;
                        dut->din_size = 0;
                        dut->din_last = 0;
                        if(state_sending_skipping < skipping_cycles){
                            state_sending_skipping++;
                        } else{
                            state_sending = 0;
                            first_message_sent = 0;
                        }
                    }
                    else{
                        state_sending = 0;
                    }
                }
                else{
                    dut->din = 0;
                    dut->din_valid = 0;
                    dut->din_size = 0;
                    dut->din_last = 0;
                }
                if((z < message_out_length_bytes) || (state_receiving != 0)){
                    if(state_receiving == 0){
                        dut->dout_ready = 1;
                        if(dut->dout_valid == 0){
                            state_receiving = 0;
                        }
                        else{
                            temp_data = dut->dout;
                            temp_data_size = 0;
                            last_block = dut->dout_last;
                            for(j = 0; (j < DIN_DOUT_WIDTH); j += 8){
                                if(temp_data_size < dut->dout_size){
                                    message_out[z] = (temp_data >> j) & 0xFF;
                                    z++;
                                    temp_data_size++;
                                }
                            }
                            state_receiving = 0;
                            if(state_receiving_skipping < skipping_cycles){
                                state_receiving_skipping++;
                                state_receiving = 1;
                            } else{
                                state_receiving_skipping = 0;
                                state_receiving = 0;
                            }
                        }
                    }
                    else if(state_receiving == 1){
                        dut->dout_ready = 0;
                        if(state_receiving_skipping < skipping_cycles){
                            state_receiving_skipping++;
                            state_receiving = 1;
                        } else{
                            state_receiving_skipping = 0;
                            state_receiving = 0;
                        }
                    }
                }
                clock_tick();
            }
            dut->din = 0;
            dut->din_valid = 0;
            dut->din_size = 0;
            dut->din_last = 0;
            dut->dout_ready = 0;
        }
        
        void dut_hash(char * message_in, int message_in_length_bytes, char * hash_out, int *hash_out_length_bytes){
            int temp_header, temp_status, temp_instruction;
            // Hash instruction
            temp_instruction = 0x8;
            send_instruction(temp_instruction);
            send_array(message_in, message_in_length_bytes);
            receive_array(hash_out, 64);
            clock_tick();
        }
        
        
        void dut_aead_enc(char * key_in, int key_in_length_bytes, char * nonce_in, int nonce_in_length_bytes, char * associated_data_in, int associated_data_in_length_bytes, char * plaintext_in, int plaintext_in_length_bytes, char * ciphertext_out, int ciphertext_out_length_bytes, char * key_tag_out, int key_tag_out_lenth_bytes){
            int temp_header, temp_status, temp_instruction;
            
            // Activate key instruction
            temp_instruction = 0x7;
            send_instruction(temp_instruction);
            
            // Send key
            send_array(key_in, key_in_length_bytes);
            
            // Start encryption instruction
            temp_instruction = 0x2;
            send_instruction(temp_instruction);
            // Send nonce data
            send_array(nonce_in, nonce_in_length_bytes);
            // Receive key tag
            receive_array(&key_tag_out[0], key_tag_out_lenth_bytes);
            // Send associated data
            send_array(associated_data_in, associated_data_in_length_bytes);
            
            // Send plaintext
            // Receive ciphertext
            send_receive_array(plaintext_in, plaintext_in_length_bytes, ciphertext_out, plaintext_in_length_bytes);
            // Receive tag
            receive_array(&ciphertext_out[plaintext_in_length_bytes], ciphertext_out_length_bytes-plaintext_in_length_bytes);
            clock_tick();
        }
        
        void dut_aead_dec(char * key_in, int key_in_length_bytes, char * nonce_in, int nonce_in_length_bytes, char * associated_data_in, int associated_data_in_length_bytes, char * ciphertext_in, int ciphertext_in_length_bytes, char * plaintext_out, int plaintext_out_length_bytes, char * key_tag_out, int key_tag_out_lenth_bytes){
            int temp_header, temp_status, temp_instruction;
            
            // Activate key instruction
            temp_instruction = 0x7;
            send_instruction(temp_instruction);
            
            // Send key
            send_array(key_in, key_in_length_bytes);
            
            // Start decryption instruction
            temp_instruction = 0x3;
            send_instruction(temp_instruction);
            // Send nonce data
            send_array(nonce_in, nonce_in_length_bytes);
            // Receive key tag
            receive_array(&key_tag_out[0], key_tag_out_lenth_bytes);
            // Send associated data
            send_array(associated_data_in, associated_data_in_length_bytes);
            
            // Send ciphertext
            // Receive plaintext
            send_receive_array(ciphertext_in, plaintext_out_length_bytes, plaintext_out, plaintext_out_length_bytes);
            // Send tag and receive status
            send_receive_array(&ciphertext_in[plaintext_out_length_bytes], ciphertext_in_length_bytes-plaintext_out_length_bytes, &plaintext_out[plaintext_out_length_bytes], 1);
            clock_tick();
        }
};

void read_until_get_character(FILE * file_read, char character_to_be_found){
    char temp_char;
    temp_char = fgetc(file_read);
    while((temp_char != character_to_be_found) && (!feof(file_read))){
        temp_char = fgetc(file_read);
    }
}

void read_ignore_character(FILE * file_read, char character_to_be_ignored, char * last_character){
    char temp_char;
    temp_char = fgetc(file_read);
    while((temp_char == character_to_be_ignored) && (!feof(file_read))){
        temp_char = fgetc(file_read);
    }
    *last_character = temp_char;
}

void decode_hex_character(char t1, char t2, char * out){
    if((t1 >= '0') && (t1 <= '9')){
        *out = t1 - '0';
    } else {
        *out = t1 - 'A' + 10;
    }
    *out = *out << 4;
    if((t2 >= '0') && (t2 <= '9')){
        *out += t2 - '0';
    } else {
        *out += t2 - 'A' + 10;
    }
}

int main(int argc, char **argv) {
    FILE * aead_file;
    char buffer_read [G_MAXIMUM_BUFFER_SIZE_ARRAY];
    char temp_char1, temp_char2, temp_value;
    int count;
    int key_size, nonce_size, pt_size, ad_size, ct_size, key_tag_size;
    int test_verification;
    int test_error;
    int core_status;
    int i, j;
    char test_input_message      [G_MAXIMUM_MESSAGE_SIZE_HASH];
    char test_output_hash        [G_MAXIMUM_HASH_SIZE];
    char true_output_hash        [G_MAXIMUM_HASH_SIZE];
    char test_input_key_enc      [G_MAXIMUM_KEY_SIZE];
    char test_input_nonce_enc    [G_MAXIMUM_NONCE_SIZE];
    char test_input_pt_enc       [G_MAXIMUM_PLAINTEXT_SIZE];
    char test_input_ad_enc       [G_MAXIMUM_ASSOCIATED_DATA_SIZE];
    char test_output_key_tag_enc [G_MAXIMUM_KEY_TAG_SIZE];
    char test_output_ct_enc      [G_MAXIMUM_CIPHERTEXT_SIZE];
    char true_output_ct_enc      [G_MAXIMUM_CIPHERTEXT_SIZE];
    char test_input_key_dec      [G_MAXIMUM_KEY_SIZE];
    char test_input_nonce_dec    [G_MAXIMUM_NONCE_SIZE];
    char test_input_ct_dec       [G_MAXIMUM_CIPHERTEXT_SIZE];
    char test_input_ad_dec       [G_MAXIMUM_ASSOCIATED_DATA_SIZE];
    char test_output_key_tag_dec [G_MAXIMUM_KEY_TAG_SIZE];
    char test_output_pt_dec      [G_MAXIMUM_PLAINTEXT_SIZE+1];
    char true_output_pt_dec      [G_MAXIMUM_PLAINTEXT_SIZE];
    Testbench * tb;
    
    // Call commandArgs first!
    Verilated::commandArgs(argc, argv);
#ifdef DUMP_TRACE_ON
    Verilated::traceEverOn(true);
#endif
    
    // Instantiate our design
    tb = new Testbench(MAX_SIMULATION_TICKS, 0);
    
    test_verification = 0;
    test_error = 0;
    memset(test_input_message, 0, sizeof(char)*G_MAXIMUM_MESSAGE_SIZE_HASH);
    memset(test_output_hash, 0, sizeof(char)*G_MAXIMUM_HASH_SIZE);
    memset(true_output_hash, 0, sizeof(char)*G_MAXIMUM_HASH_SIZE);
    memset(test_input_key_enc, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
    memset(test_input_nonce_enc, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
    memset(test_input_pt_enc, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
    memset(test_input_ad_enc, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
    memset(test_output_key_tag_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(true_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(test_input_key_dec, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
    memset(test_input_nonce_dec, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
    memset(test_input_ct_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(test_input_ad_dec, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
    memset(test_output_key_tag_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE+1);
    memset(true_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
    
    tb->reset();
    
    count = 0;
    test_error = 0;
    #if G_SKIP_KAT_AEAD_TEST == 0
        printf("Start of the aead test\n");
        aead_file = fopen(G_FNAME_AEAD_KAT, "r");
        if(!aead_file != 0){
            printf("Could not open file %s\n", G_FNAME_AEAD_KAT);
        }
        while(!feof(aead_file) && (count < G_MAXIMUM_NUMBER_OF_TESTS) && (test_error == 0)) {
            read_until_get_character(aead_file, '=');
            fscanf(aead_file, "%d", &count);
            printf("Test number %d\n", count);
            memset(test_input_key_enc, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
            memset(test_input_nonce_enc, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
            memset(test_input_pt_enc, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
            memset(test_input_ad_enc, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
            memset(test_output_key_tag_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(true_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_input_key_dec, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
            memset(test_input_nonce_dec, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
            memset(test_input_ct_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_input_ad_dec, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
            memset(test_output_key_tag_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE+1);
            memset(true_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
            
            // Read key
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            key_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_key_enc[key_size]);
                temp_char1 = fgetc(aead_file);
                key_size++;
            }
            // Read nonce
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            nonce_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_nonce_enc[nonce_size]);
                temp_char1 = fgetc(aead_file);
                nonce_size++;
            }
            // Read PT
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            pt_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_pt_enc[pt_size]);
                temp_char1 = fgetc(aead_file);
                pt_size++;
            }
            // Read AD
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            ad_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_ad_enc[ad_size]);
                temp_char1 = fgetc(aead_file);
                ad_size++;
            }
            // Read CT
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            ct_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &true_output_ct_enc[ct_size]);
                temp_char1 = fgetc(aead_file);
                ct_size++;
            }
            
            key_tag_size = 16;
            
            for(j = 0; (j < SKIPPING_TESTS_MAX) && (test_error == 0); j++){
                tb->skipping_cycles = j;
                //printf("Skipping cycles = %d\n", j);
                memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            
                // Perform the encryption procedure
                tb->dut_aead_enc(test_input_key_enc, key_size, test_input_nonce_enc, nonce_size, test_input_ad_enc, ad_size, test_input_pt_enc, pt_size, test_output_ct_enc, ct_size, test_output_key_tag_enc, key_tag_size);
                
                // Compare aead output
                if (memcmp(true_output_ct_enc, test_output_ct_enc, ct_size) == 0) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Computed values during encryption do not match expected ones\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Expected ciphertext: ");
                    for(i = 0; i < ct_size; i++){
                        printf("%02x", (true_output_ct_enc[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received ciphertext: ");
                    for(i = 0; i < ct_size; i++){
                        printf("%02x", (test_output_ct_enc[i] & 0x00FF));
                    }
                    printf("\n");
                }
            }
            
            // Decryption correct tag
            
            memcpy(test_input_key_dec, test_input_key_enc, key_size);
            memcpy(test_input_nonce_dec, test_input_nonce_enc, nonce_size);
            memcpy(test_input_ad_dec, test_input_ad_enc, ad_size);
            memcpy(test_input_ct_dec, true_output_ct_enc, ct_size);
            memcpy(true_output_pt_dec, test_input_pt_enc, pt_size);
            
            for(j = 0; (j < SKIPPING_TESTS_MAX) && (test_error == 0); j++){
                tb->skipping_cycles = j;
                //printf("Skipping cycles = %d\n", j);
                memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE + 1);
                
                // Perform the decryption procedure
                tb->dut_aead_dec(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, ct_size, test_output_pt_dec, pt_size, test_output_key_tag_dec, key_tag_size);
                
                // Compare aead output
                if (memcmp(true_output_pt_dec, test_output_pt_dec, pt_size) == 0) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Computed values during decryption do not match expected ones\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Expected plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (true_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (test_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                }
                if (test_output_pt_dec[pt_size] == 0x0E) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Core status do not match expected one for correct tag during decryption\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Received status: %x \n", test_output_pt_dec[pt_size] & 0x00FF);
                    printf("Expected status: %x \n", 0x0E & 0x00FF);
                }
            }
            
            // Decryption incorrect tag
            
            memcpy(test_input_key_dec, test_input_key_enc, key_size);
            memcpy(test_input_nonce_dec, test_input_nonce_enc, nonce_size);
            memcpy(test_input_ad_dec, test_input_ad_enc, ad_size);
            memcpy(test_input_ct_dec, true_output_ct_enc, ct_size);
            memcpy(true_output_pt_dec, test_input_pt_enc, pt_size);
            
            test_input_ct_dec[pt_size] = test_input_ct_dec[pt_size] ^ 0xFF;
            
            for(j = 0; (j < SKIPPING_TESTS_MAX) && (test_error == 0); j++){
                tb->skipping_cycles = j;
                //printf("Skipping cycles = %d\n", j);
                memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE + 1);
                
                // Perform the decryption procedure
                tb->dut_aead_dec(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, ct_size, test_output_pt_dec, pt_size, test_output_key_tag_dec, key_tag_size);
                
                // Compare aead output
                if (memcmp(true_output_pt_dec, test_output_pt_dec, pt_size) == 0) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Computed values during decryption do not match expected ones\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Expected plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (true_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (test_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                }
                if (test_output_pt_dec[pt_size] == 0x0F) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Core status do not match expected one for correct tag during decryption\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Received status: %x \n", test_output_pt_dec[pt_size] & 0x00FF);
                    printf("Expected status: %x \n", 0x0F & 0x00FF);
                }
            }
            
            tb->clock_tick();
            read_ignore_character(aead_file, '\n', &temp_char1);
        }
        fclose(aead_file);
        printf("End of the aead test\n");
    #endif
    
    #if G_SKIP_INT_AEAD_TEST == 0
        printf("Start of the internal aead test\n");
        aead_file = fopen(G_FNAME_AEAD_INT, "r");
        if(!aead_file != 0){
            printf("Could not open file %s\n", G_FNAME_AEAD_INT);
        }
        while(!feof(aead_file) && (count < G_MAXIMUM_NUMBER_OF_TESTS) && (test_error == 0)) {
            read_until_get_character(aead_file, '=');
            fscanf(aead_file, "%d", &count);
            printf("Test number %d\n", count);
            memset(test_input_key_enc, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
            memset(test_input_nonce_enc, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
            memset(test_input_pt_enc, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
            memset(test_input_ad_enc, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
            memset(test_output_key_tag_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(true_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_input_key_dec, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
            memset(test_input_nonce_dec, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
            memset(test_input_ct_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_input_ad_dec, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
            memset(test_output_key_tag_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE+1);
            memset(true_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
            
            // Read key
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            key_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_key_enc[key_size]);
                temp_char1 = fgetc(aead_file);
                key_size++;
            }
            // Read nonce
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            nonce_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_nonce_enc[nonce_size]);
                temp_char1 = fgetc(aead_file);
                nonce_size++;
            }
            // Read PT
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            pt_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_pt_enc[pt_size]);
                temp_char1 = fgetc(aead_file);
                pt_size++;
            }
            // Read AD
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            ad_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &test_input_ad_enc[ad_size]);
                temp_char1 = fgetc(aead_file);
                ad_size++;
            }
            // Read CT
            read_until_get_character(aead_file, '=');
            read_ignore_character(aead_file, ' ', &temp_char1);
            ct_size = 0;
            while(temp_char1 != '\n') {
                temp_char2 = fgetc(aead_file);
                decode_hex_character(temp_char1, temp_char2, &true_output_ct_enc[ct_size]);
                temp_char1 = fgetc(aead_file);
                ct_size++;
            }
            
            key_tag_size = G_MAXIMUM_KEY_TAG_SIZE;
            
            for(j = 0; (j < SKIPPING_TESTS_MAX) && (test_error == 0); j++){
                tb->skipping_cycles = j;
                //printf("Skipping cycles = %d\n", j);
                memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
                
                // Perform the encryption procedure
                tb->dut_aead_enc(test_input_key_enc, key_size, test_input_nonce_enc, nonce_size, test_input_ad_enc, ad_size, test_input_pt_enc, pt_size, test_output_ct_enc, ct_size, test_output_key_tag_enc, key_tag_size);
                
                // Compare aead output
                if ((memcmp(&true_output_ct_enc[key_tag_size], test_output_ct_enc, ct_size) == 0) && (memcmp(true_output_ct_enc, test_output_key_tag_enc, key_tag_size) == 0)) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Computed values during encryption do not match expected ones\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Expected ciphertext: ");
                    for(i = 0; i < ct_size; i++){
                        printf("%02x", (true_output_ct_enc[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received ciphertext: ");
                    for(i = 0; i < ct_size; i++){
                        printf("%02x", (test_output_ct_enc[i] & 0x00FF));
                    }
                    printf("\n");
                }
            }
            
            // Decryption correct tag
            
            memcpy(test_input_key_dec, test_input_key_enc, key_size);
            memcpy(test_input_nonce_dec, test_input_nonce_enc, nonce_size);
            memcpy(test_input_ad_dec, test_input_ad_enc, ad_size);
            memcpy(test_input_ct_dec, true_output_ct_enc, ct_size);
            memcpy(true_output_pt_dec, test_input_pt_enc, pt_size);
            
            for(j = 0; (j < SKIPPING_TESTS_MAX) && (test_error == 0); j++){
                tb->skipping_cycles = j;
                //printf("Skipping cycles = %d\n", j);
                memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE + 1);
                
                // Perform the decryption procedure
                tb->dut_aead_dec(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, &test_input_ct_dec[key_tag_size], ct_size-key_tag_size, test_output_pt_dec, pt_size, test_output_key_tag_dec, key_tag_size);
                
                // Compare aead output
                if ((memcmp(true_output_pt_dec, test_output_pt_dec, pt_size) == 0) && (memcmp(true_output_ct_enc, test_output_key_tag_dec, key_tag_size) == 0)) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Computed values during decryption do not match expected ones\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Expected key tag: ");
                    for(i = 0; i < key_tag_size; i++){
                        printf("%02x", (true_output_ct_enc[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received key tag: ");
                    for(i = 0; i < key_tag_size; i++){
                        printf("%02x", (test_output_key_tag_dec[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Expected plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (true_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (test_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                }
                if (test_output_pt_dec[pt_size] == 0x0E) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Core status do not match expected one for correct tag during decryption\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Received status: %x \n", test_output_pt_dec[pt_size] & 0x00FF);
                    printf("Expected status: %x \n", 0x0E & 0x00FF);
                }
            }
            
            // Decryption incorrect tag
            
            memcpy(test_input_key_dec, test_input_key_enc, key_size);
            memcpy(test_input_nonce_dec, test_input_nonce_enc, nonce_size);
            memcpy(test_input_ad_dec, test_input_ad_enc, ad_size);
            memcpy(test_input_ct_dec, true_output_ct_enc, ct_size);
            memcpy(true_output_pt_dec, test_input_pt_enc, pt_size);
            
            test_input_ct_dec[key_tag_size+pt_size] = test_input_ct_dec[key_tag_size+pt_size] ^ 0xFF;
            
            for(j = 0; (j < SKIPPING_TESTS_MAX) && (test_error == 0); j++){
                tb->skipping_cycles = j;
                //printf("Skipping cycles = %d\n", j);
                memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE + 1);
                
                // Perform the decryption procedure
                tb->dut_aead_dec(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, &test_input_ct_dec[key_tag_size], ct_size-key_tag_size, test_output_pt_dec, pt_size, test_output_key_tag_dec, key_tag_size);
                
                // Compare aead output
                if ((memcmp(true_output_pt_dec, test_output_pt_dec, pt_size) == 0) && (memcmp(true_output_ct_enc, test_output_key_tag_dec, key_tag_size) == 0)) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Computed values during decryption do not match expected ones\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Expected key tag: ");
                    for(i = 0; i < key_tag_size; i++){
                        printf("%02x", (true_output_ct_enc[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received key tag: ");
                    for(i = 0; i < key_tag_size; i++){
                        printf("%02x", (test_output_key_tag_dec[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Expected plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (true_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received plaintext: ");
                    for(i = 0; i < pt_size; i++){
                        printf("%02x", (test_output_pt_dec[i] & 0x00FF));
                    }
                    printf("\n");
                }
                if (test_output_pt_dec[pt_size] == 0x0F) {
                    test_error += 0;
                } else {
                    test_error += 1;
                    printf("Core status do not match expected one for correct tag during decryption\n");
                    printf("Test number : %d\n", count);
                    printf("Skipping value : %d\n", j);
                    printf("Received status: %x \n", test_output_pt_dec[pt_size] & 0x00FF);
                    printf("Expected status: %x \n", 0x0F & 0x00FF);
                }
            }
            
            tb->clock_tick();
            read_ignore_character(aead_file, '\n', &temp_char1);
        }
        fclose(aead_file);
        printf("End of the aead test\n");
    #endif
    
    delete tb;
}