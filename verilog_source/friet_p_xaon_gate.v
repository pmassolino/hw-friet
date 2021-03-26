/**
 Implementation by Pedro Maat C. Massolino,
 hereby denoted as "the implementer".

 To the extent possible under law, the implementer has waived all copyright
 and related or neighboring rights to the source code in this file.
 http://creativecommons.org/publicdomain/zero/1.0/
*/
`default_nettype    none

module friet_p_xaon_gate
(
    output wire o,
    input wire a,
    input wire b,
    input wire c
);

assign o = (a&b)^c;

endmodule