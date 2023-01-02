`timescale 1ns / 1ps

module controller(
    input wire[5:0] op, funct,
    input wire zero,
    output wire memtoreg, branch, alusrc, regdst, regwrite, jump,
    output wire[4:0] alucontrol,
    output wire memwrite
);

maindec u_maindec(op, memtoreg, branch, alusrc, regdst, regwrite, jump, memwrite);
aludec u_aludec(funct, op, alucontrol);

endmodule