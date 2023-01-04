`timescale 1ns / 1ps

module mips(
    input wire clk,rst,
    input wire[5:0] ext_int,
    output wire[31:0] pc,
    input wire[31:0] instr,
    output wire[3:0] memwrite,
    output wire[31:0] aluout,writedata,
    input wire[31:0] readdata,
    //debug
    output wire [31:0]  debug_wb_pc,      
    output wire [3:0]   debug_wb_rf_wen,
    output wire [4:0]   debug_wb_rf_wnum, 
    output wire [31:0]  debug_wb_rf_wdata
);

wire memtoreg,alusrc,regdst,regwrite,jump,branch,zero,overflow;
wire[4:0] alucontrol;
wire[31:0] instrD;
wire memwriteD, instrErrorD;

controller u_controller(instrD, zero, memtoreg, branch, alusrc, regdst, regwrite, jump, alucontrol, memwriteD, instrErrorD);
datapath u_datapath(clk, rst, ext_int, memtoreg, branch, alusrc, regdst, regwrite, jump, alucontrol, overflow, zero, pc, instr, aluout, writedata, readdata, memwriteD, memwrite, instrD, instrErrorD,
debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum, debug_wb_rf_wdata
);

endmodule
