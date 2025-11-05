module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc


`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    // Fill in your implementation here.
   
    //====================================================
    // IF/ID Pipeline Register
    //====================================================
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;
    
    //====================================================
    // ID/EX Pipeline Register
    //====================================================
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_inst;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1_addr;
    reg [4:0]  id_ex_rs2_addr;
    reg [4:0]  id_ex_rd_addr;
    reg [2:0]  id_ex_funct3;
    reg [6:0]  id_ex_opcode;
    // Control signals
    reg [3:0]  id_ex_alu_ctrl;
    reg        id_ex_alu_src;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_reg_write;
    reg        id_ex_branch;
    reg        id_ex_jump;
    
    //====================================================
    // EX/MEM Pipeline Register
    //====================================================
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_inst;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rs2_data;
    reg [4:0]  ex_mem_rd_addr;
    reg [2:0]  ex_mem_funct3;
    reg [6:0]  ex_mem_opcode;
    reg [31:0] ex_mem_rs1_data;  // For retire interface
    reg [31:0] ex_mem_imm;       // For AUIPC in WB
    reg [4:0]  ex_mem_rs1_addr;  // For retire interface
    reg [4:0]  ex_mem_rs2_addr;  // For retire interface
    // Control signals
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;
    reg        ex_mem_reg_write;
    reg [31:0] ex_mem_branch_target;  // Computed branch target
    reg        ex_mem_branch_taken;   // Was branch taken?
    
    //====================================================
    // MEM/WB Pipeline Register
    //====================================================
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_inst;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd_addr;
    reg [6:0]  mem_wb_opcode;
    reg [31:0] mem_wb_imm;       // For AUIPC/LUI in WB
    reg [31:0] mem_wb_rs1_data;  // For retire interface
    reg [31:0] mem_wb_rs2_data;  // For retire interface
    reg [4:0]  mem_wb_rs1_addr;  // For retire interface
    reg [4:0]  mem_wb_rs2_addr;  // For retire interface
    reg [31:0] mem_wb_dmem_addr;
    reg        mem_wb_dmem_ren;
    reg        mem_wb_dmem_wen;
    reg [3:0]  mem_wb_dmem_mask;
    reg [31:0] mem_wb_dmem_wdata;
    reg [31:0] mem_wb_dmem_rdata;
    // Control signals
    reg        mem_wb_mem_to_reg;
    reg        mem_wb_reg_write;
    reg        mem_wb_is_ebreak;
   
    //====================================================
    // 1. Instruction Fetch (IF) Stage
    //====================================================
    wire [31:0] pc_curr;
    reg [31:0] pc_next;  // Driven by always block

    pc #(.RESET_ADDR(RESET_ADDR)) u_pc (
        .clk     (i_clk),
        .rst     (i_rst),
        .pc_next (pc_next),
        .pc_curr (pc_curr)
    );

    assign o_imem_raddr = pc_curr;

    //====================================================
    // 2. Instruction Decode (ID) Stage
    //====================================================
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [31:0] imm_out;
    wire [5:0]  i_format;

    decoder u_decoder (
        .inst   (if_id_inst),
        .opcode (opcode),
        .funct3 (funct3),
        .funct7 (funct7),
        .rs1    (rs1_addr),
        .rs2    (rs2_addr),
        .rd     (rd_addr),
        .i_format (i_format)
    );

    //====================================================
    // 3. Register File (Read in ID, Write in WB)
    //====================================================
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] wb_data;  // Writeback data (declared early for RF)

    rf #(.BYPASS_EN(1)) u_rf (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_rd_wen    (mem_wb_reg_write),
        .i_rd_waddr  (mem_wb_rd_addr),
        .i_rd_wdata  (wb_data),
        .i_rs1_raddr (rs1_addr),
        .o_rs1_rdata (rs1_data),
        .i_rs2_raddr (rs2_addr),
        .o_rs2_rdata (rs2_data)
    );

    //====================================================
    // 4. Control Unit (in ID stage)
    //====================================================
    wire [3:0] alu_ctrl;
    wire       reg_write, mem_read, mem_write, mem_to_reg;
    wire       alu_src, branch, jump;

    control u_control (
        .i_opcode    (opcode),
        .i_funct3    (funct3),
        .i_funct7    (funct7),
        .o_alu_ctrl  (alu_ctrl),
        .o_reg_write (reg_write),
        .o_mem_read  (mem_read),
        .o_mem_write (mem_write),
        .o_mem_to_reg(mem_to_reg),
        .o_alu_src   (alu_src),
        .o_branch    (branch),
        .o_jump      (jump)
    );

    //====================================================
    // 5. Immediate Generator (in ID stage)
    //====================================================
    imm u_imm (
        .i_inst     (if_id_inst),
        .i_format   (i_format),
        .o_immediate(imm_out)
    );

    //====================================================
    // 6. Execute (EX) Stage - ALU + Branch Resolution
    //====================================================
    wire [31:0] alu_op2;
    wire [31:0] alu_result;
    wire        alu_zero;

    assign alu_op2 = (id_ex_alu_src) ? id_ex_imm : id_ex_rs2_data;

    alu u_alu (
        .i_op1      (id_ex_rs1_data),
        .i_op2      (alu_op2),
        .i_alu_ctrl (id_ex_alu_ctrl),
        .o_result   (alu_result),
        .o_zero     (alu_zero)
    );
    
    // Branch condition evaluation in EX stage
    reg branch_condition;
    wire is_jal = (id_ex_opcode == 7'b1101111);   // JAL
    wire is_jalr = (id_ex_opcode == 7'b1100111);  // JALR
    
    always @* begin
        branch_condition = 1'b0;
        if (id_ex_branch) begin
            case (id_ex_funct3)
                3'b000: branch_condition = (id_ex_rs1_data == id_ex_rs2_data);                     // BEQ
                3'b001: branch_condition = (id_ex_rs1_data != id_ex_rs2_data);                     // BNE
                3'b100: branch_condition = ($signed(id_ex_rs1_data) < $signed(id_ex_rs2_data));   // BLT
                3'b101: branch_condition = ($signed(id_ex_rs1_data) >= $signed(id_ex_rs2_data));  // BGE
                3'b110: branch_condition = (id_ex_rs1_data < id_ex_rs2_data);                      // BLTU
                3'b111: branch_condition = (id_ex_rs1_data >= id_ex_rs2_data);                     // BGEU
                default: branch_condition = 1'b0;
            endcase
        end
    end
    
    // Compute branch/jump targets in EX
    wire [31:0] branch_target = id_ex_pc + id_ex_imm;
    wire [31:0] jalr_sum = id_ex_rs1_data + id_ex_imm;
    wire [31:0] jalr_target = {jalr_sum[31:1], 1'b0};
    wire        branch_taken = (id_ex_branch && branch_condition) || is_jal || is_jalr;
    
    // Determine next PC target
    wire [31:0] ex_branch_target;
    assign ex_branch_target = is_jal ? branch_target :
                             is_jalr ? jalr_target :
                             (id_ex_branch && branch_condition) ? branch_target :
                             32'h0;

    //====================================================
    // 7. Memory (MEM) Stage
    //====================================================
    assign o_dmem_addr  = {ex_mem_alu_result[31:2], 2'b00}; // Word-aligned address
    
    // Memory mask based on funct3 for load/store instructions
    reg [3:0] mem_mask;
    always @* begin
        if (ex_mem_mem_read || ex_mem_mem_write) begin
            case (ex_mem_funct3)
                3'b000: mem_mask = 4'b0001 << ex_mem_alu_result[1:0]; // LB/SB: byte
                3'b001: begin // LH/SH: halfword
                    case (ex_mem_alu_result[1:0])
                        2'b00: mem_mask = 4'b0011;
                        2'b10: mem_mask = 4'b1100;
                        default: mem_mask = 4'b0011;
                    endcase
                end
                3'b010: mem_mask = 4'b1111; // LW/SW: word
                3'b100: mem_mask = 4'b0001 << ex_mem_alu_result[1:0]; // LBU: byte unsigned
                3'b101: begin // LHU: halfword unsigned
                    case (ex_mem_alu_result[1:0])
                        2'b00: mem_mask = 4'b0011;
                        2'b10: mem_mask = 4'b1100;
                        default: mem_mask = 4'b0011;
                    endcase
                end
                default: mem_mask = 4'b1111;
            endcase
        end else begin
            mem_mask = 4'b0000;
        end
    end
    
    // Store data positioning
    reg [31:0] store_data;
    always @* begin
        case (ex_mem_funct3)
            3'b000: begin // SB
                case (ex_mem_alu_result[1:0])
                    2'b00: store_data = {24'd0, ex_mem_rs2_data[7:0]};
                    2'b01: store_data = {16'd0, ex_mem_rs2_data[7:0], 8'd0};
                    2'b10: store_data = {8'd0, ex_mem_rs2_data[7:0], 16'd0};
                    2'b11: store_data = {ex_mem_rs2_data[7:0], 24'd0};
                endcase
            end
            3'b001: begin // SH
                case (ex_mem_alu_result[1:0])
                    2'b00: store_data = ex_mem_rs2_data;
                    2'b10: store_data = {ex_mem_rs2_data[15:0], 16'd0};
                    default: store_data = ex_mem_rs2_data;
                endcase
            end
            3'b010: store_data = ex_mem_rs2_data; // SW
            default: store_data = ex_mem_rs2_data;
        endcase
    end
    
    assign o_dmem_wdata = store_data;
    assign o_dmem_ren   = ex_mem_mem_read;
    assign o_dmem_wen   = ex_mem_mem_write;
    assign o_dmem_mask  = mem_mask;

    //====================================================
    // 8. Writeback (WB) Stage
    //====================================================
    wire [31:0] pc_plus_4_wb = mem_wb_pc + 32'd4;
    wire is_jal_wb = (mem_wb_opcode == 7'b1101111);   // JAL
    wire is_jalr_wb = (mem_wb_opcode == 7'b1100111);  // JALR
    
    // Writeback data multiplexer (wb_data declared earlier for RF connection)
    assign wb_data = mem_wb_mem_to_reg ? mem_wb_mem_data :           // Load instruction
                     (is_jal_wb || is_jalr_wb) ? pc_plus_4_wb :      // JAL/JALR
                     (mem_wb_opcode == 7'b0110111) ? mem_wb_imm :    // LUI
                     (mem_wb_opcode == 7'b0010111) ? (mem_wb_pc + mem_wb_imm) : // AUIPC
                     mem_wb_alu_result;                               // ALU result

    //====================================================
    // 9. Next PC Logic (controlled by EX stage)
    //====================================================
    wire [31:0] pc_plus_4 = pc_curr + 32'd4;
    
    // PC mux: Take branch target from EX if branch/jump taken, otherwise PC+4
    always @* begin
        if (branch_taken)
            pc_next = ex_branch_target;
        else
            pc_next = pc_plus_4;
    end

    //====================================================
    // 10. Pipeline Register Updates
    //====================================================
    always @(posedge i_clk) begin
        if (i_rst) begin
            // Reset all pipeline registers to NOPs
            if_id_pc <= 32'h0;
            if_id_inst <= 32'h00000013;  // NOP (addi x0, x0, 0)
            
            id_ex_pc <= 32'h0;
            id_ex_inst <= 32'h00000013;
            id_ex_rs1_data <= 32'h0;
            id_ex_rs2_data <= 32'h0;
            id_ex_imm <= 32'h0;
            id_ex_rs1_addr <= 5'h0;
            id_ex_rs2_addr <= 5'h0;
            id_ex_rd_addr <= 5'h0;
            id_ex_funct3 <= 3'h0;
            id_ex_opcode <= 7'h0;
            id_ex_alu_ctrl <= 4'h0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            
            ex_mem_pc <= 32'h0;
            ex_mem_inst <= 32'h00000013;
            ex_mem_alu_result <= 32'h0;
            ex_mem_rs2_data <= 32'h0;
            ex_mem_rd_addr <= 5'h0;
            ex_mem_funct3 <= 3'h0;
            ex_mem_opcode <= 7'h0;
            ex_mem_rs1_data <= 32'h0;
            ex_mem_imm <= 32'h0;
            ex_mem_rs1_addr <= 5'h0;
            ex_mem_rs2_addr <= 5'h0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_branch_target <= 32'h0;
            ex_mem_branch_taken <= 1'b0;
            
            mem_wb_pc <= 32'h0;
            mem_wb_inst <= 32'h00000013;
            mem_wb_alu_result <= 32'h0;
            mem_wb_mem_data <= 32'h0;
            mem_wb_rd_addr <= 5'h0;
            mem_wb_opcode <= 7'h0;
            mem_wb_imm <= 32'h0;
            mem_wb_rs1_data <= 32'h0;
            mem_wb_rs2_data <= 32'h0;
            mem_wb_rs1_addr <= 5'h0;
            mem_wb_rs2_addr <= 5'h0;
            mem_wb_dmem_addr <= 32'h0;
            mem_wb_dmem_ren <= 1'b0;
            mem_wb_dmem_wen <= 1'b0;
            mem_wb_dmem_mask <= 4'h0;
            mem_wb_dmem_wdata <= 32'h0;
            mem_wb_dmem_rdata <= 32'h0;
            mem_wb_mem_to_reg <= 1'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_is_ebreak <= 1'b0;
        end else begin
            // IF/ID: Fetch instruction
            if_id_pc <= pc_curr;
            if_id_inst <= i_imem_rdata;
            
            // ID/EX: Decode and read registers
            id_ex_pc <= if_id_pc;
            id_ex_inst <= if_id_inst;
            id_ex_rs1_data <= rs1_data;
            id_ex_rs2_data <= rs2_data;
            id_ex_imm <= imm_out;
            id_ex_rs1_addr <= rs1_addr;
            id_ex_rs2_addr <= rs2_addr;
            id_ex_rd_addr <= rd_addr;
            id_ex_funct3 <= funct3;
            id_ex_opcode <= opcode;
            id_ex_alu_ctrl <= alu_ctrl;
            id_ex_alu_src <= alu_src;
            id_ex_mem_read <= mem_read;
            id_ex_mem_write <= mem_write;
            id_ex_mem_to_reg <= mem_to_reg;
            id_ex_reg_write <= reg_write;
            id_ex_branch <= branch;
            id_ex_jump <= jump;
            
            // EX/MEM: Execute ALU and resolve branches
            ex_mem_pc <= id_ex_pc;
            ex_mem_inst <= id_ex_inst;
            ex_mem_alu_result <= alu_result;
            ex_mem_rs2_data <= id_ex_rs2_data;
            ex_mem_rd_addr <= id_ex_rd_addr;
            ex_mem_funct3 <= id_ex_funct3;
            ex_mem_opcode <= id_ex_opcode;
            ex_mem_rs1_data <= id_ex_rs1_data;
            ex_mem_imm <= id_ex_imm;
            ex_mem_rs1_addr <= id_ex_rs1_addr;
            ex_mem_rs2_addr <= id_ex_rs2_addr;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_branch_target <= ex_branch_target;
            ex_mem_branch_taken <= branch_taken;
            
            // MEM/WB: Memory access and prepare writeback
            mem_wb_pc <= ex_mem_pc;
            mem_wb_inst <= ex_mem_inst;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= i_dmem_rdata;
            mem_wb_rd_addr <= ex_mem_rd_addr;
            mem_wb_opcode <= ex_mem_opcode;
            mem_wb_imm <= ex_mem_imm;
            mem_wb_rs1_data <= ex_mem_rs1_data;
            mem_wb_rs2_data <= ex_mem_rs2_data;
            mem_wb_rs1_addr <= ex_mem_rs1_addr;
            mem_wb_rs2_addr <= ex_mem_rs2_addr;
            mem_wb_dmem_addr <= o_dmem_addr;
            mem_wb_dmem_ren <= o_dmem_ren;
            mem_wb_dmem_wen <= o_dmem_wen;
            mem_wb_dmem_mask <= o_dmem_mask;
            mem_wb_dmem_wdata <= o_dmem_wdata;
            mem_wb_dmem_rdata <= i_dmem_rdata;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_reg_write <= ex_mem_reg_write;
            // EBREAK detection
            mem_wb_is_ebreak <= (ex_mem_opcode == 7'b1110011) && (ex_mem_funct3 == 3'b000) && (ex_mem_inst[20] == 1'b1);
        end
    end
    
    //====================================================
    // 11. Retire Interface (from WB stage)
    //====================================================
    // Track cycles to skip initial pipeline fill NOPs
    reg [2:0] cycle_count;
    always @(posedge i_clk) begin
        if (i_rst)
            cycle_count <= 3'd0;
        else if (cycle_count < 3'd4)
            cycle_count <= cycle_count + 3'd1;
    end
    
    assign o_retire_inst  = mem_wb_inst;
    assign o_retire_valid = (cycle_count >= 3'd4);  // Start retiring after pipeline fills
    assign o_retire_trap  = 1'b0;
    assign o_retire_halt  = mem_wb_is_ebreak && !i_rst;
    
    assign o_retire_rs1_raddr = mem_wb_rs1_addr;
    assign o_retire_rs1_rdata = mem_wb_rs1_data;
    assign o_retire_rs2_raddr = mem_wb_rs2_addr;
    assign o_retire_rs2_rdata = mem_wb_rs2_data;
    assign o_retire_rd_waddr  = mem_wb_reg_write ? mem_wb_rd_addr : 5'd0;
    assign o_retire_rd_wdata  = mem_wb_reg_write ? wb_data : 32'd0;
    assign o_retire_pc        = mem_wb_pc;
    assign o_retire_next_pc   = mem_wb_pc + 32'd4;  // Simplified for now
    
    // Retire dmem interface signals
    assign o_retire_dmem_addr  = mem_wb_dmem_addr;
    assign o_retire_dmem_ren   = mem_wb_dmem_ren;
    assign o_retire_dmem_wen   = mem_wb_dmem_wen;
    assign o_retire_dmem_mask  = mem_wb_dmem_mask;
    assign o_retire_dmem_wdata = mem_wb_dmem_wdata;
    assign o_retire_dmem_rdata = mem_wb_dmem_rdata;

endmodule

`default_nettype wire