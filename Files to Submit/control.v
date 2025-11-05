`default_nettype none

module control (
    input  wire [6:0]  i_opcode,
    input  wire [2:0]  i_funct3,
    input  wire [6:0]  i_funct7,

    // Outputs to the datapath
    output reg  [3:0]  o_alu_ctrl,
    output reg         o_reg_write,
    output reg         o_mem_read,
    output reg         o_mem_write,
    output reg         o_mem_to_reg,
    output reg         o_alu_src,
    output reg         o_branch,
    output reg         o_jump
);

    always @(*) begin
        // Default values
        o_alu_ctrl   = 4'b0000;
        o_reg_write  = 1'b0;
        o_mem_read   = 1'b0;
        o_mem_write  = 1'b0;
        o_mem_to_reg = 1'b0;
        o_alu_src    = 1'b0;
        o_branch     = 1'b0;
        o_jump       = 1'b0;

        case (i_opcode)
            7'b0110011: begin // R-type
                o_reg_write = 1'b1;
                o_alu_src   = 1'b0;
                case ({i_funct7, i_funct3})
                    10'b0000000_000: o_alu_ctrl = 4'b0000; // ADD
                    10'b0100000_000: o_alu_ctrl = 4'b0001; // SUB
                    10'b0000000_111: o_alu_ctrl = 4'b0010; // AND
                    10'b0000000_110: o_alu_ctrl = 4'b0011; // OR
                    10'b0000000_100: o_alu_ctrl = 4'b0100; // XOR
                    10'b0000000_001: o_alu_ctrl = 4'b0101; // SLL
                    10'b0000000_101: o_alu_ctrl = 4'b0110; // SRL
                    10'b0100000_101: o_alu_ctrl = 4'b0111; // SRA
                    10'b0000000_010: o_alu_ctrl = 4'b1000; // SLT
                    10'b0000000_011: o_alu_ctrl = 4'b1001; // SLTU
                    default:         o_alu_ctrl = 4'b0000;
                endcase
            end

            7'b0010011: begin // I-type (ALU immediate)
                o_reg_write = 1'b1;
                o_alu_src   = 1'b1;
                case (i_funct3)
                    3'b000: o_alu_ctrl = 4'b0000; // ADDI
                    3'b010: o_alu_ctrl = 4'b1000; // SLTI
                    3'b011: o_alu_ctrl = 4'b1001; // SLTIU
                    3'b100: o_alu_ctrl = 4'b0100; // XORI
                    3'b110: o_alu_ctrl = 4'b0011; // ORI
                    3'b111: o_alu_ctrl = 4'b0010; // ANDI
                    3'b001: o_alu_ctrl = 4'b0101; // SLLI
                    3'b101: o_alu_ctrl = (i_funct7 == 7'b0000000) ? 4'b0110 : 4'b0111; // SRLI/SRAI
                    default: o_alu_ctrl = 4'b0000;
                endcase
            end

            7'b0000011: begin // LOAD
                o_reg_write  = 1'b1;
                o_mem_read   = 1'b1;
                o_mem_to_reg = 1'b1;
                o_alu_src    = 1'b1;
                o_alu_ctrl   = 4'b0000; // ADD for address calc
            end

            7'b0100011: begin // STORE
                o_mem_write = 1'b1;
                o_alu_src   = 1'b1;
                o_alu_ctrl  = 4'b0000; // ADD for address calc
            end

            7'b1100011: begin // BRANCH
                o_branch    = 1'b1;
                o_alu_src   = 1'b0;
                o_alu_ctrl  = 4'b0001; // SUB for comparison
            end

            7'b1101111: begin // JAL
                o_jump       = 1'b1;
                o_reg_write  = 1'b1;
                o_mem_to_reg = 1'b0;
            end

            7'b1100111: begin // JALR
                o_jump       = 1'b1;
                o_reg_write  = 1'b1;
                o_mem_to_reg = 1'b0;
                o_alu_src    = 1'b1;
                o_alu_ctrl   = 4'b0000; // ADD for target address
            end

            7'b0110111, // LUI
            7'b0010111: begin // AUIPC
                o_reg_write  = 1'b1;
                o_alu_src    = 1'b1;
                o_alu_ctrl   = 4'b0000;
            end

            default: begin
                // Invalid / unsupported opcode — all defaults
            end
        endcase
    end

endmodule

`default_nettype wire