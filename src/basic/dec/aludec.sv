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
            endcase
        `ANDI: alucontrol <= `ALU_ANDI;
        `XORI: alucontrol <= `ALU_XORI;
        `LUI:  alucontrol <= `ALU_LUI;
        `ORI:  alucontrol <= `ALU_ORI;
        default: alucontrol <= `ALU_DONOTHING;
    endcase
end

endmodule