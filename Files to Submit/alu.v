`default_nettype none

module alu (
    input  wire [31:0] i_op1,
    input  wire [31:0] i_op2,
    input  wire [3:0]  i_alu_ctrl,
    output reg  [31:0] o_result,
    output wire        o_zero
);
    always @(*) begin
        case (i_alu_ctrl)
            4'b0000: o_result = i_op1 + i_op2;              // ADD
            4'b0001: o_result = i_op1 - i_op2;              // SUB
            4'b0010: o_result = i_op1 & i_op2;              // AND
            4'b0011: o_result = i_op1 | i_op2;              // OR
            4'b0100: o_result = i_op1 ^ i_op2;              // XOR
            4'b0101: o_result = i_op1 << i_op2[4:0];        // SLL
            4'b0110: o_result = i_op1 >> i_op2[4:0];        // SRL
            4'b0111: o_result = $signed(i_op1) >>> i_op2[4:0]; // SRA
            4'b1000: o_result = ($signed(i_op1) < $signed(i_op2)) ? 32'd1 : 32'd0;  // SLT
            4'b1001: o_result = (i_op1 < i_op2) ? 32'd1 : 32'd0;  // SLTU
            default: o_result = 32'd0;
        endcase
    end

    assign o_zero = (o_result == 32'd0);

endmodule

`default_nettype wire