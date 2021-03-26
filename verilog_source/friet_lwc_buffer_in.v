/*--------------------------------------------------------------------------------*/
/* Implementation by Pedro Maat C. Massolino,                                     */
/* hereby denoted as "the implementer".                                           */
/*                                                                                */
/* To the extent possible under law, the implementer has waived all copyright     */
/* and related or neighboring rights to the source code in this file.             */
/* http://creativecommons.org/publicdomain/zero/1.0/                              */
/*--------------------------------------------------------------------------------*/
`default_nettype    none

module friet_lwc_buffer_in
#(parameter G_WIDTH = 32
)
(
    input wire clk,
    input wire rst,
    // In
    input wire [(G_WIDTH-1):0] din,
    input wire din_valid,
    output wire din_ready,
    // Out
    output wire [(G_WIDTH-1):0] dout,
    output wire dout_valid,
    input wire dout_ready
);

reg [(G_WIDTH-1):0] reg_data, next_data;
reg reg_data_empty, next_data_empty;

reg int_din_ready;
reg [(G_WIDTH-1):0] int_dout;
reg int_dout_valid;

wire din_valid_and_ready;
wire dout_valid_and_ready;

assign din_valid_and_ready = din_valid & int_din_ready;
assign dout_valid_and_ready = int_dout_valid & dout_ready;

always @(posedge clk) begin
    reg_data <= next_data;
    reg_data_empty <= next_data_empty;
end

always @(*) begin
    if(din_valid_and_ready == 1'b1) begin
        next_data = din;
    end else if(din_valid_and_ready == 1'b0) begin
        next_data = reg_data;
    end else begin
        next_data = {G_WIDTH{1'bx}};
    end
end

always @(*) begin
    if(rst == 1'b1) begin
        next_data_empty = 1'b1;
    end else if(rst == 1'b0) begin
        if((din_valid_and_ready == 1'b1)) begin
            if(dout_valid_and_ready == 1'b0) begin
                next_data_empty = 1'b0;
            end else if(dout_valid_and_ready == 1'b1) begin
                next_data_empty = reg_data_empty;
            end else begin
                next_data_empty = 1'bx;
            end
        end else if((din_valid_and_ready == 1'b0)) begin
            if(dout_valid_and_ready == 1'b1) begin
                next_data_empty = 1'b1;
            end else if(dout_valid_and_ready == 1'b0) begin
                next_data_empty = reg_data_empty;
            end else begin
                next_data_empty = 1'bx;
            end
        end else begin
            next_data_empty = 1'bx;
        end
    end else begin
        next_data_empty = 1'bx;
    end
end

always @(*) begin
    if(rst == 1'b1) begin
        int_din_ready = 1'b0;
    end else if(rst == 1'b0) begin
        if(reg_data_empty == 1'b1) begin
            int_din_ready = 1'b1;
        end else if(reg_data_empty == 1'b0) begin
            if(dout_ready == 1'b1) begin
                int_din_ready = 1'b1;
            end else if(dout_ready == 1'b0) begin
                int_din_ready = 1'b0;
            end else begin
                int_din_ready = 1'bx;
            end
        end else begin
            int_din_ready = 1'bx;
        end
    end else begin
        int_din_ready = 1'bx;
    end
end

always @(*) begin
    if(reg_data_empty == 1'b0) begin
        int_dout_valid = 1'b1;
    end else if(reg_data_empty == 1'b1) begin
        int_dout_valid = 1'b0;
    end else begin
        int_dout_valid = 1'bx;
    end
end

always @(*) begin
    int_dout = reg_data;
end

assign din_ready = int_din_ready;
assign dout = int_dout;
assign dout_valid = int_dout_valid;

endmodule