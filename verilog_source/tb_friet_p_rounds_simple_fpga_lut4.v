/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module tb_friet_p_rounds_simple_fpga_lut4
#(parameter PERIOD = 1000,
parameter ASYNC_RSTN = 0,  // 0 - Synchronous reset in high, 1 - Asynchrouns reset in low.
parameter maximum_line_length = 10000,
parameter MAXIMUM_BUFFER_SIZE = 8192,
parameter skip_aead_test = 0, // 1 - True, 0 - False
parameter test_memory_file_friet_aead = "../data_tests/LWC_AEAD_KAT_256_128.txt",
parameter sim_enable_dump = 1 // 1 - True, 0 - False
);

reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_key_enc;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_nonce_enc;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_pt_enc;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_ad_enc;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_output_ct_enc;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_output_tag_enc;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] true_output_ct_enc;

reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_key_dec;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_nonce_dec;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_ct_dec;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_input_ad_dec;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_output_pt_dec;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] test_output_tag_dec;
reg [(MAXIMUM_BUFFER_SIZE - 1):0] true_output_pt_dec;

reg test_arstn;
reg [2:0] test_oper;
reg [127:0] test_din;
reg [4:0] test_din_size;
reg test_din_last;
reg test_din_valid;
wire test_din_ready;
wire [127:0] test_dout;
wire test_dout_valid;
reg test_dout_ready;
wire [4:0] test_dout_size;
wire test_dout_last;
wire test_fault_detected;

reg clk;
reg test_error = 1'b0;
reg test_verification = 1'b0;

localparam tb_delay = PERIOD/2;
localparam tb_delay_read = 3*PERIOD/4;

friet_p_rounds_simple_fpga_lut4
test
(
    .clk(clk),
    .arstn(test_arstn),
    .oper(test_oper),
    .din(test_din),
    .din_size(test_din_size),
    .din_last(test_din_last),
    .din_valid(test_din_valid),
    .din_ready(test_din_ready),
    .dout(test_dout),
    .dout_valid(test_dout_valid),
    .dout_ready(test_dout_ready),
    .dout_size(test_dout_size),
    .dout_last(test_dout_last),
    .fault_detected(test_fault_detected)
);

initial begin : clock_generator
    clk <= 1'b1;
    forever begin
        #(PERIOD/2);
        clk <= ~clk;
    end
end

task test_init_state;
    output integer cycle_counts;
    integer temp_buffer_in, temp_j;
    begin
        cycle_counts = 0;
        test_oper = 3'b000;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b1;
        test_dout_ready = 1'b0;
        while(test_din_ready == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_oper = 3'b000;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
        test_din_valid = 1'b0;
    end
endtask

task test_absorb_direct;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] buffer_in;
    input integer buffer_size;
    input [1:0] absorb_type;
    output integer cycle_counts;
    integer temp_buffer_in, temp_j;
    begin
        cycle_counts = 0;
        test_oper = {1'b1, absorb_type};
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
        temp_buffer_in = 0;
        while(temp_buffer_in < (buffer_size-16)) begin
            test_din = 128'b00;
            temp_j = 0;
            while(temp_j < 16) begin
                test_din = {buffer_in[8*temp_buffer_in +: 8], test_din[127:8]};
                temp_buffer_in = temp_buffer_in + 1;
                temp_j = temp_j + 1;
            end
            test_din_size = 5'b10000;
            test_din_last = 1'b0;
            test_din_valid = 1'b1;
            test_dout_ready = 1'b0;
            while(test_din_ready == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din = 128'b00;
            test_din_size = 5'b00000;
            test_din_valid = 1'b0;
            test_dout_ready = 1'b0;
        end
        test_din = 128'b00;
        temp_j = 0;
        test_din_size = 0;
        test_din_last = 1'b1;
        while((temp_j < 16) && (temp_buffer_in < buffer_size)) begin
            test_din = {buffer_in[8*temp_buffer_in +: 8], test_din[127:8]};
            test_din_size = test_din_size + 1;
            temp_buffer_in = temp_buffer_in + 1;
            temp_j = temp_j + 1;
        end
        while(temp_j < 16) begin
            test_din = {8'b00, test_din[127:8]};
            temp_buffer_in = temp_buffer_in + 1;
            temp_j = temp_j + 1;
        end
        test_din_valid = 1'b1;
        test_dout_ready = 1'b0;
        while(test_din_ready == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_oper = 3'b000;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
    end
endtask

task test_absorb_encrypt;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] buffer_in;
    input integer buffer_size;
    output [(MAXIMUM_BUFFER_SIZE - 1):0] buffer_out;
    output integer cycle_counts;
    integer temp_buffer_in, temp_buffer_out, temp_j;
    begin
        cycle_counts = 0;
        test_oper = 3'b001;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
        buffer_out = {MAXIMUM_BUFFER_SIZE{1'b0}};
        temp_buffer_in = 0;
        temp_buffer_out = 0;
        while(temp_buffer_in < (buffer_size-16)) begin
            test_din = 128'b00;
            temp_j = 0;
            while(temp_j < 16) begin
                test_din = {buffer_in[8*temp_buffer_in +: 8], test_din[127:8]};
                temp_buffer_in = temp_buffer_in + 1;
                temp_j = temp_j + 1;
            end
            test_din_size = 5'b10000;
            test_din_last = 1'b0;
            test_din_valid = 1'b1;
            test_dout_ready = 1'b0;
            while(test_din_ready == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din_valid = 1'b0;
            test_dout_ready = 1'b1;
            while(test_dout_valid == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            temp_j = 0;
            while(temp_j < 16) begin
                buffer_out[8*temp_buffer_out +: 8] = test_dout[8*temp_j +: 8];
                temp_buffer_out = temp_buffer_out + 1;
                temp_j = temp_j + 1;
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din = 128'b00;
            test_din_size = 5'b00000;
            test_din_last = 1'b0;
            test_din_valid = 1'b0;
            test_dout_ready = 1'b0;
        end
        test_din = 128'b00;
        test_din_last = 1'b1;
        temp_j = 0;
        test_din_size = 0;
        while((temp_j < 16) && (temp_buffer_in < buffer_size)) begin
            test_din = {buffer_in[8*temp_buffer_in +: 8], test_din[127:8]};
            test_din_size = test_din_size + 1;
            temp_buffer_in = temp_buffer_in + 1;
            temp_j = temp_j + 1;
        end
        while((temp_j < 16)) begin
            test_din = {8'b00, test_din[127:8]};
            temp_buffer_in = temp_buffer_in + 1;
            temp_j = temp_j + 1;
        end
        test_din_valid = 1'b1;
        test_dout_ready = 1'b0;
        while(test_din_ready == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_din_valid = 1'b0;
        test_dout_ready = 1'b1;
        while(test_dout_valid == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        temp_j = 0;
        while((temp_j < 16) && (temp_buffer_out < buffer_size)) begin
            buffer_out[8*temp_buffer_out +: 8] = test_dout[8*temp_j +: 8];
            temp_buffer_out = temp_buffer_out + 1;
            temp_j = temp_j + 1;
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_oper = 3'b000;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
    end
endtask

task test_absorb_decrypt;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] buffer_in;
    input integer buffer_size;
    output [(MAXIMUM_BUFFER_SIZE - 1):0] buffer_out;
    output integer cycle_counts;
    integer temp_buffer_in, temp_buffer_out, temp_j;
    begin
        cycle_counts = 0;
        test_oper = 3'b010;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
        buffer_out = {MAXIMUM_BUFFER_SIZE{1'b0}};
        temp_buffer_in = 0;
        temp_buffer_out = 0;
        while(temp_buffer_in < (buffer_size-16)) begin
            test_din = 128'b00;
            temp_j = 0;
            test_din_size = 0;
            while(temp_j < 16) begin
                test_din = {buffer_in[8*temp_buffer_in +: 8], test_din[127:8]};
                temp_buffer_in = temp_buffer_in + 1;
                temp_j = temp_j + 1;
            end
            test_din_size = 5'b10000;
            test_din_last = 1'b0;
            test_din_valid = 1'b1;
            test_dout_ready = 1'b0;
            while(test_din_ready == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din_valid = 1'b0;
            test_dout_ready = 1'b1;
            while(test_dout_valid == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            temp_j = 0;
            while(temp_j < 16) begin
                buffer_out[8*temp_buffer_out +: 8] = test_dout[8*temp_j +: 8];
                temp_buffer_out = temp_buffer_out + 1;
                temp_j = temp_j + 1;
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din = 128'b00;
            test_din_size = 5'b00000;
            test_din_last = 1'b0;
            test_din_valid = 1'b0;
            test_dout_ready = 1'b0;
        end
        test_din = 128'b00;
        test_din_last = 1'b1;
        temp_j = 0;
        test_din_size = 0;
        while((temp_j < 16) && (temp_buffer_in < buffer_size)) begin
            test_din = {buffer_in[8*temp_buffer_in +: 8], test_din[127:8]};
            test_din_size = test_din_size + 1;
            temp_buffer_in = temp_buffer_in + 1;
            temp_j = temp_j + 1;
        end
        while((temp_j < 16)) begin
            test_din = {8'b00, test_din[127:8]};
            temp_buffer_in = temp_buffer_in + 1;
            temp_j = temp_j + 1;
        end
        test_din_valid <= 1'b1;
        test_dout_ready <= 1'b0;
        while(test_din_ready == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_din_valid <= 1'b0;
        test_dout_ready <= 1'b1;
        while(test_dout_valid == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        temp_j = 0;
        while((temp_j < 16) && (temp_buffer_out < buffer_size)) begin
            buffer_out[8*temp_buffer_out +: 8] = test_dout[8*temp_j +: 8];
            temp_buffer_out = temp_buffer_out + 1;
            temp_j = temp_j + 1;
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_oper = 3'b000;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
    end
endtask

task test_squeeze_permute;
    output [(MAXIMUM_BUFFER_SIZE - 1):0] buffer_out;
    input integer buffer_size;
    output integer cycle_counts;
    integer temp_buffer_out, temp_j;
    begin
        cycle_counts = 0;
        test_oper = 3'b011;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
        buffer_out = {MAXIMUM_BUFFER_SIZE{1'b0}};
        temp_buffer_out = 0;
        while(temp_buffer_out < (buffer_size-16)) begin
            test_din_valid = 1'b1;
            test_dout_ready = 1'b0;
            while(test_din_ready == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din_valid = 1'b0;
            test_dout_ready = 1'b1;
            while(test_dout_valid == 1'b0) begin
                cycle_counts = cycle_counts + 1;
                #(PERIOD);
            end
            temp_j = 0;
            while((temp_j < 16) && (temp_buffer_out < buffer_size)) begin
                buffer_out[8*temp_buffer_out +: 8] = test_dout[8*temp_j +: 8];
                temp_buffer_out = temp_buffer_out + 1;
                temp_j = temp_j + 1;
            end
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
            test_din = 128'b00;
            test_din_size = 5'b00000;
            test_din_last = 1'b0;
            test_din_valid = 1'b0;
            test_dout_ready = 1'b0;
        end
        test_din_valid = 1'b1;
        test_dout_ready = 1'b0;
        test_din_last = 1'b1;
        while(test_din_ready == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_din_valid = 1'b0;
        test_dout_ready = 1'b1;
        while(test_dout_valid == 1'b0) begin
            cycle_counts = cycle_counts + 1;
            #(PERIOD);
        end
        temp_j = 0;
        while((temp_j < 16) && (temp_buffer_out < buffer_size)) begin
            buffer_out[8*temp_buffer_out +: 8] = test_dout[8*temp_j +: 8];
            temp_buffer_out = temp_buffer_out + 1;
            temp_j = temp_j + 1;
        end
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
        test_oper = 3'b000;
        test_din = 128'b00;
        test_din_size = 5'b00000;
        test_din_last = 1'b0;
        test_din_valid = 1'b0;
        test_dout_ready = 1'b0;
    end
endtask

task test_encrypt;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] key;
    input integer key_size;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] nonce;
    input integer nonce_size;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] associated_data;
    input integer associated_data_size;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] plaintext;
    input integer plaintext_size;
    output [(MAXIMUM_BUFFER_SIZE - 1):0] ciphertext;
    output [127:0] tag;
    output integer cycle_counts;
    reg [127:0] temp_out;
    integer temp_cycle_counts;
    begin
    cycle_counts = 0;
    test_init_state(temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_direct(key, key_size, 2'b00, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_direct(nonce, nonce_size, 2'b01, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_squeeze_permute(temp_out, 16, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_direct(associated_data, associated_data_size, 2'b00, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_encrypt(plaintext, plaintext_size, ciphertext, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_squeeze_permute(tag, 16, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    while(test_din_ready == 1'b0) begin
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
    end
    end
endtask

task test_decrypt;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] key;
    input integer key_size;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] nonce;
    input integer nonce_size;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] associated_data;
    input integer associated_data_size;
    input [(MAXIMUM_BUFFER_SIZE - 1):0] ciphertext;
    input integer ciphertext_size;
    output [(MAXIMUM_BUFFER_SIZE - 1):0] plaintext;
    output [127:0] tag;
    output integer cycle_counts;
    reg [127:0] temp_out;
    integer temp_cycle_counts;
    begin
    cycle_counts = 0;
    test_init_state(temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_direct(key, key_size, 2'b00, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_direct(nonce, nonce_size, 2'b01, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_squeeze_permute(temp_out, 16, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_direct(associated_data, associated_data_size, 2'b00, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_absorb_decrypt(ciphertext, ciphertext_size, plaintext, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    test_squeeze_permute(tag, 16, temp_cycle_counts);
    cycle_counts = cycle_counts + temp_cycle_counts;
    while(test_din_ready == 1'b0) begin
        cycle_counts = cycle_counts + 1;
        #(PERIOD);
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
integer hash_file;
integer temp_text1;
integer count;
integer key_size;
integer nonce_size;
integer pt_size;
integer ad_size;
integer ct_size;
integer tag_size;
integer status_ram_file;
integer test_iterator;
integer cycle_counts;
initial begin
    if(ASYNC_RSTN == 0) begin
        test_arstn = 1'b1;
    end else begin
        test_arstn = 1'b0;
    end
    test_oper = 3'b000;
    test_din = 128'b00;
    test_din_size = 5'b00000;
    test_din_last = 1'b0;
    test_din_valid = 1'b0;
    test_dout_ready = 1'b0;
    test_error = 1'b0;
    test_verification = 1'b0;
    test_input_key_enc   = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_nonce_enc = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_pt_enc    = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_ad_enc    = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_output_ct_enc   = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_output_tag_enc  = {MAXIMUM_BUFFER_SIZE{1'b0}};
    true_output_ct_enc   = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_key_dec   = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_nonce_dec = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_ct_dec    = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_input_ad_dec    = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_output_tag_dec  = {MAXIMUM_BUFFER_SIZE{1'b0}};
    test_output_pt_dec   = {MAXIMUM_BUFFER_SIZE{1'b0}};
    true_output_pt_dec   = {MAXIMUM_BUFFER_SIZE{1'b0}};
    tag_size = 16;
    #(PERIOD*2);
    if(ASYNC_RSTN == 0) begin
        test_arstn = 1'b0;
    end else begin
        test_arstn = 1'b1;
    end
    #(PERIOD);
    #(tb_delay);
    if(skip_aead_test == 0) begin
        $display("Start of the aead test");
        aead_file = $fopen(test_memory_file_friet_aead, "r");
        while(!$feof(aead_file)) begin
            read_until_get_character(aead_file, "=");
            status_ram_file = $fscanf(aead_file, "%d", count);
            $display("Test number : %d", count);
            #(PERIOD);
            test_error <= 1'b0;
            test_verification <= 1'b0;
            test_input_key_enc   <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_nonce_enc <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_pt_enc    <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_ad_enc    <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_output_ct_enc   <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_output_tag_enc  <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            true_output_ct_enc   <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_key_dec   <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_nonce_dec <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_ct_dec    <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_input_ad_dec    <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_output_tag_dec  <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            test_output_pt_dec   <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            true_output_pt_dec   <= {MAXIMUM_BUFFER_SIZE{1'b0}};
            #(PERIOD);
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
                test_input_key_enc = {test_input_key_enc[7:0], test_input_key_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
                key_size = key_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(key_size > 0) begin
                test_iterator = MAXIMUM_BUFFER_SIZE/8;
                while (test_iterator > key_size) begin
                    test_input_key_enc = {test_input_key_enc[7:0], test_input_key_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
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
                test_input_nonce_enc = {test_input_nonce_enc[7:0], test_input_nonce_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
                nonce_size = nonce_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(nonce_size > 0) begin
                test_iterator = MAXIMUM_BUFFER_SIZE/8;
                while (test_iterator > nonce_size) begin
                    test_input_nonce_enc = {test_input_nonce_enc[7:0], test_input_nonce_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
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
                test_input_pt_enc = {test_input_pt_enc[7:0], test_input_pt_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
                pt_size = pt_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(pt_size > 0) begin
                test_iterator = MAXIMUM_BUFFER_SIZE/8;
                while (test_iterator > pt_size) begin
                    test_input_pt_enc = {test_input_pt_enc[7:0], test_input_pt_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
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
                test_input_ad_enc = {test_input_ad_enc[7:0], test_input_ad_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
                ad_size = ad_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(ad_size > 0) begin
                test_iterator = MAXIMUM_BUFFER_SIZE/8;
                while (test_iterator > ad_size) begin
                    test_input_ad_enc = {test_input_ad_enc[7:0], test_input_ad_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
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
                true_output_ct_enc = {true_output_ct_enc[7:0], true_output_ct_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
                ct_size = ct_size + 1;
            end
            // If the length is variable the buffer has to be adjusted
            if(ct_size > 0) begin
                test_iterator = MAXIMUM_BUFFER_SIZE/8;
                while (test_iterator > ct_size) begin
                    true_output_ct_enc = {true_output_ct_enc[7:0], true_output_ct_enc[(MAXIMUM_BUFFER_SIZE-1):8]};
                    test_iterator = test_iterator - 1;
                end
            end
            // Copy ciphertext input for decryption
            // Copy plaintext output for decryption
            test_iterator = 0;
            while(test_iterator < pt_size) begin
                true_output_pt_dec = {test_input_pt_enc[test_iterator*8 +:8], true_output_pt_dec[(MAXIMUM_BUFFER_SIZE-1):8]};
                test_input_ct_dec = {true_output_ct_enc[test_iterator*8 +:8], test_input_ct_dec[(MAXIMUM_BUFFER_SIZE-1):8]};
                test_iterator = test_iterator + 1;
            end
            while(test_iterator < ct_size) begin
                true_output_pt_dec = {true_output_ct_enc[test_iterator*8 +:8], true_output_pt_dec[(MAXIMUM_BUFFER_SIZE-1):8]};
                test_input_ct_dec = {test_input_ct_dec[7:0], test_input_ct_dec[(MAXIMUM_BUFFER_SIZE-1):8]};
                test_iterator = test_iterator + 1;
            end
            while(test_iterator < MAXIMUM_BUFFER_SIZE/8) begin
                true_output_pt_dec = {true_output_pt_dec[7:0], true_output_pt_dec[(MAXIMUM_BUFFER_SIZE-1):8]};
                test_input_ct_dec = {test_input_ct_dec[7:0], test_input_ct_dec[(MAXIMUM_BUFFER_SIZE-1):8]};
                test_iterator = test_iterator + 1;
            end
            test_input_key_dec = test_input_key_enc;
            test_input_nonce_dec = test_input_nonce_enc;
            test_input_ad_dec = test_input_ad_enc;
            // Perform the encryption procedure
            test_encrypt(test_input_key_enc, key_size, test_input_nonce_enc, nonce_size, test_input_ad_enc, ad_size, test_input_pt_enc, pt_size, test_output_ct_enc, test_output_tag_enc, cycle_counts);
            $display("Cycle counts encryption: %d", cycle_counts);
            #(PERIOD);
            test_iterator = 0;
            while(test_iterator < tag_size) begin
                test_output_ct_enc[(pt_size*8+test_iterator*8) +: 8] <= test_output_tag_enc[(test_iterator*8) +: 8];
                test_iterator = test_iterator + 1;
            end
            #(PERIOD);
            // Check ciphertext and tag
            #(PERIOD);
            test_verification <= 1'b1;
            if (true_output_ct_enc == test_output_ct_enc) begin
                test_error <= 1'b0;
            end else begin
                test_error <= 1'b1;
                $display("Computed values do not match expected ones");
            end
            #(PERIOD);
            test_error <= 1'b0;
            test_verification <= 1'b0;
            #(PERIOD);
            // Perform the decryption procedure
            test_decrypt(test_input_key_dec, key_size, test_input_nonce_dec, nonce_size, test_input_ad_dec, ad_size, test_input_ct_dec, pt_size, test_output_pt_dec, test_output_tag_dec, cycle_counts);
            $display("Cycle counts decryption: %d\n", cycle_counts);
            #(PERIOD);
            test_iterator = 0;
            while(test_iterator < tag_size) begin
                test_output_pt_dec[(pt_size*8+test_iterator*8) +: 8] <= test_output_tag_dec[(test_iterator*8) +: 8];
                test_iterator = test_iterator + 1;
            end
            #(PERIOD);
            // Check plaintext and tag
            #(PERIOD);
            test_verification <= 1'b1;
            if (true_output_pt_dec == test_output_pt_dec) begin
                test_error <= 1'b0;
            end else begin
                test_error <= 1'b1;
                $display("Computed values do not match expected ones");
            end
            #(PERIOD);
            test_error <= 1'b0;
            test_verification <= 1'b0;
            #(PERIOD);
            read_ignore_character(aead_file, "\n", temp_text1);
        end
        $fclose(aead_file);
        $display("End of the aead test.");
    end
    $display("End of the test.");
    disable clock_generator;
    #(PERIOD);
end

generate
if(sim_enable_dump == 1'b1) begin
    initial
    begin
        $dumpfile("tb_friet_p_rounds_simple_fpga_lut4_dump");
        $dumpvars(1, tb_friet_p_rounds_simple_fpga_lut4);
        $dumpvars(1, tb_friet_p_rounds_simple_fpga_lut4.test);
    end
end
endgenerate

endmodule