#!/usr/bin/env python3
# -*- coding: utf-8 -*-

def bits_to_hex_string(in_bits, big_endian=True):
    string_state = ""
    if(len(in_bits)%8 == 0):
        final_position = len(in_bits) - 8
    else:
        final_position = len(in_bits) - (len(in_bits)%8)
    for i in range(0, final_position, 8):
        temp_value = in_bits[i] + 2*in_bits[i+1] + 4*in_bits[i+2] + 8*in_bits[i+3] + 16*in_bits[i+4] + 32*in_bits[i+5] + 64*in_bits[i+6] + 128*in_bits[i+7]
        if(big_endian):
            string_state = string_state + "{0:02x}".format(temp_value)
        else:
            string_state = "{0:02x}".format(temp_value) + string_state
    mult_factor = 1
    temp_value = 0
    for i in range(final_position, len(in_bits)):
        temp_value += mult_factor*in_bits[i]
        mult_factor *= 2
    if(big_endian):
        string_state = string_state + "{0:02x}".format(temp_value)
    else:
        string_state = "{0:02x}".format(temp_value) + string_state
    return string_state

def bytearray_to_bits(value):
    value_bits = [((int(value[i//8]) & (1 << (i%8))) >> (i%8)) for i in range(len(value)*8)]
    return value_bits

def bits_to_bytearray(value):
    value_bytearray = bytearray((len(value)+7)//8)
    if(len(value) != 0):
        if(len(value)%8 == 0):
            final_position = len(value) - 8
        else:
            final_position = len(value) - (len(value)%8)
        j = 0
        for i in range(0, final_position, 8):
            value_bytearray[j] = value[i] + 2*value[i+1] + 4*value[i+2] + 8*value[i+3] + 16*value[i+4] + 32*value[i+5] + 64*value[i+6] + 128*value[i+7]
            j += 1
        mult_factor = 1
        value_bytearray[j] = 0
        for i in range(final_position, len(value)):
            value_bytearray[j] += mult_factor*value[i]
            mult_factor *= 2
    return value_bytearray

friet_rc = [0x1111, 0x11100000, 0x1101, 0x10100000, 0x101, 0x10110000, 0x110, 0x11000000, 0x1001, 0x100000, 0x100, 0x10000000, 0x1, 0x110000, 0x111, 0x11110000, 0x1110, 0x11010000, 0x1010, 0x1010000, 0x1011, 0x1100000, 0x1100, 0x10010000]

def friet_rol(a, value):
    return (((a << value) & 2**128-1) | (a >> (128-value)) & 2**128-1)

def friet_pc(state):
    new_state = list(state)
    for i in range(0, 24):
        # Delta operation
        new_state[2] = new_state[2] ^ friet_rc[i]
        # Tau 1 operation
        new_state = [new_state[0] ^ new_state[1] ^ new_state[2], new_state[2], new_state[0]]
        # Mu 1 operation
        new_state[1] = new_state[1] ^ friet_rol(new_state[2], 1)
        # Mu 2 operation
        new_state[2] = new_state[2] ^ friet_rol(new_state[1], 80)
        # Tau 2 operation
        new_state = [new_state[0], new_state[0] ^ new_state[1] ^ new_state[2], new_state[2]]
        # Xi operation
        new_state[0] = new_state[0] ^ (friet_rol(new_state[1], 36) & friet_rol(new_state[2], 67))
    return new_state

def friet_sponge_duplex(state, sigma, b):
    sigma_padded = sigma + [b] + [1] + [0 for j in range(130-len(sigma)-2)]
    state_rate = bytearray_to_bits(state[0].to_bytes(16, 'little')) + bytearray_to_bits((state[1] & 0xFF).to_bytes(1, 'little'))[0:2]
    new_state_rate = [state_rate[j] ^ sigma_padded[j] for j in range(130)]
    state[0] = int.from_bytes(bits_to_bytearray(new_state_rate[0:128]), 'little', signed=False)
    state[1] = (state[1] & 2**128-4) | int.from_bytes(bits_to_bytearray(new_state_rate[128:]), 'little', signed=False)
    state = friet_pc(state)
    return state

def friet_sponge_absorb_none(state, x):
    i = 0
    while(i < len(x)-128):
        state = friet_sponge_duplex(state, x[i:(i+128)], 0)
        i = i + 128
    state = friet_sponge_duplex(state, x[i:], 1)
    return state

def friet_sponge_absorb_encrypt(state, x):
    i = 0
    y = []
    while(i < len(x)-128):
        state_out = bytearray_to_bits(state[0].to_bytes(16, 'little'))
        temp = [state_out[j] ^ x[i+j] for j in range(128)]
        y = y + temp
        state = friet_sponge_duplex(state, x[i:(i+128)], 1)
        i = i + 128
    state_out = bytearray_to_bits(state[0].to_bytes(16, 'little'))
    temp = [state_out[j] ^ x[i+j] for j in range(len(x[i:]))]
    y = y + temp
    state = friet_sponge_duplex(state, x[i:], 0)
    return state, y

def friet_sponge_absorb_decrypt(state, x):
    i = 0
    y = []
    while(i < len(x)-128):
        state_out = bytearray_to_bits(state[0].to_bytes(16, 'little'))
        temp = [state_out[j] ^ x[i+j] for j in range(128)]
        y = y + temp
        state = friet_sponge_duplex(state, temp, 1)
        i = i + 128
    state_out = bytearray_to_bits(state[0].to_bytes(16, 'little'))
    temp = [state_out[j] ^ x[i+j] for j in range(len(x[i:]))]
    y = y + temp
    state = friet_sponge_duplex(state, temp, 0)
    return state, y

def friet_sponge_squeeze(state, l):
    i = 0
    z = []
    while(len(z) < l):
        state_out = bytearray_to_bits(state[0].to_bytes(16, 'little'))
        z = z + state_out
        state = friet_sponge_duplex(state, [], 0)
    z = z[0:l]
    return state, z

def friet_sponge_start(key, distinguisher, key_tag_bytes):
    state = [0, 0, 0]
    state = friet_sponge_absorb_none(state, key)
    state, _ = friet_sponge_absorb_encrypt(state, distinguisher)
    state, tag = friet_sponge_squeeze(state, key_tag_bytes)
    return state, tag

def friet_sponge_wrap(state, ad, plaintext, tag_bytes):
    state = friet_sponge_absorb_none(state, ad)
    state, ciphertext = friet_sponge_absorb_encrypt(state, plaintext)
    state, tag = friet_sponge_squeeze(state, tag_bytes)
    return state, ciphertext, tag

def friet_sponge_unwrap(state, ad, ciphertext, tag):
    state = friet_sponge_absorb_none(state, ad)
    state, plaintext = friet_sponge_absorb_decrypt(state, ciphertext)
    state, tag_p = friet_sponge_squeeze(state, len(tag))
    match_tag = (tag_p == tag)
    e_plaintext = None
    e_state = None
    if(match_tag):
        f_plaintext = plaintext
        f_state = state
    else:
        f_plaintext = e_plaintext
        f_state = e_state
    return f_state, f_plaintext

def crypto_aead_encrypt(m, ad, nsec, npub, k, t_length_bytes):
    state, _ = friet_sponge_start(bytearray_to_bits(k), bytearray_to_bits(npub), 128)
    state, ciphertext_bits, tag_bits = friet_sponge_wrap(state, bytearray_to_bits(ad), bytearray_to_bits(m), t_length_bytes*8)
    ciphertext = bits_to_bytearray(ciphertext_bits)
    tag = bits_to_bytearray(tag_bits)
    c = ciphertext + tag
    return c

def crypto_aead_decrypt(c, ad, nsec, npub, k, t_length_bytes):
    state, _ = friet_sponge_start(bytearray_to_bits(k), bytearray_to_bits(npub), 128)
    ciphertext_length = len(c) - t_length_bytes
    ciphertext, tag = c[0:ciphertext_length], c[ciphertext_length:]
    state, plaintext_bits = friet_sponge_unwrap(state, bytearray_to_bits(ad), bytearray_to_bits(ciphertext), bytearray_to_bits(tag))
    if((state == None) or (plaintext_bits == None)):
        f_plaintext = None
    else:
        f_plaintext = bits_to_bytearray(plaintext_bits)
    return f_plaintext

def crypto_aead_encrypt_with_key_tag(m, ad, nsec, npub, k, kt_length_bytes, t_length_bytes):
    state, ktag_bits = friet_sponge_start(bytearray_to_bits(k), bytearray_to_bits(npub), kt_length_bytes*8)
    state, ciphertext_bits, tag_bits = friet_sponge_wrap(state, bytearray_to_bits(ad), bytearray_to_bits(m), t_length_bytes*8)
    ktag = bits_to_bytearray(ktag_bits)
    ciphertext = bits_to_bytearray(ciphertext_bits)
    tag = bits_to_bytearray(tag_bits)
    c = ktag + ciphertext + tag
    return c

def crypto_aead_decrypt_with_key_tag(c, ad, nsec, npub, k, kt_length_bytes, t_length_bytes):
    ciphertext_length = len(c) - kt_length_bytes - t_length_bytes
    ktag, ciphertext, tag = c[0:kt_length_bytes], c[kt_length_bytes:(kt_length_bytes+ciphertext_length)], c[(kt_length_bytes+ciphertext_length):]
    state, ktag_p_bits = friet_sponge_start(bytearray_to_bits(k), bytearray_to_bits(npub), kt_length_bytes*8)
    ktag_p = bits_to_bytearray(ktag_p_bits)
    state, plaintext_bits = friet_sponge_unwrap(state, bytearray_to_bits(ad), bytearray_to_bits(ciphertext), bytearray_to_bits(tag))
    if(((state == None) or (plaintext_bits == None)) or (ktag_p != ktag)):
        f_plaintext = None
    else:
        f_plaintext = bits_to_bytearray(plaintext_bits)
    return f_plaintext

if __name__ == "__main__":
    K = bytearray([0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F])
    D = bytearray([0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F])
    
    max_bytes_a = 0
    max_bytes_p = 16
    A = bytearray([i for i in range(max_bytes_a)])
    P = bytearray([i for i in range(max_bytes_p)])
    
    
    state, KT = friet_sponge_start(K, D, 16)
    print("KT = " + KT.hex())
    state, C, T = friet_sponge_wrap(state, A, P, 16)
    print("C = " + C.hex())
    print("T = " + T.hex())
    state, KT2 = friet_sponge_start(K, D, 16)
    print("Matches Key Tag = " + str(KT == KT2))
    state, Pp = friet_sponge_unwrap(state, A, C, T)
    if(Pp != None):
        print("P  = " + P.hex())
        print("Pp = " + Pp.hex())
    print("Matches = " + str(Pp == P))
    