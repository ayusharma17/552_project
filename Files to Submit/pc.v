`timescale 1ns / 1ps
`default_nettype none

//-----------------------------------------------------
// Program Counter (PC)
//-----------------------------------------------------
// Holds the current instruction address.
// On reset:  loads RESET_ADDR.
// Otherwise: updates with pc_next on each rising clock.
//
module pc #(
    parameter RESET_ADDR = 32'h00000000
)(
    input  wire        clk,       // system clock
    input  wire        rst,       // synchronous active-high reset
    input  wire [31:0] pc_next,   // next PC value from datapath
    output wire [31:0] pc_curr    // current PC value to instruction memory
);

    // internal register to hold PC
    reg [31:0] pc_reg;

    // sequential update of PC
    always @(posedge clk) begin
    if (rst)
        pc_reg <= RESET_ADDR;
    else
        pc_reg <= pc_next;
    end


    // drive output
    assign pc_curr = pc_reg;

endmodule

`default_nettype wire