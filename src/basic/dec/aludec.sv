`timescale 1ns / 1ps

`include "../utils/aludefines.vh"
`include "../utils/defines2.vh"

module aludec(
    input wire[5:0] funct,
    input wire[5:0] op,
    output reg[4:0] alucontrol
);

always @(*) begin
    case (op)
        `R_TYPE:
            case (funct)
                `AND: alucontrol <= `ALU_AND;
                `OR:  alucontrol <= `ALU_OR;
                `XOR: alucontrol <= `ALU_XOR;
                `NOR: alucontrol <= `ALU_NOR;

                `SLL: alucontrol <= `ALU_SLL;
                `SRL: alucontrol <= `ALU_SRL;
                `SRA: alucontrol <= `ALU_SRA;
                `SLLV: alucontrol <= `ALU_SLLV;
                `SRLV: alucontrol <= `ALU_SRLV;
                `SRAV: alucontrol <= `ALU_SRAV;

                `MFHI: alucontrol <= `ALU_MFHI;
                `MFLO: alucontrol <= `ALU_MFLO;
                `MTHI: alucontrol <= `ALU_MTHI;
                `MTLO: alucontrol <= `ALU_MTLO;

                `ADD:  alucontrol <= `ALU_ADD;
                `ADDU: alucontrol <= `ALU_ADDU;
                `SUB:  alucontrol <= `ALU_SUB;
                `SUBU: alucontrol <= `ALU_SUBU;
                `SLT:  alucontrol <= `ALU_SLT;
                `SLTU: alucontrol <= `ALU_SLTU;
                `DIV:  alucontrol <= `ALU_DIV;
                `DIVU: alucontrol <= `ALU_DIVU;
                `MULT: alucontrol <= `ALU_MULT;
                `MULTU: alucontrol <= `ALU_MULTU;

                `JR: alucontrol <= `ALU_JR;
                `JALR: alucontrol <= `ALU_JALR;

                default: alucontrol <= `ALU_ZERO;
            endcase
        `ANDI: alucontrol <= `ALU_AND;
        `XORI: alucontrol <= `ALU_XOR;
        `LUI:  alucontrol <= `ALU_LUI;
        `ORI:  alucontrol <= `ALU_OR;
        `ADDI: alucontrol <= `ALU_ADD;
        `ADDIU: alucontrol <= `ALU_ADDU;
        `SLTI: alucontrol <= `ALU_SLT;
        `SLTIU: alucontrol <= `ALU_SLTU;
        `REGIMM_INST: alucontrol <= `ALU_DONOTHING;
        `JAL: alucontrol <= `ALU_DONOTHING;

        `SW: alucontrol <= `ALU_ADD;
        `SH: alucontrol <= `ALU_ADD;
        `SB: alucontrol <= `ALU_ADD;
        `LB: alucontrol <= `ALU_ADD;
        `LBU: alucontrol <= `ALU_ADD;
        `LH: alucontrol <= `ALU_ADD;
        `LHU: alucontrol <= `ALU_ADD;
        `LW: alucontrol <= `ALU_ADD;

        default: alucontrol <= `ALU_ZERO;
    endcase
end

endmodule