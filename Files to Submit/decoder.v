`timescale 1ns / 1ps
`default_nettype none

module decoder (
    input  wire [31:0] inst,       // full instruction word

    output wire [6:0]  opcode,     // bits [6:0]
    output wire [2:0]  funct3,     // bits [14:12]
    output wire [6:0]  funct7,     // bits [31:25]
    output wire [4:0]  rs1,        // bits [19:15]
    output wire [4:0]  rs2,        // bits [24:20]
    output wire [4:0]  rd,         // bits [11:7]
    // New: one-hot encoded immediate format selection for the `imm` unit
    // bit[0] = R-type (no immediate)
    // bit[1] = I-type
    // bit[2] = S-type
    // bit[3] = B-type
    // bit[4] = U-type
    // bit[5] = J-type
    output wire [5:0]  i_format
);

    //-------------------------------------------------
    // basic field extraction
    //-------------------------------------------------
    assign opcode = inst[6:0];
    assign rd     = inst[11:7];
    assign funct3 = inst[14:12];
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign funct7 = inst[31:25];

    //-------------------------------------------------
    // immediate format selection (one-hot)
    //-------------------------------------------------
    // Map opcodes to immediate formats. This is intentionally conservative
    // and matches the usage in `hart.v`.
    wire is_rtype = (inst[6:0] == 7'b0110011);                                // OP
    wire is_itype = (inst[6:0] == 7'b0010011) || (inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b1100111); // OP-IMM, LOAD, JALR
    wire is_stype = (inst[6:0] == 7'b0100011);                                // STORE
    wire is_btype = (inst[6:0] == 7'b1100011);                                // BRANCH
    wire is_utype = (inst[6:0] == 7'b0110111) || (inst[6:0] == 7'b0010111);    // LUI, AUIPC
    wire is_jtype = (inst[6:0] == 7'b1101111);                                // JAL

    assign i_format = {is_jtype, is_utype, is_btype, is_stype, is_itype, is_rtype};

endmodule
`default_nettype wire