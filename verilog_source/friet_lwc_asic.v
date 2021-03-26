/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

module friet_lwc_asic
#(parameter ASYNC_RSTN = 0,         // 0 - Synchronous reset in high, 1 - Asynchrouns reset in low.
parameter COMBINATIONAL_ROUNDS = 1, // Number of unrolled combinational rounds possible (Supported sizes : 1, 2, 3, 4, 6, 8, 12)
parameter G_PWIDTH = 32,
parameter G_SWIDTH = 32,
parameter G_SEGMENT_SIZE_BITS = 16
)
(
    input wire clk,
    input wire rst,
    // PDI data bus
    input wire [(G_PWIDTH-1):0] pdi_data,
    input wire pdi_valid,
    output wire pdi_ready,
    // SDI data bus
    input wire [(G_SWIDTH-1):0] sdi_data,
    input wire sdi_valid,
    output wire sdi_ready,
    // DO data bus
    output wire [(G_PWIDTH-1):0] do_data,
    output wire do_valid,
    input wire do_ready,
    output wire do_last
);

wire pdi_valid_and_ready;
wire sdi_valid_and_ready;

wire [(G_PWIDTH-1):0] pdi_buffer_din;
reg pdi_buffer_din_valid;
wire pdi_buffer_din_ready;
wire [(G_PWIDTH-1):0] pdi_buffer_dout;
wire pdi_buffer_dout_valid;
reg  pdi_buffer_dout_ready;
wire pdi_buffer_rst;
reg [2:0] reg_pdi_buffer_dout_size, next_pdi_buffer_dout_size;
reg reg_pdi_buffer_dout_last, next_pdi_buffer_dout_last;

wire [1:0] pdi_oper;
wire sm_pdi_ready;
reg int_pdi_ready;

wire [(G_PWIDTH-1):0] sdi_buffer_din;
reg sdi_buffer_din_valid;
wire sdi_buffer_din_ready;
wire [(G_PWIDTH-1):0] sdi_buffer_dout;
wire sdi_buffer_dout_valid;
reg  sdi_buffer_dout_ready;
wire sdi_buffer_rst;
reg [2:0] reg_sdi_buffer_dout_size, next_sdi_buffer_dout_size;
reg reg_sdi_buffer_dout_last, next_sdi_buffer_dout_last;

wire reg_buffer_dout_size_enable;

wire sdi_oper;
wire sm_sdi_ready;
reg int_sdi_ready;

reg [31:0] temp_data;
reg [2:0] temp_data_size;
reg temp_data_last;
reg temp_valid;
reg temp_ready;
wire sm_temp_ready;
wire [1:0] temp_data_oper;

wire temp_valid_and_ready;

wire cipher_din_oper;

wire [31:0] cipher_din;
wire [2:0] cipher_din_size;
wire cipher_din_last;
reg cipher_din_valid;
wire cipher_din_ready;
wire [3:0] cipher_inst;
reg cipher_inst_valid;
wire cipher_inst_ready;
wire [31:0] cipher_dout;
wire [2:0] cipher_dout_size;
wire cipher_dout_last;
wire cipher_dout_valid;
reg cipher_dout_ready;
wire cipher_fault_detected;

reg [(G_SEGMENT_SIZE_BITS-1):0] reg_data_size, next_data_size;
wire [1:0] reg_data_size_oper;
reg is_reg_data_size_less_equal_four;
reg is_reg_data_size_load_zero;

reg [3:0] reg_inst, next_inst;
wire reg_inst_enable;

reg reg_segment_end_of_type, next_segment_end_of_type;
wire reg_segment_end_of_type_enable;

wire do_buffer_din_valid_and_ready;

reg [(G_PWIDTH-1):0] do_buffer_din;
reg do_buffer_din_last;
reg do_buffer_din_valid;
wire do_buffer_din_ready;
wire [(G_PWIDTH-1):0] do_buffer_dout;
wire do_buffer_dout_last;
wire do_buffer_dout_valid;
wire do_buffer_dout_ready;
wire do_buffer_rst;

wire [2:0] do_buffer_din_type;

wire do_valid_and_ready;

assign pdi_valid_and_ready = pdi_valid & int_pdi_ready;
assign sdi_valid_and_ready = sdi_valid & int_sdi_ready;

assign pdi_buffer_din = pdi_data;

always @(*) begin
    case(pdi_oper)
        // PDI <-> Cipher instruction
        2'b01 : begin
            int_pdi_ready = cipher_inst_ready;
            cipher_inst_valid = pdi_valid;
            pdi_buffer_din_valid = 1'b0;
        end
        // PDI <-> pdi buffer
        2'b10 : begin
            int_pdi_ready = pdi_buffer_din_ready;
            cipher_inst_valid = 1'b0;
            pdi_buffer_din_valid = pdi_valid;
        end
        // PDI <-> state machine
        2'b00, 2'b11 : begin
            int_pdi_ready = sm_pdi_ready;
            cipher_inst_valid = 1'b0;
            pdi_buffer_din_valid = 1'b0;
        end
        default : begin
            int_pdi_ready = 1'bx;
            cipher_inst_valid = 1'bx;
            pdi_buffer_din_valid = 1'bx;
        end
    endcase
end

friet_lwc_buffer_in
#(.G_WIDTH(G_PWIDTH)
)
pdi_buffer
(
    .clk(clk),
    .rst(pdi_buffer_rst),
    .din(pdi_buffer_din),
    .din_valid(pdi_buffer_din_valid),
    .din_ready(pdi_buffer_din_ready),
    .dout(pdi_buffer_dout),
    .dout_valid(pdi_buffer_dout_valid),
    .dout_ready(pdi_buffer_dout_ready)
);

assign sdi_buffer_din = sdi_data;

always @(*) begin
    if(sdi_oper == 1'b1) begin
        // SDI <-> sdi buffer
        int_sdi_ready = sdi_buffer_din_ready;
        sdi_buffer_din_valid = sdi_valid;
    end else if(sdi_oper == 1'b0) begin
        // SDI <-> state machine
        int_sdi_ready = sm_sdi_ready;
        sdi_buffer_din_valid = 1'b0;
    end else begin
        int_sdi_ready = 1'bx;
        sdi_buffer_din_valid = 1'bx;
    end
end

friet_lwc_buffer_in
#(.G_WIDTH(G_SWIDTH)
)
sdi_buffer
(
    .clk(clk),
    .rst(sdi_buffer_rst),
    .din(sdi_buffer_din),
    .din_valid(sdi_buffer_din_valid),
    .din_ready(sdi_buffer_din_ready),
    .dout(sdi_buffer_dout),
    .dout_valid(sdi_buffer_dout_valid),
    .dout_ready(sdi_buffer_dout_ready)
);

always @(posedge clk) begin
    reg_pdi_buffer_dout_size <= next_pdi_buffer_dout_size;
    reg_pdi_buffer_dout_last <= next_pdi_buffer_dout_last;
    reg_sdi_buffer_dout_size <= next_sdi_buffer_dout_size;
    reg_sdi_buffer_dout_last <= next_sdi_buffer_dout_last;
end

always @(*) begin
    if((pdi_buffer_din_valid == 1'b1) && (pdi_buffer_din_ready == 1'b1)) begin
        if((is_reg_data_size_less_equal_four == 1'b1) && (reg_buffer_dout_size_enable == 1'b1) && (reg_segment_end_of_type == 1'b1)) begin
            next_pdi_buffer_dout_size = reg_data_size[2:0];
            next_pdi_buffer_dout_last = 1'b1;
        end else if((is_reg_data_size_less_equal_four == 1'b0) || (reg_buffer_dout_size_enable == 1'b0) || (reg_segment_end_of_type == 1'b0)) begin
            next_pdi_buffer_dout_size = 3'b100;
            next_pdi_buffer_dout_last = 1'b0;
        end else begin
            next_pdi_buffer_dout_size = {3{1'bx}};
            next_pdi_buffer_dout_last = 1'bx;
        end
    end else if((pdi_buffer_din_valid == 1'b0) || (pdi_buffer_din_ready == 1'b0)) begin
        next_pdi_buffer_dout_size = reg_pdi_buffer_dout_size;
        next_pdi_buffer_dout_last = reg_pdi_buffer_dout_last;
    end else begin
        next_pdi_buffer_dout_size = {3{1'bx}};
        next_pdi_buffer_dout_last = 1'bx;
    end
end

always @(*) begin
    if((sdi_buffer_din_valid == 1'b1) && (sdi_buffer_din_ready == 1'b1)) begin
        if((is_reg_data_size_less_equal_four == 1'b1) && (reg_buffer_dout_size_enable == 1'b1)) begin
            next_sdi_buffer_dout_size = reg_data_size[2:0];
            next_sdi_buffer_dout_last = 1'b1;
        end else if((is_reg_data_size_less_equal_four == 1'b0) || (reg_buffer_dout_size_enable == 1'b0)) begin
            next_sdi_buffer_dout_size = 3'b100;
            next_sdi_buffer_dout_last = 1'b0;
        end else begin
            next_sdi_buffer_dout_size = {3{1'bx}};
            next_sdi_buffer_dout_last = 1'bx;;
        end
    end else if((sdi_buffer_din_valid == 1'b0) || (sdi_buffer_din_ready == 1'b0)) begin
        next_sdi_buffer_dout_size = reg_sdi_buffer_dout_size;
        next_sdi_buffer_dout_last = reg_sdi_buffer_dout_last;
    end else begin
        next_sdi_buffer_dout_size = {3{1'bx}};
        next_sdi_buffer_dout_last = 1'bx;;
    end
end

assign temp_valid_and_ready = temp_valid & temp_ready;

always @(*) begin
    case(temp_data_oper)
        // SM <-> temp_data
        2'b01 : begin
            temp_data = 32'b0;
            temp_valid = 1'b1;
            temp_data_size = 3'b000; 
            temp_data_last = 1'b1;
            pdi_buffer_dout_ready = 1'b0;
            sdi_buffer_dout_ready = 1'b0;
        end
        // PDI <-> temp_data
        2'b10 : begin
            temp_data = pdi_buffer_dout;
            temp_valid = pdi_buffer_dout_valid;
            temp_data_size = reg_pdi_buffer_dout_size;
            temp_data_last = reg_pdi_buffer_dout_last;
            pdi_buffer_dout_ready = temp_ready;
            sdi_buffer_dout_ready = 1'b0;
        end
        // SDI <-> temp_data
        2'b11 : begin
            temp_data  = sdi_buffer_dout;
            temp_valid = sdi_buffer_dout_valid;
            temp_data_size = reg_sdi_buffer_dout_size; 
            temp_data_last = reg_sdi_buffer_dout_last;
            sdi_buffer_dout_ready = temp_ready;
            pdi_buffer_dout_ready = 1'b0;
        end
        // Empty <-> temp_data
        2'b00 : begin
            temp_data = 32'b0;
            temp_valid = 1'b0;
            temp_data_size = 3'b000; 
            temp_data_last = 1'b0;
            pdi_buffer_dout_ready = 1'b0;
            sdi_buffer_dout_ready = 1'b0;
        end
        default : begin
            temp_data = {32{1'bx}};
            temp_valid = 1'bx;
            temp_data_size = {3{1'bx}}; 
            temp_data_last = 1'bx;
            pdi_buffer_dout_ready = 1'bx;
            sdi_buffer_dout_ready = 1'bx;
        end
    endcase
end

always @(*) begin
    if(temp_data[(G_SEGMENT_SIZE_BITS-1):0] == 0) begin
        is_reg_data_size_load_zero = 1'b1;
    end else if(temp_data[(G_SEGMENT_SIZE_BITS-1):0] != 0) begin
        is_reg_data_size_load_zero = 1'b0;
    end else begin
        is_reg_data_size_load_zero = 1'bx;
    end
end

always @(*) begin
    if(cipher_din_oper == 1'b1) begin
        // temp_data <-> cipher
        cipher_din_valid = temp_valid;
        temp_ready = cipher_din_ready;
    end else if(cipher_din_oper == 1'b0) begin
        // temp_data <-> state machine
        cipher_din_valid = 1'b0;
        temp_ready = sm_temp_ready;
    end else begin
        cipher_din_valid = 1'bx;
        temp_ready = 1'bx;
    end
end

assign cipher_din[7:0]   = temp_data[31:24];
assign cipher_din[15:8]  = temp_data[23:16];
assign cipher_din[23:16] = temp_data[15:8];
assign cipher_din[31:24] = temp_data[7:0];

assign cipher_din_last = temp_data_last;
assign cipher_din_size = temp_data_size;

assign cipher_inst = pdi_data[(G_PWIDTH-1):(G_PWIDTH-4)];

friet_stream_asic
#(.ASYNC_RSTN(ASYNC_RSTN),
.COMBINATIONAL_ROUNDS(COMBINATIONAL_ROUNDS),
.KEY_TAG_SIZE(1'd0),
.AE_TAG_SIZE(1'd0),
.DIN_DOUT_WIDTH(32),
.DIN_DOUT_SIZE_WIDTH(2))
cipher
(
    .clk(clk),
    .arstn(rst),
    // Data in bus
    .din(cipher_din),
    .din_size(cipher_din_size),
    .din_last(cipher_din_last),
    .din_valid(cipher_din_valid),
    .din_ready(cipher_din_ready),
    // Instruction bus
    .inst(cipher_inst),
    .inst_valid(cipher_inst_valid),
    .inst_ready(cipher_inst_ready),
    // Data out bus
    .dout(cipher_dout),
    .dout_size(cipher_dout_size),
    .dout_last(cipher_dout_last),
    .dout_valid(cipher_dout_valid),
    .dout_ready(cipher_dout_ready),
    // Fault detection
    .fault_detected(cipher_fault_detected)
);

always @(posedge clk) begin
    reg_data_size <= next_data_size;
end

always @(*) begin
    case(reg_data_size_oper)
        2'b01 : begin
            next_data_size = temp_data[(G_SEGMENT_SIZE_BITS-1):0];
        end
        2'b10 : begin
            if((pdi_valid_and_ready == 1'b1) || (sdi_valid_and_ready == 1'b1)) begin
                if(is_reg_data_size_less_equal_four == 1'b1) begin
                    next_data_size = {G_SEGMENT_SIZE_BITS{1'b0}};
                end else if(is_reg_data_size_less_equal_four == 1'b0) begin
                    next_data_size = reg_data_size - 4;
                end else begin
                    next_data_size = {G_SEGMENT_SIZE_BITS{1'bx}};
                end
            end else if((pdi_valid_and_ready == 1'b0) && (sdi_valid_and_ready == 1'b0)) begin
                next_data_size = reg_data_size;
            end else begin
                next_data_size = {G_SEGMENT_SIZE_BITS{1'bx}};
            end
        end
        2'b00, 2'b11 : begin
            next_data_size = reg_data_size;
        end
        default : begin
            next_data_size = {G_SEGMENT_SIZE_BITS{1'bx}};
        end
    endcase
end

always @(*) begin
    if(reg_data_size <= 4) begin
        is_reg_data_size_less_equal_four = 1'b1;
    end else if(reg_data_size > 4) begin
        is_reg_data_size_less_equal_four = 1'b0;
    end else begin
        is_reg_data_size_less_equal_four = 1'bx;
    end
end

always @(posedge clk) begin
    reg_inst <= next_inst;
end

always @(*) begin
    if((cipher_inst_valid == 1'b1) && (cipher_inst_ready == 1'b1)) begin
        next_inst = pdi_data[31:28];
    end else if((cipher_inst_valid == 1'b0) || (cipher_inst_ready == 1'b0)) begin
        next_inst = reg_inst;
    end else begin
        next_inst = reg_inst;
    end
end

always @(posedge clk) begin
    reg_segment_end_of_type <= next_segment_end_of_type;
end

always @(*) begin
    if((temp_valid == 1'b1) && (reg_segment_end_of_type_enable == 1'b1)) begin
        next_segment_end_of_type = temp_data[25];
    end else if((temp_valid == 1'b0) || (reg_segment_end_of_type_enable == 1'b0)) begin
        next_segment_end_of_type = reg_segment_end_of_type;
    end else begin
        next_segment_end_of_type = 1'bx;
    end
end

assign do_buffer_din_valid_and_ready = do_buffer_din_valid & do_buffer_din_ready;

always @(*) begin
    case(do_buffer_din_type)
        // Status header for hash instruction
        3'b001 : begin
            do_buffer_din[31:28] = 4'b1001;
            do_buffer_din[27:24] = 4'b0011;
            do_buffer_din[23:16] = 8'h00;
            do_buffer_din[15:0]  = 32;
            do_buffer_din_valid  = 1'b1;
            do_buffer_din_last   = 1'b0;
            cipher_dout_ready    = 1'b0;
        end
        // Status header for ciphertext/plaintext
        3'b010 : begin
            if(reg_inst[0] == 1'b0) begin
                do_buffer_din[31:28] = 4'b0101;
                do_buffer_din[27:24] = {2'b00, temp_data[25], 1'b0};
                do_buffer_din[23:G_SEGMENT_SIZE_BITS]  = {(23+1-G_SEGMENT_SIZE_BITS){1'b0}};
                do_buffer_din[G_SEGMENT_SIZE_BITS-1:0] = temp_data[G_SEGMENT_SIZE_BITS-1:0];
                do_buffer_din_valid  = 1'b1;
                do_buffer_din_last   = 1'b0;
                cipher_dout_ready    = 1'b0;
            end else if(reg_inst[0] == 1'b1) begin
                do_buffer_din[31:28] = 4'b0100;
                do_buffer_din[27:24] = {2'b00, temp_data[25], temp_data[25]};
                do_buffer_din[23:G_SEGMENT_SIZE_BITS]  = {(23+1-G_SEGMENT_SIZE_BITS){1'b0}};
                do_buffer_din[G_SEGMENT_SIZE_BITS-1:0] = temp_data[G_SEGMENT_SIZE_BITS-1:0];
                do_buffer_din_valid  = 1'b1;
                do_buffer_din_last   = 1'b0;
                cipher_dout_ready    = 1'b0;
            end else begin
                do_buffer_din = {32{1'bx}};
                do_buffer_din_valid = 1'bx;
                do_buffer_din_last  = 1'bx;
                cipher_dout_ready   = 1'bx;
            end
        end
        // Status header for tag
        3'b100 : begin
            do_buffer_din[31:28] = 4'b1000;
            do_buffer_din[27:24] = 4'b0011;
            do_buffer_din[23:16] = 8'h00;
            do_buffer_din[15:0]  = 16;
            do_buffer_din_valid  = 1'b1;
            do_buffer_din_last   = 1'b0;
            cipher_dout_ready    = 1'b0;
        end
        // Status instruction for correct execution
        3'b101 : begin
            do_buffer_din[31:28] = {3'b111, cipher_fault_detected};
            do_buffer_din[27:24] = 4'b0000;
            do_buffer_din[23:16] = 8'h00;
            do_buffer_din[15:0]  = 16'h0000;
            do_buffer_din_valid  = 1'b1;
            do_buffer_din_last   = 1'b1;
            cipher_dout_ready    = 1'b0;
        end
        // Status instruction for tag verification
        3'b110 : begin
            do_buffer_din[31:28] = cipher_dout[3:0];
            do_buffer_din[27:24] = 4'b0000;
            do_buffer_din[23:16] = 8'h00;
            do_buffer_din[15:0]  = 16'h0000;
            do_buffer_din_valid  = cipher_dout_valid;
            do_buffer_din_last   = 1'b1;
            cipher_dout_ready    = do_buffer_din_ready;
        end
        3'b111 : begin
            do_buffer_din = {32{1'b0}};
            do_buffer_din_valid = 1'b0;
            do_buffer_din_last  = 1'b0;
            cipher_dout_ready   = 1'b0;
        end
        // Ignore value that comes from the cipher core
        3'b011 : begin
            do_buffer_din = {32{1'b0}};
            do_buffer_din_valid = 1'b0;
            do_buffer_din_last  = 1'b0;
            cipher_dout_ready   = 1'b1;
        end        
        // Value comes from the cipher core
        3'b000 : begin
            // Because of the notation of the LWC API the values have to changed positions.
            do_buffer_din[31:24] = cipher_dout[7:0];
            do_buffer_din[23:16] = cipher_dout[15:8];
            do_buffer_din[15:8]  = cipher_dout[23:16];
            do_buffer_din[7:0]   = cipher_dout[31:24];
            do_buffer_din_valid  = cipher_dout_valid;
            do_buffer_din_last   = cipher_dout_last;
            cipher_dout_ready    = do_buffer_din_ready;
        end        
        default : begin
            do_buffer_din = {32{1'bx}};
            do_buffer_din_valid = 1'bx;
            do_buffer_din_last  = 1'bx;
            cipher_dout_ready   = 1'bx;
        end
    endcase
end

assign do_buffer_dout_ready = do_ready;

assign do_valid_and_ready = do_buffer_dout_valid & do_ready;

friet_lwc_buffer_out
#(.G_WIDTH(G_PWIDTH)
)
do_buffer
(
    .clk(clk),
    .rst(do_buffer_rst),
    .din(do_buffer_din),
    .din_last(do_buffer_din_last),
    .din_valid(do_buffer_din_valid),
    .din_ready(do_buffer_din_ready),
    .dout(do_buffer_dout),
    .dout_last(do_buffer_dout_last),
    .dout_valid(do_buffer_dout_valid),
    .dout_ready(do_buffer_dout_ready)
);

friet_lwc_state_machine
#(.ASYNC_RSTN(ASYNC_RSTN),
.G_PWIDTH(G_PWIDTH),
.G_SWIDTH(G_SWIDTH))
state_machine
(
    .clk(clk),
    .rst(rst),
    .pdi_data(pdi_data[(G_PWIDTH-1):(G_PWIDTH-4)]),
    .pdi_valid_and_ready(pdi_valid_and_ready),
    .pdi_oper(pdi_oper),
    .sm_pdi_ready(sm_pdi_ready),
    .pdi_buffer_rst(pdi_buffer_rst),
    .sdi_data(sdi_data[(G_SWIDTH-1):(G_SWIDTH-4)]),
    .sdi_valid_and_ready(sdi_valid_and_ready),
    .sdi_oper(sdi_oper),
    .sm_sdi_ready(sm_sdi_ready),
    .sdi_buffer_rst(sdi_buffer_rst),
    .reg_buffer_dout_size_enable(reg_buffer_dout_size_enable),
    .temp_valid_and_ready(temp_valid_and_ready),
    .temp_data_oper(temp_data_oper),
    .sm_temp_ready(sm_temp_ready),
    .cipher_din_oper(cipher_din_oper),
    .cipher_din_ready(cipher_din_ready),
    .cipher_inst_ready(cipher_inst_ready),
    .cipher_dout_last(cipher_dout_last),
    .cipher_dout_valid(cipher_dout_valid),
    .cipher_dout_ready(cipher_dout_ready),
    .reg_data_size_oper(reg_data_size_oper),
    .is_reg_data_size_less_equal_four(is_reg_data_size_less_equal_four),
    .is_reg_data_size_load_zero(is_reg_data_size_load_zero),
    .reg_inst(reg_inst),
    .reg_inst_enable(reg_inst_enable),
    .reg_segment_end_of_type(reg_segment_end_of_type),
    .reg_segment_end_of_type_enable(reg_segment_end_of_type_enable),
    .do_buffer_din_valid_and_ready(do_buffer_din_valid_and_ready),
    .do_buffer_rst(do_buffer_rst),
    .do_buffer_din_type(do_buffer_din_type),
    .do_valid_and_ready(do_valid_and_ready)
);

assign pdi_ready = int_pdi_ready;
assign sdi_ready = int_sdi_ready;
assign do_data  = do_buffer_dout;
assign do_valid = do_buffer_dout_valid;
assign do_last  = do_buffer_dout_last;

endmodule