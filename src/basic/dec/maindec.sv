`timescale 1ns / 1ps

`include "../utils/defines2.vh"

module maindec(
    input  wire[5:0] op,
    output wire memtoreg, memwrite, branch, alusrc, regdst, regwrite, jump
);

reg[6:0] controls;

assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump} = controls;
always @(*) begin
    case (op)
        `R_TYPE: controls <= 7'b1100000;  // R-type
        6'b100011: controls <= 7'b1010010;  // lw
        6'b101011: controls <= 7'b0010100;  // sw
        `BEQ: controls <= 7'b0001000;
        `BNE: controls <= 7'b0001000;
        `BGTZ: controls <= 7'b0001000;
        `BLEZ: controls <= 7'b0001000;
        `REGIMM_INST: controls <= 7'b0001000;
        6'b001000: controls <= 7'b1010000;  // addi
        `J: controls <= 7'b0000001;
        `JAL: controls <= 7'b0000001;
        // new
        `ANDI: controls <= 7'b1010000;
        `XORI: controls <= 7'b1010000;
        `LUI:  controls <= 7'b1010000;
        `ORI:  controls <= 7'b1010000;
        `ADDI: controls <= 7'b1010000;
        `ADDIU: controls <= 7'b1010000;
        `SLTI: controls <= 7'b1010000;
        `SLTIU: controls <= 7'b1010000;
        default:   controls <= 7'b0000000;
    endcase
end

endmodule