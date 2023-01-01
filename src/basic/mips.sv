`timescale 1ns / 1ps

module mips(
    input wire clk,rst,
    output wire[31:0] pc,
    input wire[31:0] instr,
    output wire memwrite,
    output wire[31:0] aluout,writedata,
    input wire[31:0] readdata 
);

wire memtoreg,alusrc,regdst,regwrite,jump,branch,zero,overflow, memwriteD;
wire[4:0] alucontrol;
wire[31:0] instrD;

controller u_controller(instrD[31:26], instrD[5:0], zero, memtoreg, memwriteD, branch, alusrc, regdst, regwrite, jump, alucontrol);
datapath u_datapath(clk, rst, memtoreg, branch, alusrc, regdst, regwrite, jump, alucontrol, overflow, zero, pc, instr, aluout, writedata, readdata, memwriteD, memwrite, instrD);

endmodule
