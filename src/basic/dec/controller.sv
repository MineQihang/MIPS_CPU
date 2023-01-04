`timescale 1ns / 1ps

module controller(
    input wire[31:0] instrD,
    input wire zero,
    output wire memtoreg, branch, alusrc, regdst, regwrite, jump,
    output wire[4:0] alucontrol,
    output wire memwrite,
    output wire instrErrorD
);

wire[5:0] op, funct;

maindec u_maindec(instrD, memtoreg, branch, alusrc, regdst, regwrite, jump, memwrite, instrErrorD);
aludec u_aludec(instrD[5:0], instrD[31:26], alucontrol);

endmodule