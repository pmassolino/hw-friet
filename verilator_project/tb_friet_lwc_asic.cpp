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
#include "Vfriet_lwc_asic.h"
#include "verilated.h"

#ifdef DUMP_TRACE_ON
#ifdef DUMP_TRACE_FST
#include "verilated_fst_c.h"
#else
#include "verilated_vcd_c.h"
#endif
#endif

#define MAX_SIMULATION_TICKS 100000000

#define G_MAXIMUM_BUFFER_SIZE_ARRAY 2048
#define G_MAXIMUM_MESSAGE_SIZE_HASH 1024
#define G_MAXIMUM_HASH_SIZE 32
#define G_MAXIMUM_KEY_SIZE 32
#define G_MAXIMUM_NONCE_SIZE 16
#define G_MAXIMUM_ASSOCIATED_DATA_SIZE 32
#define G_MAXIMUM_PLAINTEXT_SIZE 32
#define G_MAXIMUM_TAG_SIZE 16
#define G_MAXIMUM_CIPHERTEXT_SIZE (G_MAXIMUM_PLAINTEXT_SIZE + G_MAXIMUM_TAG_SIZE)
#define G_MAXIMUM_DATA_SEGMENT_SIZE ((1U << 15)+1)

#define G_FNAME_AEAD_KAT "../data_tests/LWC_AEAD_KAT_256_128.txt"
#define G_MAXIMUM_NUMBER_OF_TESTS 2000
#define G_SKIP_AEAD_TEST 0 // 1 - True, 0 - False
#define PRINT_CURRENT_TEST_NUMBER 1
#define ASYNC_RST 0
#define G_PWIDTH 32
#define G_SWIDTH 32
#define G_PWIDTH_MASK ((1UL << (G_PWIDTH)) - 1)
#define G_SWIDTH_MASK ((1UL << (G_SWIDTH)) - 1)
#define G_SEGMENT_DATA_SIZE_MASK ((1U << 16)-1)

#define SKIPPING_TESTS_MAX 40


class Testbench {
    public:
        vluint64_t time_count;
        int stop_time_enable;
        vluint64_t stop_time;
        Vfriet_lwc_asic *dut;
#ifdef DUMP_TRACE_ON
#ifdef DUMP_TRACE_FST
        VerilatedFstC* tfp;
#else
        VerilatedVcdC* tfp;
#endif
#endif
    
        Testbench(long long stop_time_value=-1) {
            dut = new Vfriet_lwc_asic;
            time_count = 1;
            dut->clk = 0;
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
            tfp->open("tb_friet_lwc_asic.fst");
#else
            tfp = new VerilatedVcdC;
            dut->trace(tfp, 99);
            tfp->open("tb_friet_lwc_asic.vcd");
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
                dut->rst = 1;
            } else {
                dut->rst = 0;
            }
            
            dut->pdi_data = 0;
            dut->pdi_valid = 0;
            dut->sdi_data = 0;
            dut->sdi_valid = 0;
            dut->do_ready = 0;
            
            for(i = 0; i < 10; i++){
                clock_tick();
            }
            if(ASYNC_RST == 0){
                dut->rst = 0;
            } else {
                dut->rst = 1;
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
        
        void add_instruction_to_buffer(char * buffer, int * buffer_length, int buffer_width, int instruction){
            int i;
            buffer[*buffer_length] = instruction & 0x00FF;
            *buffer_length = *buffer_length + 1;
            for(i = 8; i < buffer_width; i += 8){
                buffer[*buffer_length] = 0;
                *buffer_length = *buffer_length + 1;
            }
        }
        
        void add_status_to_buffer(char * buffer, int * buffer_length, int buffer_width, int status){
            int i;
            buffer[*buffer_length] = status & 0x00FF;
            *buffer_length = *buffer_length + 1;
            for(i = 8; i < buffer_width; i += 8){
                buffer[*buffer_length] = 0;
                *buffer_length = *buffer_length + 1;
            }
        }
        
        void add_header_to_buffer(char * buffer, int * buffer_length, int buffer_width, int header){
            int i;
            for(i = 0; i < 32; i += 8){
                buffer[*buffer_length] = (header >> (24 - i)) & 0x00FF;
                *buffer_length = *buffer_length + 1;
            }
        }
        
        void add_data_to_buffer(char * buffer, int * buffer_length, int buffer_width, char * data, int data_length){
            int i, j;
            for(j = 0; j < data_length;){
                for(i = 0; i < buffer_width; i += 8){
                    if(j < data_length){
                        buffer[*buffer_length] = data[j];
                        *buffer_length = *buffer_length + 1;
                        j++;
                    }
                    else{
                        buffer[*buffer_length] = 0;
                        *buffer_length = *buffer_length + 1;
                    }
                }
            }
        }
        
        void send_pdi_sdi_buffers_receive_do(char * pdi_buffer, int pdi_buffer_length_bytes, char * sdi_buffer, int sdi_buffer_length_bytes, char * do_buffer, int do_buffer_length_bytes, int skipping_cycles, int * time_cycles){
            int j;
            int pdi_iter, sdi_iter, do_iter;
            unsigned int temp_data;
            int last_block;
            int state_pdi_sending = 0;
            int state_pdi_sending_skipping = 0;
            int state_sdi_sending = 0;
            int state_sdi_sending_skipping = 0;
            int state_do_receiving = 0;
            int state_do_receiving_skipping = 0;
            pdi_iter = sdi_iter = do_iter = 0;
            *time_cycles = 0;
            while((pdi_iter < pdi_buffer_length_bytes) || (sdi_iter < sdi_buffer_length_bytes) || (do_iter < do_buffer_length_bytes) || (state_do_receiving != 0) || (state_sdi_sending != 0) || (state_pdi_sending != 0)){
                if((pdi_iter < pdi_buffer_length_bytes) || (state_pdi_sending != 0)){
                    if(state_pdi_sending == 0){
                        temp_data = 0;
                        for(j = 0; (j < G_PWIDTH); j += 8){
                            if((pdi_iter < pdi_buffer_length_bytes)){
                                temp_data = temp_data << 8;
                                temp_data |= ((pdi_buffer[pdi_iter]) & 0x00FF);
                                pdi_iter++;
                            }
                        }
                        dut->pdi_data = temp_data;
                        dut->pdi_valid = 1;
                        if(dut->pdi_ready == 0){
                            state_pdi_sending = 1;
                        }
                        else{
                            if(skipping_cycles > 0){
                                state_pdi_sending = 2;
                                state_pdi_sending_skipping = 0;
                            } else {
                                state_pdi_sending = 0;
                            }
                        }
                    }
                    else if(state_pdi_sending == 1){
                        if(dut->pdi_ready == 0){
                            state_pdi_sending = 1;
                        }
                        else{
                            if(skipping_cycles > 0){
                                state_pdi_sending = 2;
                                state_pdi_sending_skipping = 0;
                            } else {
                                state_pdi_sending = 0;
                            }
                        }
                    }
                    else if(state_pdi_sending == 2){
                        dut->pdi_data = 0;
                        dut->pdi_valid = 0;
                        if(state_pdi_sending_skipping < skipping_cycles){
                            state_pdi_sending_skipping++;
                        } else{
                            state_pdi_sending = 0;
                        }
                    }
                    else{
                        state_pdi_sending = 0;
                    }
                }
                else{
                    dut->pdi_data = 0;
                    dut->pdi_valid = 0;
                }
                if((sdi_iter < sdi_buffer_length_bytes) || (state_sdi_sending != 0)){
                    if(state_sdi_sending == 0){
                        temp_data = 0;
                        for(j = 0; (j < G_SWIDTH); j += 8){
                            if((sdi_iter < sdi_buffer_length_bytes)){
                                temp_data = temp_data << 8;
                                temp_data |= ((sdi_buffer[sdi_iter]) & 0x00FF);
                                sdi_iter++;
                            }
                        }
                        dut->sdi_data = temp_data;
                        dut->sdi_valid = 1;
                        if(dut->sdi_ready == 0){
                            state_sdi_sending = 1;
                        }
                        else{
                            if(skipping_cycles > 0){
                                state_sdi_sending = 2;
                                state_sdi_sending_skipping = 0;
                            } else {
                                state_sdi_sending = 0;
                            }
                        }
                    }
                    else if(state_sdi_sending == 1){
                        if(dut->sdi_ready == 0){
                            state_sdi_sending = 1;
                        }
                        else{
                            if(skipping_cycles > 0){
                                state_sdi_sending = 2;
                                state_sdi_sending_skipping = 0;
                            } else {
                                state_sdi_sending = 0;
                            }
                        }
                    }
                    else if(state_sdi_sending == 2){
                        dut->sdi_data = 0;
                        dut->sdi_valid = 0;
                        if(state_sdi_sending_skipping < skipping_cycles){
                            state_sdi_sending_skipping++;
                        } else{
                            state_sdi_sending = 0;
                        }
                    }
                    else{
                        state_sdi_sending = 0;
                    }
                }
                else{
                    dut->sdi_data = 0;
                    dut->sdi_valid = 0;
                }
                if((do_iter < do_buffer_length_bytes) || (state_do_receiving != 0)){
                    if(state_do_receiving == 0){
                        dut->do_ready = 1;
                        if(dut->do_valid == 0){
                            state_do_receiving = 0;
                        }
                        else{
                            temp_data = dut->do_data;
                            last_block = dut->do_last;
                            for(j = 0; (j < G_PWIDTH); j += 8){
                                do_buffer[do_iter] = (temp_data >> (G_PWIDTH - 8 - j)) & 0xFF;
                                do_iter++;
                            }
                            state_do_receiving = 0;
                            if(state_do_receiving_skipping < skipping_cycles){
                                state_do_receiving_skipping++;
                                state_do_receiving = 1;
                            } else{
                                state_do_receiving_skipping = 0;
                                state_do_receiving = 0;
                            }
                        }
                    }
                    else if(state_do_receiving == 1){
                        dut->do_ready = 0;
                        if(state_do_receiving_skipping < skipping_cycles){
                            state_do_receiving_skipping++;
                            state_do_receiving = 1;
                        } else{
                            state_do_receiving_skipping = 0;
                            state_do_receiving = 0;
                        }
                    }
                }
                else{
                    dut->do_ready = 0;
                }
                *time_cycles = *time_cycles + 1;
                clock_tick();
            }
            dut->pdi_data  = 0;
            dut->pdi_valid = 0;
            dut->sdi_data  = 0;
            dut->sdi_valid = 0;
            dut->do_ready  = 0;
        }
        
        int dut_hash(char * message_in, int message_in_length_bytes, char * true_hash_out, int hash_out_length_bytes){
            int temp_header, temp_status, temp_instruction;
            int temp_message_in_amount_sent, temp_message_in_amount_remaining, temp_message_in_amount_to_send, temp_hash_out_amount_received, temp_hash_out_amount_remaining;
            char pdi_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int pdi_buffer_size;
            char true_do_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int true_do_buffer_size;
            char test_do_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int test_do_buffer_size;
            int i;
            int skipping_cycles;
            int time_cycles;
            pdi_buffer_size = true_do_buffer_size = test_do_buffer_size = 0;
            
            temp_message_in_amount_sent = 0;
            temp_hash_out_amount_received = 0;
            // Hash instruction
            temp_instruction = 0x80;
            add_instruction_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_instruction);
            do{
                temp_message_in_amount_remaining = message_in_length_bytes - temp_message_in_amount_sent;
                temp_message_in_amount_to_send = (((temp_message_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_message_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of message to hash
                // header type (hash message)
                temp_header = 0x7 << 28;
                // header partial
                temp_header |= ((((temp_message_in_amount_remaining) > 0) && ((temp_message_in_amount_remaining) < G_MAXIMUM_DATA_SEGMENT_SIZE)) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((temp_message_in_amount_remaining) < G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_message_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= (((temp_message_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 24;
                temp_header |= temp_message_in_amount_to_send;
                
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Send hash data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &message_in[temp_message_in_amount_sent], temp_message_in_amount_to_send);
                temp_message_in_amount_sent += temp_message_in_amount_to_send;
            } while(temp_message_in_amount_sent < message_in_length_bytes);
            
            // Assume there is only one segment for the hash output.
            add_header_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, 0x93000000 + hash_out_length_bytes);
            add_data_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, true_hash_out, hash_out_length_bytes);
            add_status_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, 0xE0);
            
            for (skipping_cycles = 0; skipping_cycles < SKIPPING_TESTS_MAX; skipping_cycles++){
                
                send_pdi_sdi_buffers_receive_do(pdi_buffer, pdi_buffer_size, pdi_buffer, 0, test_do_buffer, true_do_buffer_size, skipping_cycles, &time_cycles);
                
                if(skipping_cycles == 0){
                    printf("Total time for hashing %d cycles, skip %d \n", time_cycles, skipping_cycles);
                }
                
                if(memcmp(test_do_buffer, true_do_buffer, true_do_buffer_size) != 0){
                    printf("Do buffers do no match\n");
                    printf("Skipping value set = %d\n", skipping_cycles);
                    printf("Expected buffer:\n");
                    for(i = 0; i < true_do_buffer_size; i++){
                        printf("%02x", (true_do_buffer[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received buffer:\n");
                    for(i = 0; i < true_do_buffer_size; i++){
                        printf("%02x", (test_do_buffer[i] & 0x00FF));
                    }
                    printf("\n");
                    return 1;
                }
            }
            return 0;
        }
        
        int dut_aead_enc(char * key_in, int key_in_length_bytes, char * nonce_in, int nonce_in_length_bytes, char * associated_data_in, int associated_data_in_length_bytes, char * plaintext_in, int plaintext_in_length_bytes, char * ciphertext_out, int ciphertext_out_length_bytes){
            int temp_header, temp_status, temp_instruction;
            int temp_key_in_amount_sent, temp_key_in_amount_remaining, temp_key_in_amount_to_send;
            int temp_nonce_in_amount_sent, temp_nonce_in_amount_remaining, temp_nonce_in_amount_to_send;
            int temp_associated_data_in_amount_sent, temp_associated_data_in_amount_remaining, temp_associated_data_in_amount_to_send;
            int temp_plaintext_in_amount_sent, temp_plaintext_in_amount_remaining, temp_plaintext_in_amount_to_send;
            int temp_ciphertext_out_length_bytes, temp_ciphertext_out_amount_received, temp_ciphertext_out_amount_remaining;
            int temp_tag_out_length_bytes;
            
            char pdi_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int pdi_buffer_size;
            char sdi_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int sdi_buffer_size;
            char true_do_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int true_do_buffer_size;
            char test_do_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int test_do_buffer_size;
            int i;
            int skipping_cycles;
            int time_cycles;
            pdi_buffer_size = sdi_buffer_size = true_do_buffer_size = test_do_buffer_size = 0;
            
            temp_key_in_amount_sent = 0;
            temp_nonce_in_amount_sent = 0;
            temp_associated_data_in_amount_sent = 0;
            temp_plaintext_in_amount_sent = 0;
            temp_ciphertext_out_amount_received = 0;
            
            // Activate key instruction
            temp_instruction = 0x70;
            add_instruction_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_instruction);
            
            // Send key instruction
            temp_instruction = 0x40;
            add_instruction_to_buffer(sdi_buffer, &sdi_buffer_size, G_SWIDTH, temp_instruction);
            // Send key data
            do{
                temp_key_in_amount_remaining = key_in_length_bytes - temp_key_in_amount_sent;
                temp_key_in_amount_to_send = (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_key_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of key to encrypt
                // header type (key message)
                temp_header = 0xC << 28;
                temp_header |= (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((temp_key_in_amount_remaining) > 0) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 24;
                temp_header |= temp_key_in_amount_to_send;
                add_header_to_buffer(sdi_buffer, &sdi_buffer_size, G_SWIDTH, temp_header);
                // Send key data
                add_data_to_buffer(sdi_buffer, &sdi_buffer_size, G_SWIDTH, &key_in[temp_key_in_amount_sent], temp_key_in_amount_to_send);
                temp_key_in_amount_sent += temp_key_in_amount_to_send;
            }
            while(temp_key_in_amount_sent < key_in_length_bytes);
            
            // Start encryption instruction
            temp_instruction = 0x20;
            add_instruction_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_instruction);
            
            // Send nonce data
            do{
                temp_nonce_in_amount_remaining = nonce_in_length_bytes - temp_nonce_in_amount_sent;
                temp_nonce_in_amount_to_send = (((temp_nonce_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_nonce_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of nonce to encrypt
                // header type (nonce message)
                temp_header = 0xD << 28;
                temp_header |= (((temp_nonce_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((associated_data_in_length_bytes == 0) && (plaintext_in_length_bytes == 0) && (temp_nonce_in_amount_sent == 0)) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_nonce_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= 0 << 24;
                temp_header |= temp_nonce_in_amount_to_send;
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Send nonce data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &nonce_in[temp_nonce_in_amount_sent], temp_nonce_in_amount_to_send);
                temp_nonce_in_amount_sent += temp_nonce_in_amount_to_send;
            }
            while(temp_nonce_in_amount_sent < nonce_in_length_bytes);
            
            // Send associated data
            do{
                temp_associated_data_in_amount_remaining = associated_data_in_length_bytes - temp_associated_data_in_amount_sent;
                temp_associated_data_in_amount_to_send = (((temp_associated_data_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_associated_data_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of associated data to encrypt
                // header type (associated data message)
                temp_header = 0x1 << 28;
                temp_header |= (((temp_associated_data_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((associated_data_in_length_bytes > 0) && (temp_associated_data_in_amount_sent == 0) && (plaintext_in_length_bytes == 0)) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_associated_data_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= 0 << 24;
                temp_header |= temp_associated_data_in_amount_to_send;
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Send associated data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &associated_data_in[temp_associated_data_in_amount_sent], temp_associated_data_in_amount_to_send);
                temp_associated_data_in_amount_sent += temp_associated_data_in_amount_to_send;
            }
            while(temp_associated_data_in_amount_sent < associated_data_in_length_bytes);
            
            // Send plaintext
            // Receive ciphertext
            do{
                temp_plaintext_in_amount_remaining = plaintext_in_length_bytes - temp_plaintext_in_amount_sent;
                temp_ciphertext_out_amount_remaining = ciphertext_out_length_bytes - temp_ciphertext_out_amount_received;
                temp_plaintext_in_amount_to_send = (((temp_plaintext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_plaintext_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of plaintext to encrypt
                // header type (plaintext message)
                temp_header = 0x4 << 28;
                temp_header |= (((temp_plaintext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((plaintext_in_length_bytes > 0) && (temp_plaintext_in_amount_sent == 0)) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_plaintext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= (((temp_plaintext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 24;;
                temp_header |= temp_plaintext_in_amount_to_send;
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Receive ciphertext header
                add_header_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, 0x50000000 + ((((temp_plaintext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25) + temp_plaintext_in_amount_to_send);
                // Send plaintext data
                // Receive ciphertext data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &plaintext_in[temp_plaintext_in_amount_sent], temp_plaintext_in_amount_to_send);
                add_data_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, &ciphertext_out[temp_ciphertext_out_amount_received], temp_plaintext_in_amount_to_send);
                temp_plaintext_in_amount_sent += temp_plaintext_in_amount_to_send;
                temp_ciphertext_out_amount_received += temp_plaintext_in_amount_to_send;
            }
            while(temp_plaintext_in_amount_sent < plaintext_in_length_bytes);
            // Receive tag header
            temp_ciphertext_out_amount_remaining = ciphertext_out_length_bytes - temp_ciphertext_out_amount_received;
            add_header_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, 0x83000000 + temp_ciphertext_out_amount_remaining);
            // Receive tag
            add_data_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, &ciphertext_out[temp_ciphertext_out_amount_received], temp_ciphertext_out_amount_remaining);
            add_status_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, 0xE0);
            
            // Perform all operations
            for (skipping_cycles = 0; skipping_cycles < SKIPPING_TESTS_MAX; skipping_cycles++){
            
                send_pdi_sdi_buffers_receive_do(pdi_buffer, pdi_buffer_size, sdi_buffer, sdi_buffer_size, test_do_buffer, true_do_buffer_size, skipping_cycles, &time_cycles);
                clock_tick();
                clock_tick();
                
                if(skipping_cycles == 0){
                    printf("Total time for AEAD encryption %d cycles\n", time_cycles);
                }
                
                if(memcmp(test_do_buffer, true_do_buffer, true_do_buffer_size) != 0){
                    printf("Do buffers do no match\n");
                    printf("Skipping value set = %d\n", skipping_cycles);
                    printf("Expected buffer:\n");
                    for(i = 0; i < true_do_buffer_size; i++){
                        printf("%02x", (true_do_buffer[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received buffer:\n");
                    for(i = 0; i < true_do_buffer_size; i++){
                        printf("%02x", (test_do_buffer[i] & 0x00FF));
                    }
                    printf("\n");
                    return 1;
                }
            }
                return 0;
        }
        
        int dut_aead_dec(char * key_in, int key_in_length_bytes, char * nonce_in, int nonce_in_length_bytes, char * associated_data_in, int associated_data_in_length_bytes, char * ciphertext_in, int ciphertext_in_length_bytes, char * plaintext_out, int plaintext_out_length_bytes, int true_core_status){
            int temp_header, temp_status, temp_instruction;
            int temp_key_in_amount_sent, temp_key_in_amount_remaining, temp_key_in_amount_to_send;
            int temp_nonce_in_amount_sent, temp_nonce_in_amount_remaining, temp_nonce_in_amount_to_send;
            int temp_associated_data_in_amount_sent, temp_associated_data_in_amount_remaining, temp_associated_data_in_amount_to_send;
            int temp_ciphertext_in_amount_sent, temp_ciphertext_in_amount_remaining, temp_ciphertext_in_amount_to_send;
            int temp_plaintext_out_amount_received, temp_plaintext_out_amount_remaining, temp_plaintext_out_amount_to_receive;
            int temp_tag_in_length_bytes;
            
            char pdi_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int pdi_buffer_size;
            char sdi_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int sdi_buffer_size;
            char true_do_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int true_do_buffer_size;
            char test_do_buffer[G_MAXIMUM_BUFFER_SIZE_ARRAY];
            int test_do_buffer_size;
            int i;
            int skipping_cycles;
            int time_cycles;
            pdi_buffer_size = sdi_buffer_size = true_do_buffer_size = test_do_buffer_size = 0;
            
            temp_key_in_amount_sent = 0;
            temp_nonce_in_amount_sent = 0;
            temp_associated_data_in_amount_sent = 0;
            temp_ciphertext_in_amount_sent = 0;
            temp_plaintext_out_amount_received = 0;
            
            // Activate key instruction
            temp_instruction = 0x70;
            add_instruction_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_instruction);
            
            // Send key instruction
            temp_instruction = 0x40;
            add_instruction_to_buffer(sdi_buffer, &sdi_buffer_size, G_SWIDTH, temp_instruction);
            // Send key data
            do{
                temp_key_in_amount_remaining = key_in_length_bytes - temp_key_in_amount_sent;
                temp_key_in_amount_to_send = (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_key_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of key to decrypt
                // header type (key message)
                temp_header = 0xC << 28;
                temp_header |= (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((temp_key_in_amount_remaining) > 0) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= (((temp_key_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 24;
                temp_header |= temp_key_in_amount_to_send;
                add_header_to_buffer(sdi_buffer, &sdi_buffer_size, G_SWIDTH, temp_header);
                // Send key data
                add_data_to_buffer(sdi_buffer, &sdi_buffer_size, G_SWIDTH, &key_in[temp_key_in_amount_sent], temp_key_in_amount_to_send);
                temp_key_in_amount_sent += temp_key_in_amount_to_send;
            }
            while(temp_key_in_amount_sent < key_in_length_bytes);
            
            // Start decryption instruction
            temp_instruction = 0x30;
            add_instruction_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_instruction);
            
            // Send nonce data
            do{
                temp_nonce_in_amount_remaining = nonce_in_length_bytes - temp_nonce_in_amount_sent;
                temp_nonce_in_amount_to_send = (((temp_nonce_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_nonce_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of nonce to decrypt
                // header type (nonce message)
                temp_header = 0xD << 28;
                temp_header |= (((temp_nonce_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((associated_data_in_length_bytes == 0) && (plaintext_out_length_bytes == 0) && (temp_nonce_in_amount_sent == 0)) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_nonce_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= 0 << 24;
                temp_header |= temp_nonce_in_amount_to_send;
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Send nonce data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &nonce_in[temp_nonce_in_amount_sent], temp_nonce_in_amount_to_send);
                temp_nonce_in_amount_sent += temp_nonce_in_amount_to_send;
            }
            while(temp_nonce_in_amount_sent < nonce_in_length_bytes);
            
            // Send associated data
            do{
                temp_associated_data_in_amount_remaining = associated_data_in_length_bytes - temp_associated_data_in_amount_sent;
                temp_associated_data_in_amount_to_send = (((temp_associated_data_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_associated_data_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of associated data to decrypt
                // header type (associated data message)
                temp_header = 0x1 << 28;
                temp_header |= (((temp_associated_data_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((associated_data_in_length_bytes > 0) && (temp_associated_data_in_amount_sent == 0) && (plaintext_out_length_bytes == 0)) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_associated_data_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= 0 << 24;
                temp_header |= temp_associated_data_in_amount_to_send;
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Send associated data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &associated_data_in[temp_associated_data_in_amount_sent], temp_associated_data_in_amount_to_send);
                temp_associated_data_in_amount_sent += temp_associated_data_in_amount_to_send;
            }
            while(temp_associated_data_in_amount_sent < associated_data_in_length_bytes);
            
            // Send ciphertext
            // Receive plaintext
            do{
                temp_ciphertext_in_amount_remaining = plaintext_out_length_bytes - temp_ciphertext_in_amount_sent;
                temp_plaintext_out_amount_remaining = plaintext_out_length_bytes - temp_plaintext_out_amount_received;
                temp_ciphertext_in_amount_to_send = (((temp_ciphertext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? G_MAXIMUM_DATA_SEGMENT_SIZE-1 : (temp_ciphertext_in_amount_remaining)) & G_SEGMENT_DATA_SIZE_MASK;
                // Send header of ciphertext to decrypt
                // header type (ciphertext message)
                temp_header = 0x5 << 28;
                temp_header |= (((temp_ciphertext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 1 : 0) << 27;
                // header end of input (active high)
                temp_header |= (((plaintext_out_length_bytes > 0) && (temp_ciphertext_in_amount_sent == 0)) ? 1 : 0) << 26;
                // header end of type (active high)
                temp_header |= (((temp_ciphertext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25;
                // header last (active high)
                temp_header |= 0 << 24;
                temp_header |= temp_ciphertext_in_amount_to_send;
                add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
                // Receive plaintext header
                add_header_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, 0x40000000 + ((((temp_ciphertext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 25) + ((((temp_ciphertext_in_amount_remaining) >= G_MAXIMUM_DATA_SEGMENT_SIZE) ? 0 : 1) << 24) + temp_ciphertext_in_amount_to_send);
                // Send ciphertext data
                // Receive plaintext data
                add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &ciphertext_in[temp_ciphertext_in_amount_sent], temp_ciphertext_in_amount_to_send);
                add_data_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, &plaintext_out[temp_plaintext_out_amount_received], temp_ciphertext_in_amount_to_send);
                temp_ciphertext_in_amount_sent += temp_ciphertext_in_amount_to_send;
                temp_plaintext_out_amount_received += temp_ciphertext_in_amount_to_send;
            }
            while(temp_ciphertext_in_amount_sent < plaintext_out_length_bytes);
            
            temp_tag_in_length_bytes = ciphertext_in_length_bytes - plaintext_out_length_bytes;
            
            // Send tag
            // Send header of tag to verify
            // header type (tag message)
            temp_header = 0x8 << 28;
            temp_header |=  0 << 27;
            // header end of input (active high)
            temp_header |= 0 << 26;
            // header end of type (active high)
            temp_header |= 1 << 25;
            // header last (active high)
            temp_header |= 1 << 24;
            temp_header |= temp_tag_in_length_bytes;
            add_header_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, temp_header);
            // Send tag data
            add_data_to_buffer(pdi_buffer, &pdi_buffer_size, G_PWIDTH, &ciphertext_in[temp_ciphertext_in_amount_sent], temp_tag_in_length_bytes);
            // Receive status header
            add_status_to_buffer(true_do_buffer, &true_do_buffer_size, G_PWIDTH, true_core_status);
            
            // Perform all operations
            for (skipping_cycles = 0; skipping_cycles < SKIPPING_TESTS_MAX; skipping_cycles++){
                send_pdi_sdi_buffers_receive_do(pdi_buffer, pdi_buffer_size, sdi_buffer, sdi_buffer_size, test_do_buffer, true_do_buffer_size, skipping_cycles, &time_cycles);
                
                if(skipping_cycles == 0){
                    printf("Total time for AEAD decryption %d cycles\n", time_cycles);
                }
                if(memcmp(test_do_buffer, true_do_buffer, true_do_buffer_size) != 0){
                    printf("Do buffers do no match\n");
                    printf("Skipping value set = %d\n", skipping_cycles);
                    printf("Expected buffer:\n");
                    for(i = 0; i < true_do_buffer_size; i++){
                        printf("%02x", (true_do_buffer[i] & 0x00FF));
                    }
                    printf("\n");
                    printf("Received buffer:\n");
                    for(i = 0; i < true_do_buffer_size; i++){
                        printf("%02x", (test_do_buffer[i] & 0x00FF));
                    }
                    printf("\n");
                    return 1;
                }
            }
            return 0;
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
    FILE * hash_file;
    FILE * aead_file;
    char buffer_read [G_MAXIMUM_BUFFER_SIZE_ARRAY];
    char temp_char1, temp_char2, temp_value;
    int count;
    int key_size, nonce_size, pt_size, ad_size, ct_size;
    int test_verification;
    int test_error;
    int core_status;
    int i, j;
    char test_input_key_enc   [G_MAXIMUM_KEY_SIZE];
    char test_input_nonce_enc [G_MAXIMUM_NONCE_SIZE];
    char test_input_pt_enc    [G_MAXIMUM_PLAINTEXT_SIZE];
    char test_input_ad_enc    [G_MAXIMUM_ASSOCIATED_DATA_SIZE];
    char test_output_ct_enc   [G_MAXIMUM_CIPHERTEXT_SIZE];
    char true_output_ct_enc   [G_MAXIMUM_CIPHERTEXT_SIZE];
    char test_input_key_dec   [G_MAXIMUM_KEY_SIZE];
    char test_input_nonce_dec [G_MAXIMUM_NONCE_SIZE];
    char test_input_ct_dec    [G_MAXIMUM_CIPHERTEXT_SIZE];
    char test_input_ad_dec    [G_MAXIMUM_ASSOCIATED_DATA_SIZE];
    char test_output_pt_dec   [G_MAXIMUM_PLAINTEXT_SIZE];
    char true_output_pt_dec   [G_MAXIMUM_PLAINTEXT_SIZE];
    Testbench * tb;
    
    // Call commandArgs first!
    Verilated::commandArgs(argc, argv);
#ifdef DUMP_TRACE_ON
    Verilated::traceEverOn(true);
#endif
    
    // Instantiate our design
    tb = new Testbench(MAX_SIMULATION_TICKS);
    
    test_verification = 0;
    test_error = 0;
    memset(test_input_key_enc, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
    memset(test_input_nonce_enc, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
    memset(test_input_pt_enc, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
    memset(test_input_ad_enc, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
    memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(true_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(test_input_key_dec, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
    memset(test_input_nonce_dec, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
    memset(test_input_ct_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
    memset(test_input_ad_dec, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
    memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
    memset(true_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
    
    tb->reset();
    
    count = 0;
    test_error = 0;
    #if G_SKIP_AEAD_TEST == 0
        printf("Start of the aead test\n");
        aead_file = fopen(G_FNAME_AEAD_KAT, "r");
        if(!aead_file != 0){
            printf("Could not open file %s\n", G_FNAME_AEAD_KAT);
        }
        while(!feof(aead_file) && (count < G_MAXIMUM_NUMBER_OF_TESTS) && (test_error == 0)) {
            read_until_get_character(aead_file, '=');
            fscanf(aead_file, "%d", &count);
            #if PRINT_CURRENT_TEST_NUMBER != 0
                printf("Test number %d\n", count);
            #endif
            memset(test_input_key_enc, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
            memset(test_input_nonce_enc, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
            memset(test_input_pt_enc, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
            memset(test_input_ad_enc, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
            memset(test_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(true_output_ct_enc, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_input_key_dec, 0, sizeof(char)*G_MAXIMUM_KEY_SIZE);
            memset(test_input_nonce_dec, 0, sizeof(char)*G_MAXIMUM_NONCE_SIZE);
            memset(test_input_ct_dec, 0, sizeof(char)*G_MAXIMUM_CIPHERTEXT_SIZE);
            memset(test_input_ad_dec, 0, sizeof(char)*G_MAXIMUM_ASSOCIATED_DATA_SIZE);
            memset(test_output_pt_dec, 0, sizeof(char)*G_MAXIMUM_PLAINTEXT_SIZE);
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
            
            // Perform the encryption procedure
            test_error += tb->dut_aead_enc(test_input_key_enc, key_size, test_input_nonce_enc, nonce_size, test_input_ad_enc, ad_size, test_input_pt_enc, pt_size, true_output_ct_enc, ct_size);
            if(test_error != 0){
                tb->clock_tick();
                break;
            }
            tb->clock_tick();
            
            // Wait the last permutation squeeze
            for(j = 0; j < 25; j++){
                tb->clock_tick();
            }
            
            // Decryption correct tag
            
            memcpy(test_input_key_dec, test_input_key_enc, key_size);
            memcpy(test_input_nonce_dec, test_input_nonce_enc, nonce_size);
            memcpy(test_input_ad_dec, test_input_ad_enc, ad_size);
            memcpy(test_input_ct_dec, true_output_ct_enc, ct_size);
            memcpy(true_output_pt_dec, test_input_pt_enc, pt_size);
            
            // Perform the decryption procedure
            test_error += tb->dut_aead_dec(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, ct_size, true_output_pt_dec, pt_size, 0xE0);
            if(test_error != 0){
                tb->clock_tick();
                break;
            }
            tb->clock_tick();
            
            // Wait the last permutation squeeze
            for(j = 0; j < 25; j++){
                tb->clock_tick();
            }
            
            
            // Decryption incorrect tag
            
            memcpy(test_input_key_dec, test_input_key_enc, key_size);
            memcpy(test_input_nonce_dec, test_input_nonce_enc, nonce_size);
            memcpy(test_input_ad_dec, test_input_ad_enc, ad_size);
            memcpy(test_input_ct_dec, true_output_ct_enc, ct_size);
            memcpy(true_output_pt_dec, test_input_pt_enc, pt_size);
            
            test_input_ct_dec[pt_size] = test_input_ct_dec[pt_size] ^ 0xFF;
            
            // Perform the decryption procedure
            test_error += tb->dut_aead_dec(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, ct_size, true_output_pt_dec, pt_size, 0xF0);
            if(test_error != 0){
                tb->clock_tick();
                break;
            }
            tb->clock_tick();
            
            // Wait the last permutation squeeze
            for(j = 0; j < 25; j++){
                tb->clock_tick();
            }
            
            
            read_ignore_character(aead_file, '\n', &temp_char1);
        }
        fclose(aead_file);
        printf("End of the aead test\n");
    #endif
    
    delete tb;
}