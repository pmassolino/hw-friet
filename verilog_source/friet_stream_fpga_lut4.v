/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

module friet_stream_fpga_lut4
#(parameter ASYNC_RSTN = 1,           // 0 - Synchronous reset in high, 1 - Asynchrouns reset in low.
parameter COMBINATIONAL_ROUNDS = 1,   // Number of unrolled combinational rounds possible (Supported sizes : 1, 2, 3, 4, 6, 8, 12)
parameter KEY_AE_TAG_SIZE_LENGTH = 1, // The counter length to fit both key and tag size
parameter [KEY_AE_TAG_SIZE_LENGTH-1:0] KEY_TAG_SIZE = 1'd0, // Key tag size in words of 128 bits. The number is one smaller, for example 0 is 1 word.
parameter [KEY_AE_TAG_SIZE_LENGTH-1:0] AE_TAG_SIZE = 1'd0,  // AE Tag size in words of 128 bits. The number is one smaller, for example 0 is 1 word.
parameter DIN_DOUT_WIDTH = 32,        // The width of ports din and dout (Supported sizes : 8, 16, 32, 64)
parameter DIN_DOUT_SIZE_WIDTH = 2)    // DIN_DOUT_WIDTH = 8,  DIN_DOUT_SIZE_WIDTH = 0
                              // DIN_DOUT_WIDTH = 16, DIN_DOUT_SIZE_WIDTH = 1
                              // DIN_DOUT_WIDTH = 32, DIN_DOUT_SIZE_WIDTH = 2
                              // DIN_DOUT_WIDTH = 64, DIN_DOUT_SIZE_WIDTH = 4
(
    input wire clk,
    input wire arstn,
    // Data in bus
    input wire [(DIN_DOUT_WIDTH-1):0] din,
    input wire [DIN_DOUT_SIZE_WIDTH:0] din_size,
    input wire din_last,
    input wire din_valid,
    output wire din_ready,
    // Instruction bus
    input wire [3:0] inst,
    input wire inst_valid,
    output wire inst_ready,
    // Data out bus
    output wire [(DIN_DOUT_WIDTH-1):0] dout,
    output wire [DIN_DOUT_SIZE_WIDTH:0] dout_size,
    output wire dout_last,
    output wire dout_valid,
    input wire dout_ready,
    // Fault detection
    output wire fault_detected
);

reg [3:0] reg_inst, next_inst;
wire int_inst_ready;
wire sm_inst_ready;

wire inst_valid_and_ready;

reg int_din_ready;
wire sm_din_ready;
wire sm_p_core_din_valid;

wire sm_p_core_din_last;

// Buffer in

wire din_valid_and_ready;

wire buffer_in_din_oper;

wire buffer_in_rst;
reg [(DIN_DOUT_WIDTH-1):0] buffer_in_din;
reg [DIN_DOUT_SIZE_WIDTH:0] buffer_in_din_size;
reg buffer_in_din_last;
reg buffer_in_din_valid;
wire buffer_in_din_ready;
wire [127:0] buffer_in_dout;
wire [4:0] buffer_in_dout_size;
wire buffer_in_dout_valid;
reg buffer_in_dout_ready;
wire buffer_in_dout_last;
wire buffer_in_size_full;
wire buffer_in_next_size_full;


// Permutation core (Friet_C)

wire p_core_din_valid_and_ready;

wire [1:0] p_core_din_oper;

wire [2:0] p_core_oper;
reg [127:0] p_core_din;
reg [4:0] p_core_din_size;
reg p_core_din_valid;
wire p_core_din_ready;
reg p_core_din_last;
wire [1:0] p_core_din_type;
wire [127:0] p_core_dout;
wire p_core_dout_valid;
reg p_core_dout_ready;
wire [4:0] p_core_dout_size;
wire p_core_dout_last;
wire [1:0] p_core_dout_type;
wire p_core_fault_detected;

wire p_core_dout_valid_and_ready;

reg reg_p_core_last, next_p_core_last;

// Buffer out

wire [1:0] buffer_out_din_oper;

wire buffer_out_rst;
wire [127:0] buffer_out_din;
wire [4:0] buffer_out_din_size;
wire buffer_out_din_last;
reg buffer_out_din_valid;
wire buffer_out_din_ready;
wire [(DIN_DOUT_WIDTH-1):0] buffer_out_dout;
wire [DIN_DOUT_SIZE_WIDTH:0] buffer_out_dout_size;
wire buffer_out_dout_valid;
reg buffer_out_dout_ready;
wire buffer_out_dout_last;
wire [4:0] buffer_out_size;

// Dout signals

wire [1:0] dout_oper;

wire dout_valid_and_ready;

reg [(DIN_DOUT_WIDTH-1):0] int_dout;
reg [DIN_DOUT_SIZE_WIDTH:0] int_dout_size;
reg int_dout_last;
reg int_dout_valid;

// Tag comparison

reg [127:0] reg_compare_tag, next_compare_tag;
wire reg_compare_tag_valid_and_ready;
wire reg_compare_tag_rst;
wire reg_compare_tag_enable;

reg is_reg_compare_tag_equal_zero;

// Counter tag

reg [KEY_AE_TAG_SIZE_LENGTH-1:0] reg_ctr_tag_size, next_ctr_tag_size;

wire reg_ctr_tag_size_rst;
wire [1:0] reg_ctr_tag_size_oper;
reg is_reg_ctr_tag_size_zero;
reg is_reg_ctr_tag_size_one;

// Instruction register

assign inst_valid_and_ready = int_inst_ready & inst_valid;

always @(posedge clk) begin
    reg_inst <= next_inst;
end

always @(*) begin
    if((inst_valid_and_ready == 1'b1)) begin
        next_inst = inst;
    end else if((inst_valid_and_ready == 1'b0)) begin
        next_inst = reg_inst;
    end else begin
        next_inst = {4{1'bx}};
    end
end

// Buffer in

assign din_valid_and_ready = din_valid & int_din_ready;

always @(*) begin
    buffer_in_din = din;
    buffer_in_din_size = din_size;
    buffer_in_din_last = din_last;
    if(buffer_in_din_oper == 1'b1) begin
        buffer_in_din_valid = 1'b0;
        int_din_ready = 1'b0;
    end else if(buffer_in_din_oper == 1'b0) begin
        buffer_in_din_valid = din_valid;
        int_din_ready = buffer_in_din_ready;
    end else begin
        buffer_in_din_valid = 1'bx;
        int_din_ready = 1'bx;
    end
end

friet_stream_buffer_in
#(.DIN_WIDTH(DIN_DOUT_WIDTH),
.DIN_SIZE_WIDTH(DIN_DOUT_SIZE_WIDTH),
.DOUT_WIDTH(128),
.DOUT_SIZE_WIDTH(4))
buffer_in
(
    .clk(clk),
    .rst(buffer_in_rst),
    .din(buffer_in_din),
    .din_size(buffer_in_din_size),
    .din_last(buffer_in_din_last),
    .din_valid(buffer_in_din_valid),
    .din_ready(buffer_in_din_ready),
    .dout(buffer_in_dout),
    .dout_size(buffer_in_dout_size),
    .dout_valid(buffer_in_dout_valid),
    .dout_ready(buffer_in_dout_ready),
    .dout_last(buffer_in_dout_last),
    .reg_buffer_size_full(buffer_in_size_full),
    .next_buffer_size_full(buffer_in_next_size_full)
);

assign p_core_din_valid_and_ready = p_core_din_valid & p_core_din_ready;

// Permutation core

always @(*) begin
    case(p_core_din_oper)
        // Disabled
        2'b01 : begin
            p_core_din = 128'b00;
            p_core_din_size = 5'b00000;
            p_core_din_valid = 1'b0;
            p_core_din_last = 1'b0;
            buffer_in_dout_ready = 1'b0;
        end
        // Insert 0
        2'b10 : begin
            p_core_din = 128'b00;
            p_core_din_size = 5'b00000;
            p_core_din_valid = 1'b1;
            p_core_din_last = sm_p_core_din_last;
            buffer_in_dout_ready = 1'b0;
        end
        // Tag mode
        2'b11 : begin
            p_core_din = 128'b00;
            p_core_din_size = 5'b00000;
            p_core_din_valid = 1'b0;
            p_core_din_last = sm_p_core_din_last;
            buffer_in_dout_ready = p_core_dout_valid;
        end
        // Connected to buffer
        2'b00 : begin
            p_core_din = buffer_in_dout;
            p_core_din_size = buffer_in_dout_size;
            p_core_din_valid = buffer_in_dout_valid;
            p_core_din_last = buffer_in_dout_last;
            buffer_in_dout_ready = p_core_din_ready;
        end
        default : begin
            p_core_din = {128{1'bx}};
            p_core_din_size = {5{1'bx}};
            p_core_din_valid = 1'bx;
            p_core_din_last = 1'bx;
            buffer_in_dout_ready = 1'bx;
        end
    endcase
end

friet_p_rounds_simple_fpga_lut4
#(.ASYNC_RSTN(ASYNC_RSTN),
.COMBINATIONAL_ROUNDS(COMBINATIONAL_ROUNDS))
p_core
(
    .clk(clk),
    .arstn(arstn),
    .oper(p_core_oper),
    .din(p_core_din),
    .din_size(p_core_din_size),
    .din_valid(p_core_din_valid),
    .din_ready(p_core_din_ready),
    .din_last(p_core_din_last),
    .dout(p_core_dout),
    .dout_valid(p_core_dout_valid),
    .dout_ready(p_core_dout_ready),
    .dout_size(p_core_dout_size),
    .dout_last(p_core_dout_last),
    .fault_detected(p_core_fault_detected)
);

// Buffer out

assign p_core_dout_valid_and_ready = p_core_dout_ready & p_core_dout_valid;

always @(*) begin
    case(buffer_out_din_oper)
        // Disabled
        2'b01 : begin
            buffer_out_din_valid = 1'b0;
            p_core_dout_ready = 1'b0;
        end
        // Ignore output
        2'b10 : begin
            buffer_out_din_valid = 1'b0;
            p_core_dout_ready = 1'b1;
        end
        // Tag mode
        2'b11 : begin
            buffer_out_din_valid = 1'b0;
            p_core_dout_ready = buffer_in_dout_valid;
        end
        // Permutation core
        2'b00 : begin
            buffer_out_din_valid = p_core_dout_valid;
            p_core_dout_ready = buffer_out_din_ready;
        end
        default : begin
            buffer_out_din_valid = 1'bx;
            p_core_dout_ready = 1'bx;
        end
    endcase
end

assign buffer_out_din = p_core_dout;
assign buffer_out_din_size = p_core_dout_size;
assign buffer_out_din_last = p_core_dout_last;

friet_stream_buffer_out
#(.DIN_WIDTH(128),
.DIN_SIZE_WIDTH(4),
.DOUT_WIDTH(DIN_DOUT_WIDTH),
.DOUT_SIZE_WIDTH(DIN_DOUT_SIZE_WIDTH))
buffer_out
(
    .clk(clk),
    .rst(buffer_out_rst),
    .din(buffer_out_din),
    .din_size(buffer_out_din_size),
    .din_last(buffer_out_din_last),
    .din_valid(buffer_out_din_valid),
    .din_ready(buffer_out_din_ready),
    .dout(buffer_out_dout),
    .dout_size(buffer_out_dout_size),
    .dout_valid(buffer_out_dout_valid),
    .dout_ready(buffer_out_dout_ready),
    .dout_last(buffer_out_dout_last),
    .size(buffer_out_size)
);

// Dout connection

assign dout_valid_and_ready = int_dout_valid & dout_ready;

always @(*) begin
    case(dout_oper)
        // Disabled
        2'b01 : begin
            int_dout = {DIN_DOUT_WIDTH{1'b0}};
            int_dout_size = {(DIN_DOUT_SIZE_WIDTH+1){1'b0}};
            int_dout_last = 1'b0;
            int_dout_valid = 1'b0;
            buffer_out_dout_ready = 1'b0;
        end
        // Tag mode
        2'b11 : begin
            int_dout[(DIN_DOUT_WIDTH-1):4] = {DIN_DOUT_WIDTH-4{1'b0}};
            int_dout[3:1]  = 3'b111;
            int_dout[0]    = (~is_reg_compare_tag_equal_zero) | p_core_fault_detected;
            int_dout_size = {{DIN_DOUT_SIZE_WIDTH{1'b0}}, 1'b1};
            int_dout_last = 1'b1;
            int_dout_valid = 1'b1;
            buffer_out_dout_ready = 1'b0;
        end
        // Buffer connected to the output
        2'b00, 2'b10 : begin
            int_dout = buffer_out_dout;
            int_dout_size = buffer_out_dout_size;
            int_dout_last = buffer_out_dout_last;
            int_dout_valid = buffer_out_dout_valid;
            buffer_out_dout_ready = dout_ready;
        end
        default : begin
            int_dout = {DIN_DOUT_WIDTH{1'bx}};
            int_dout_size = {(DIN_DOUT_SIZE_WIDTH+1){1'bx}};
            int_dout_last = 1'bx;
            int_dout_valid = 1'bx;
            buffer_out_dout_ready = 1'bx;
        end
    endcase
end

assign reg_compare_tag_valid_and_ready = buffer_in_dout_valid & p_core_dout_valid;

always @(posedge clk) begin
    reg_compare_tag <= next_compare_tag;
end

always @(*) begin
    if(reg_compare_tag_rst == 1'b1) begin
        next_compare_tag = 128'b00;
    end else if(reg_compare_tag_rst == 1'b0) begin
        if((reg_compare_tag_enable == 1'b1) && (reg_compare_tag_valid_and_ready == 1'b1)) begin
            next_compare_tag = reg_compare_tag | (p_core_dout ^ buffer_in_dout);
        end else if (((reg_compare_tag_enable == 1'b0) || (reg_compare_tag_valid_and_ready == 1'b0))) begin
            next_compare_tag = reg_compare_tag;
        end else begin
            next_compare_tag = {128{1'bx}};
        end
    end else begin
        next_compare_tag = {128{1'bx}};
    end
end

always @(*) begin
    if(reg_compare_tag == {128{1'b0}}) begin
        is_reg_compare_tag_equal_zero = 1'b1;
    end else if(reg_compare_tag != {128{1'b0}}) begin
        is_reg_compare_tag_equal_zero = 1'b0;
    end else begin
        is_reg_compare_tag_equal_zero = 1'bx;
    end
end

// Counter for Tag size

always @(posedge clk) begin
    reg_ctr_tag_size <= next_ctr_tag_size;
end

always @(*) begin
    if(reg_ctr_tag_size_rst == 1'b1) begin
        next_ctr_tag_size = {KEY_AE_TAG_SIZE_LENGTH{1'b0}};
    end else if(reg_ctr_tag_size_rst == 1'b0) begin
        case(reg_ctr_tag_size_oper)
            // Do nothing
            2'b00 : begin
                next_ctr_tag_size = reg_ctr_tag_size;
            end
            // Load counter key tag size
            2'b01 : begin
                next_ctr_tag_size = KEY_TAG_SIZE;
            end
            // Load counter ae tag size
            2'b10 : begin
                next_ctr_tag_size = AE_TAG_SIZE;
            end
            // Decrement
            2'b11 : begin
                if(p_core_din_valid_and_ready == 1'b1) begin
                    next_ctr_tag_size = reg_ctr_tag_size-1;
                end else if(p_core_din_valid_and_ready == 1'b0) begin
                    next_ctr_tag_size = reg_ctr_tag_size;
                end else begin
                    next_ctr_tag_size = {KEY_AE_TAG_SIZE_LENGTH{1'bx}};
                end
            end
            default : begin
                next_ctr_tag_size = {KEY_AE_TAG_SIZE_LENGTH{1'bx}};
            end
        endcase
    end else begin
        next_ctr_tag_size = {KEY_AE_TAG_SIZE_LENGTH{1'bx}};
    end
end

always @(*) begin
    if(reg_ctr_tag_size == {KEY_AE_TAG_SIZE_LENGTH{1'b0}}) begin
        is_reg_ctr_tag_size_zero = 1'b1;
    end else if(reg_ctr_tag_size != {KEY_AE_TAG_SIZE_LENGTH{1'b0}}) begin
        is_reg_ctr_tag_size_zero = 1'b0;
    end else begin
        is_reg_ctr_tag_size_zero = 1'bx;
    end
end

always @(*) begin
    if(reg_ctr_tag_size == {{(KEY_AE_TAG_SIZE_LENGTH-1){1'b0}},1'b1}) begin
        is_reg_ctr_tag_size_one = 1'b1;
    end else if(reg_ctr_tag_size != {{(KEY_AE_TAG_SIZE_LENGTH-1){1'b0}},1'b1}) begin
        is_reg_ctr_tag_size_one = 1'b0;
    end else begin
        is_reg_ctr_tag_size_one = 1'bx;
    end
end

friet_stream_state_machine
#(.ASYNC_RSTN(ASYNC_RSTN),
.KEY_AE_TAG_SIZE_LENGTH(KEY_AE_TAG_SIZE_LENGTH),
.KEY_TAG_SIZE(KEY_TAG_SIZE),
.AE_TAG_SIZE(AE_TAG_SIZE))
state_machine
(
    .clk(clk),
    .arstn(arstn),
    // Buffer in
    .din_last(din_last),
    .din_valid_and_ready(din_valid_and_ready),
    .buffer_in_rst(buffer_in_rst),
    .buffer_in_din_oper(buffer_in_din_oper),
    .buffer_in_size_full(buffer_in_size_full),
    .buffer_in_next_size_full(buffer_in_next_size_full),
    // Instruction bus
    .inst(inst),
    .inst_valid_and_ready(inst_valid_and_ready),
    .inst_ready(sm_inst_ready),
    .reg_inst(reg_inst),
    // Permutation core
    .p_core_din_valid_and_ready(p_core_din_valid_and_ready),
    .p_core_din_oper(p_core_din_oper),
    .p_core_oper(p_core_oper),
    .sm_p_core_din_last(sm_p_core_din_last),
    .p_core_dout_valid_and_ready(p_core_dout_valid_and_ready),
    // Buffer out 
    .buffer_out_dout_last(buffer_out_dout_last),
    .buffer_out_rst(buffer_out_rst),
    .buffer_out_din_oper(buffer_out_din_oper),
    // Tag compare register
    .reg_compare_tag_valid_and_ready(reg_compare_tag_valid_and_ready),
    .reg_compare_tag_rst(reg_compare_tag_rst),
    .reg_compare_tag_enable(reg_compare_tag_enable),
    // Counter tag size
    .reg_ctr_tag_size_rst(reg_ctr_tag_size_rst),
    .reg_ctr_tag_size_oper(reg_ctr_tag_size_oper),
    .is_reg_ctr_tag_size_zero(is_reg_ctr_tag_size_zero),
    .is_reg_ctr_tag_size_one(is_reg_ctr_tag_size_one),
    // Dout
    .dout_valid_and_ready(dout_valid_and_ready),
    .dout_oper(dout_oper)
);

assign dout = int_dout;
assign dout_size = int_dout_size;
assign dout_last = int_dout_last;
assign dout_valid = int_dout_valid;

assign din_ready = int_din_ready;

assign int_inst_ready = sm_inst_ready;
assign inst_ready = int_inst_ready;

assign fault_detected = p_core_fault_detected;

endmodule