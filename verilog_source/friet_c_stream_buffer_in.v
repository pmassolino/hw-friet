/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

module friet_c_stream_buffer_in
#(parameter DIN_WIDTH = 32,
parameter DIN_SIZE_WIDTH = 2,
parameter DOUT_WIDTH = 128,
parameter DOUT_SIZE_WIDTH = 4)
(
    input wire clk,
    input wire rst,
    input wire [(DIN_WIDTH-1):0] din,
    input wire [DIN_SIZE_WIDTH:0] din_size,
    input wire din_last,
    input wire din_valid,
    output wire din_ready,
    output wire [(DOUT_WIDTH-1):0] dout,
    output wire [DOUT_SIZE_WIDTH:0] dout_size,
    output wire dout_valid,
    input wire dout_ready,
    output wire dout_last,
    output wire reg_buffer_size_full,
    output wire next_buffer_size_full
);

localparam DIN_WORDS_FOR_DOUT = DOUT_WIDTH/DIN_WIDTH;

wire [DOUT_SIZE_WIDTH:0] din_size_resized;
reg int_din_ready;
wire din_valid_and_ready;

reg int_dout_valid;
wire dout_valid_and_ready;

reg [(DOUT_WIDTH-1):0] reg_buffer, next_buffer;
reg [DOUT_SIZE_WIDTH:0] reg_buffer_size, next_buffer_size;
reg reg_buffer_last, next_buffer_last;
reg [DOUT_SIZE_WIDTH:0] reg_buffer_size_alignment, next_buffer_size_alignment;

reg is_reg_buffer_size_almost_full;
reg is_reg_buffer_size_full;
reg is_next_reg_buffer_size_full;
reg is_reg_buffer_size_empty;

assign din_size_resized = {{DOUT_SIZE_WIDTH-DIN_SIZE_WIDTH{1'b0}}, din_size};

assign din_valid_and_ready  = din_valid & int_din_ready;
assign dout_valid_and_ready = int_dout_valid & dout_ready;

always @(posedge clk) begin
    reg_buffer <= next_buffer;
    reg_buffer_size <= next_buffer_size;
    reg_buffer_last <= next_buffer_last;
    reg_buffer_size_alignment <= next_buffer_size_alignment;
end

always @(*) begin
    if((din_valid_and_ready == 1'b1)) begin
        next_buffer = {din, reg_buffer[(DOUT_WIDTH-1):DIN_WIDTH]};
    end else if((din_valid_and_ready == 1'b0) && (reg_buffer_last == 1'b1) && (is_reg_buffer_size_almost_full == 1'b0)) begin
        next_buffer = {{DIN_WIDTH{1'b0}}, reg_buffer[(DOUT_WIDTH-1):DIN_WIDTH]};
    end else if((din_valid_and_ready == 1'b0) && ((reg_buffer_last == 1'b0) || (is_reg_buffer_size_almost_full == 1'b1))) begin
        next_buffer = reg_buffer;
    end else begin
        next_buffer = {(DOUT_WIDTH){1'bx}};
    end
end

always @(*) begin
    if(reg_buffer_size == 2**DOUT_SIZE_WIDTH) begin
        is_reg_buffer_size_full = 1'b1;
    end else if(reg_buffer_size != 2**DOUT_SIZE_WIDTH) begin
        is_reg_buffer_size_full = 1'b0;
    end else begin
        is_reg_buffer_size_full = 1'bx;
    end
end

always @(*) begin
    if(next_buffer_size == 2**DOUT_SIZE_WIDTH) begin
        is_next_reg_buffer_size_full = 1'b1;
    end else if(next_buffer_size != 2**DOUT_SIZE_WIDTH) begin
        is_next_reg_buffer_size_full = 1'b0;
    end else begin
        is_next_reg_buffer_size_full = 1'bx;
    end
end

always @(*) begin
    if(reg_buffer_size == 0) begin
        is_reg_buffer_size_empty = 1'b1;
    end else if(reg_buffer_size != 0) begin
        is_reg_buffer_size_empty = 1'b0;
    end else begin
        is_reg_buffer_size_empty = 1'bx;
    end
end

/* verilator lint_off WIDTH */

always @(*) begin
    if(reg_buffer_size_alignment > ((DIN_WORDS_FOR_DOUT-1)*(DIN_WIDTH/8))) begin
        is_reg_buffer_size_almost_full = 1'b1;
    end else if(reg_buffer_size_alignment <= ((DIN_WORDS_FOR_DOUT-1)*(DIN_WIDTH/8))) begin
        is_reg_buffer_size_almost_full = 1'b0;
    end else begin
        is_reg_buffer_size_almost_full = 1'bx;
    end
end

/* verilator lint_on WIDTH */

always @(*) begin
    if(rst == 1'b1) begin
        next_buffer_size = {(DOUT_SIZE_WIDTH+1){1'b0}};
    end else if(rst == 1'b0) begin
        if((din_valid_and_ready == 1'b1) && (dout_valid_and_ready == 1'b1)) begin
            next_buffer_size = din_size_resized;
        end else if((din_valid_and_ready == 1'b1) && (dout_valid_and_ready == 1'b0)) begin
            next_buffer_size = reg_buffer_size + din_size_resized;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b1)) begin
            next_buffer_size = 0;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b0)) begin
            next_buffer_size = reg_buffer_size;
        end else begin
            next_buffer_size = {(DOUT_SIZE_WIDTH+1){1'bx}};
        end
    end else begin
        next_buffer_size = {(DOUT_SIZE_WIDTH+1){1'bx}};
    end
end

always @(*) begin
    if(rst == 1'b1) begin
        next_buffer_size_alignment = 0;
    end else if(rst == 1'b0) begin
        if((din_valid_and_ready == 1'b1) && (dout_valid_and_ready == 1'b1)) begin
            next_buffer_size_alignment = din_size_resized;
        end else if((din_valid_and_ready == 1'b1) && (dout_valid_and_ready == 1'b0)) begin
            next_buffer_size_alignment = reg_buffer_size_alignment + din_size_resized;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b1)) begin
            next_buffer_size_alignment = 0;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b0) && (reg_buffer_last == 1'b1) && (is_reg_buffer_size_almost_full == 1'b0)) begin
            next_buffer_size_alignment = reg_buffer_size_alignment + 2**DIN_SIZE_WIDTH;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b0) && ((reg_buffer_last == 1'b0) || (is_reg_buffer_size_almost_full == 1'b1))) begin
            next_buffer_size_alignment = reg_buffer_size_alignment;
        end else begin
            next_buffer_size_alignment = {(DOUT_SIZE_WIDTH+1){1'bx}};
        end
    end else begin
        next_buffer_size_alignment = {(DOUT_SIZE_WIDTH+1){1'bx}};
    end
end

always @(*) begin
    if(rst == 1'b1) begin
        next_buffer_last = 1'b0;
    end else if(rst == 1'b0) begin
        if((din_valid_and_ready == 1'b1)) begin
            next_buffer_last = din_last;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b1)) begin
            next_buffer_last = 1'b0;
        end else if((din_valid_and_ready == 1'b0) && (dout_valid_and_ready == 1'b0)) begin
            next_buffer_last = reg_buffer_last;
        end else begin
            next_buffer_last = 1'bx;
        end
    end else begin
        next_buffer_last = 1'bx;
    end
end

always @(*) begin
    if((is_reg_buffer_size_full == 1'b1)) begin
        int_dout_valid = 1'b1;
    end else if((is_reg_buffer_size_full == 1'b0) && (reg_buffer_last == 1'b1) && (is_reg_buffer_size_almost_full == 1'b1)) begin
        int_dout_valid = 1'b1;
    end else if((is_reg_buffer_size_full == 1'b0) && ((reg_buffer_last == 1'b0) || (is_reg_buffer_size_almost_full == 1'b0))) begin
        int_dout_valid = 1'b0;
    end else begin
        int_dout_valid = 1'bx;
    end
end

always @(*) begin
    if((is_reg_buffer_size_full == 1'b1)) begin
        int_din_ready = dout_valid_and_ready;
    end else if((is_reg_buffer_size_full == 1'b0) && (reg_buffer_last == 1'b1)) begin
        int_din_ready = dout_valid_and_ready;
    end else if((is_reg_buffer_size_full == 1'b0) && (reg_buffer_last == 1'b0)) begin
        int_din_ready = 1'b1;
    end else begin
        int_din_ready = 1'bx;
    end
end

assign din_ready = int_din_ready;
assign dout = reg_buffer;
assign dout_size = reg_buffer_size;
assign dout_valid = int_dout_valid;
assign dout_last = reg_buffer_last;
assign reg_buffer_size_full = is_reg_buffer_size_full;
assign next_buffer_size_full = is_next_reg_buffer_size_full;

endmodule