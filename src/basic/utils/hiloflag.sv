`timescale 1ns / 1ps

`include "aludefines.vh"

module hiloflag(
    input wire[4:0] alucontrol,
    output reg[2:0] flag1,  // 读的时候判断的
    output reg[2:0] flag2   // 写的时候判断的
);
    always @(*) begin
        case(alucontrol)
            `ALU_MFHI: begin
                flag1 <= 3'b110;
                flag2 <= 3'b010;
            end
            `ALU_MFLO: begin
                flag1 <= 3'b101;
                flag2 <= 3'b001;
            end
            `ALU_MTHI: begin
                flag1 <= 3'b010;
                flag2 <= 3'b110;
            end
            `ALU_MTLO: begin
                flag1 <= 3'b001;
                flag2 <= 3'b101;
            end
            default: begin
                flag1 <= 3'b000;
                flag2 <= 3'b000;
            end
        endcase
    end
endmodule