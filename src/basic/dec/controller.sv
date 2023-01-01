`timescale 1ns / 1ps

module controller(
    input wire[5:0] op, funct,
    input wire zero,
    output wire memtoreg, memwrite, branch, alusrc, regdst, regwrite, jump,
    output wire[4:0] alucontrol
);

maindec u_maindec(op, memtoreg, memwrite, branch, alusrc, regdst, regwrite, jump);
aludec u_aludec(funct, op, alucontrol);

endmodule