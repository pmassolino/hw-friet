#!/usr/bin/env python3
# -*- coding: utf-8 -*-

friet_rc = [0x1111, 0x11100000, 0x1101, 0x10100000, 0x101, 0x10110000, 0x110, 0x11000000, 0x1001, 0x100000, 0x100, 0x10000000, 0x1, 0x110000, 0x111, 0x11110000, 0x1110, 0x11010000, 0x1010, 0x1010000, 0x1011, 0x1100000, 0x1100, 0x10010000]

def friet_rol(a, value):
    return (((a << value) & 2**128-1) | (a >> (128-value)) & 2**128-1)

def friet_state_check_parity(state):
    parity = state[0] ^ state[1] ^ state[2] ^ state[3]
    return (parity == 0)

def friet_p(state):
    new_state = list(state)
    j = 0
    for i in range(0, 24):
        # Delta operation
        new_state[2] = new_state[2] ^ friet_rc[i]
        new_state[3] = new_state[3] ^ friet_rc[j]
        # Mu 1 operation
        new_state[1] = new_state[1] ^ friet_rol(new_state[0], 1)
        new_state[2] = new_state[2] ^ friet_rol(new_state[0], 1)
        # Mu 2 operation
        new_state[0] = new_state[0] ^ friet_rol(new_state[2], 80)
        new_state[1] = new_state[1] ^ friet_rol(new_state[2], 80)
        # Xi operation
        new_state[2] = new_state[2] ^ (friet_rol(new_state[1], 36) & friet_rol(new_state[0], 67))
        new_state[3] = new_state[3] ^ (friet_rol(new_state[1], 36) & friet_rol(new_state[0], 67))
        # Tau 1+2 operation
        new_state = [new_state[3], new_state[1], new_state[0], new_state[2]]
        j = j + 1
    return new_state

def friet_sponge_duplex(state, sigma, b):
    sigma_padded = sigma + bytearray([b+2]) + bytearray(17-len(sigma)-1)
    state_rate = state[0].to_bytes(16, 'little') + (state[1] & 0xFF).to_bytes(1, 'little')
    state_parity = state[3].to_bytes(16, 'little')
    new_state_rate = [state_rate[j] ^ sigma_padded[j] for j in range(17)]
    new_state_parity = [state_parity[j] ^ sigma_padded[j] for j in range(16)]
    new_state_parity[0] = new_state_parity[0] ^ sigma_padded[16]
    state[0] = int.from_bytes(new_state_rate[0:16], 'little', signed=False)
    state[1] = (state[1] & 2**128-256) | int.from_bytes(new_state_rate[16:], 'little', signed=False)
    state[3] = int.from_bytes(new_state_parity, 'little', signed=False)
    state = friet_p(state)
    return state

def friet_sponge_absorb_none(state, x):
    i = 0
    while(i < len(x)-16):
        state = friet_sponge_duplex(state, x[i:(i+16)], 0)
        i = i + 16
    state = friet_sponge_duplex(state, x[i:], 1)
    return state

def friet_sponge_absorb_encrypt(state, x):
    i = 0
    y = bytearray()
    while(i < len(x)-16):
        state_out = state[0].to_bytes(16, 'little')
        temp = bytearray([state_out[j] ^ x[i+j] for j in range(16)])
        y = y + temp
        state = friet_sponge_duplex(state, x[i:(i+16)], 1)
        i = i + 16
    state_out = state[0].to_bytes(16, 'little')
    temp = bytearray([state_out[j] ^ x[i+j] for j in range(len(x[i:]))])
    y = y + temp
    state = friet_sponge_duplex(state, x[i:], 0)
    return state, y

def friet_sponge_absorb_decrypt(state, x):
    i = 0
    y = bytearray()
    while(i < len(x)-16):
        state_out = state[0].to_bytes(16, 'little')
        temp = bytearray([state_out[j] ^ x[i+j] for j in range(16)])
        y = y + temp
        state = friet_sponge_duplex(state, temp, 1)
        i = i + 16
    state_out = state[0].to_bytes(16, 'little')
    temp = bytearray([state_out[j] ^ x[i+j] for j in range(len(x[i:]))])
    y = y + temp
    state = friet_sponge_duplex(state, temp, 0)
    return state, y

def friet_sponge_squeeze(state, l):
    i = 0
    z = bytearray()
    null_array = bytearray(0)
    while(len(z) < l):
        state_out = state[0].to_bytes(16, 'little')
        z = z + state_out
        state = friet_sponge_duplex(state, null_array, 0)
    z = z[0:l]
    return state, z

def friet_sponge_start(key, distinguisher):
    state = [0, 0, 0, 0]
    state = friet_sponge_absorb_none(state, key)
    state, _ = friet_sponge_absorb_encrypt(state, distinguisher)
    state, tag = friet_sponge_squeeze(state, 16)
    return state, tag

def friet_sponge_wrap(state, ad, plaintext):
    state = friet_sponge_absorb_none(state, ad)
    state, ciphertext = friet_sponge_absorb_encrypt(state, plaintext)
    state, tag = friet_sponge_squeeze(state, 16)
    return state, ciphertext, tag

def friet_sponge_unwrap(state, ad, ciphertext, tag):
    state = friet_sponge_absorb_none(state, ad)
    state, plaintext = friet_sponge_absorb_decrypt(state, ciphertext)
    state, tag_p = friet_sponge_squeeze(state, 16)
    match_tag = (tag_p == tag)
    match_parity = friet_state_check_parity(state)
    e_plaintext = None
    e_state = None
    if(match_tag and match_parity):
        f_plaintext = plaintext
        f_state = state
    else:
        f_plaintext = e_plaintext
        f_state = e_state
    return f_state, f_plaintext

def crypto_aead_encrypt(m, ad, nsec, npub, k, t_length_bytes):
    state, _ = friet_sponge_start(k, npub)
    state, ciphertext, tag = friet_sponge_wrap(state, ad, m)
    c = ciphertext + tag
    return c

def crypto_aead_decrypt(c, ad, nsec, npub, k, t_length_bytes):
    state, _ = friet_sponge_start(k, npub)
    ciphertext_length = len(c) - t_length_bytes
    ciphertext, tag = c[0:ciphertext_length], c[ciphertext_length:]
    state, plaintext = friet_sponge_unwrap(state, ad, ciphertext, tag)
    if((state == None) or (plaintext == None)):
        f_plaintext = None
    else:
        f_plaintext = plaintext
    return f_plaintext

if __name__ == "__main__":
    K = bytearray([0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F])
    D = bytearray([0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F])
    
    max_bytes_a = 0
    max_bytes_p = 16
    A = bytearray([i for i in range(max_bytes_a)])
    P = bytearray([i for i in range(max_bytes_p)])
    
    state, KT = friet_sponge_start(K, D)
    print("KT = " + KT.hex())
    state, C, T = friet_sponge_wrap(state, A, P)
    print("C = " + C.hex())
    print("T = " + T.hex())
    state, KT2 = friet_sponge_start(K, D)
    print("Matches Key Tag = " + str(KT == KT2))
    state, Pp = friet_sponge_unwrap(state, A, C, T)
    if(Pp != None):
        print("P  = " + P.hex())
        print("Pp = " + Pp.hex())
    print("Matches = " + str(Pp == P))
    