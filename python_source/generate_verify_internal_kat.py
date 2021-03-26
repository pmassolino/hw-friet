#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from friet_c import *

def init_buffer(number_bytes, starting_byte=0):
    value = bytearray(number_bytes)
    for i in range(number_bytes):
        value[i] = (i+starting_byte) % 256
    return value

def generate_aead_test(test_file_name = "AEAD_INT_KAT.txt", tag_bytes = 48, key_tag_bytes = 48):
    out_file = open(test_file_name, 'w', newline='\n')
    tests_ad_m = [0, 1, 16, 17, 32, 33]
    tests_k_n = [1, 16, 17, 32, 33]
    messages = init_buffer(48)
    associated_datas = init_buffer(48)
    nonce = init_buffer(48, 64)
    key = init_buffer(48, 32)
    count = 1
    for i in tests_ad_m:
        for j in tests_ad_m:
            for l in tests_k_n:
                for q in tests_k_n:
                    ciphertext = crypto_aead_encrypt_with_key_tag(messages[:i], associated_datas[:j], None, nonce[:l], key[:q], key_tag_bytes, tag_bytes)
                    out_file.write("Count = " + str(count) + '\n')
                    out_file.write("Key = " + ((key[:q]).hex()).upper() + '\n')
                    out_file.write("Nonce = " + ((nonce[:l]).hex()).upper() + '\n')
                    out_file.write("PT = " + ((messages[:i]).hex()).upper() + '\n')
                    out_file.write("AD = " + ((associated_datas[:j]).hex()).upper() + '\n')
                    out_file.write("CT = " + (ciphertext.hex()).upper() + '\n')
                    out_file.write("\n")
                    count += 1
    out_file.close()

def verify_aead_test(test_file_name = "AEAD_INT_KAT.txt", tag_bytes = 48, key_tag_bytes = 48):
    read_file = open(test_file_name, 'r', newline='\n')
    current_line = read_file.readline()
    while(current_line != ''):
        count_str = (current_line.split('=')[1]).strip()
        count = int(count_str)
        current_line = read_file.readline()
        key_str = (current_line.split('=')[1]).strip()
        key = bytearray.fromhex(key_str)
        current_line = read_file.readline()
        nonce_str = (current_line.split('=')[1]).strip()
        nonce = bytearray.fromhex(nonce_str)
        current_line = read_file.readline()
        message_str = (current_line.split('=')[1]).strip()
        message = bytearray.fromhex(message_str)
        current_line = read_file.readline()
        associated_data_str = (current_line.split('=')[1]).strip()
        associated_data = bytearray.fromhex(associated_data_str)
        current_line = read_file.readline()
        ciphertext_str = (current_line.split('=')[1]).strip()
        ciphertext = bytearray.fromhex(ciphertext_str)
        message = crypto_aead_decrypt_with_key_tag(ciphertext, associated_data, None, nonce, key, key_tag_bytes, tag_bytes)
        if(message == None):
            print("Count = " + str(count) + '\n')
            print("Key = " + key_str + '\n')
            print("Nonce = " + nonce_str + '\n')
            print("PT = " + message_str + '\n')
            print("AD = " + associated_data_str + '\n')
            print("CT = " + ciphertext_str + '\n')
            print("\n")
            break
        current_line = read_file.readline() # There is one blank line between tests
        current_line = read_file.readline()
    read_file.close()

generate_aead_test("../data_tests/AEAD_INT_KAT.txt")
verify_aead_test(test_file_name = "../data_tests/AEAD_INT_KAT.txt")