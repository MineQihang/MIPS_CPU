`timescale 1ns / 1ps

`include "./utils/aludefines.vh"
`include "./utils/defines2.vh"

module datapath(
    input wire clk, rst,
    input wire memtoreg, branch,
    input wire alusrc, regdst,
    input wire regwrite, jump,
    input wire[4:0] alucontrol,
    output wire overflow, zero,
    output wire[31:0] pc,
    input wire[31:0] instr,
    output wire[31:0] aluout, writedata,
    input wire[31:0] readdata,
    input wire memwriteD,
    output wire[3:0] memwrite,
    output wire[31:0] instrD
);

// -------------------------data------------------------------
// controller
wire regwriteD0, regwriteD, regwriteE, memtoregE, branchE, alusrcE, regdstE;
wire memwriteE, memwriteM;
wire[4:0] alucontrolE;
wire regwriteM, memtoregM, branchM;
wire regwriteW, memtoregW;
wire regwriteLD;
// fetch
wire stallF, stallD, pcsrcPD, pbranchF, flushD, pmis;
wire[31:0] nxt_pc, tmp_pc1, tmp_pc2, tmp_pc3, tmp_pc4, pc_plus4F, pc_plus4D, pc_plus4E, pc_plus4M, pc_branchD, pc_branchE, fpcF, fpcD, fpcE, fpcM, pcD, pcE, pcM, pcW;
// decode
wire flushE, pcsrcE, pbranchD;
wire[31:0] rd1D0, rd2D0, rd2D1, rd1D, rd2D, immD, immE, rd1E, rd2E, rd1_data, rd2_data, immD_sl2;
wire[63:0] res;
wire[4:0] rsD, rtD, rdD, rsE, rtE, rdE, wregE, wregM, wregW, saD, saE;
wire[4:0] rtD0, rtE0;
wire linkD, linkPCD, forwardaD, forwardbD;
wire[2:0] flagD_imm, flagD, flagE, flagM, flagW;
wire[5:0] op, opE;
wire jr, jalr, jumpE, jrE, jalrE;
// execute
wire zeroE, flushM, pcsrcPE, pbranchE, tbranch;
wire[31:0] srca, srcbt, srcb, write, writedataM;
wire[63:0] aluoutE, aluoutM;
wire[1:0] forwardaE, forwardbE;
wire[31:0] instrE;
// memory
wire[63:0] aluoutW;
wire[31:0] readdataW;
wire[31:0] pcsrcPM, pcsrcM;
wire[31:0] instrM;
wire[31:0] readdataM;

// -------------------------logic------------------------------
// pc transfer
pc #(32) u_pc(clk, rst, ~stallF, pc_plus4F, tmp_pc1);

mux2 #(32) u_mux_pcbr1(pc_plus4E, pc_branchE, pcsrcPE, tmp_pc2);
mux2 #(32) u_mux_pcf(pc_plus4E, pc_branchE, ~pcsrcPE, fpcE);  // 预测失败时的pc
mux2 #(32) u_mux_branch(tmp_pc1, tmp_pc2, branchE, tmp_pc3);  // 是否分支

assign jr = alucontrol == `ALU_JR;
assign jalr = alucontrol == `ALU_JALR;
mux2 #(32) u_mux_jump({pc_plus4E[31:28], instrE[25:0], 2'b00}, srca, jrE | jalrE, tmp_pc4);

mux2 #(32) u_mux_pc(tmp_pc3, tmp_pc4, jumpE | jrE | jalrE, nxt_pc); // jump
mux2 #(32) u_mux_pcbr2(nxt_pc, fpcM, pmis, pc); // 失败的pc


// ========================Fetch========================
adder pc_adder4(pc, 32'h4, pc_plus4F);

flopenrc #(32) f1(clk, rst, ~stallD, flushD, instr, instrD);
flopenrc #(32) f2(clk, rst, ~stallD, flushD, pc_plus4F, pc_plus4D);
flopenrc #(1) f3(clk, rst, ~stallD, flushD, pbranchF, pbranchD);  // clk
flopenrc #(32) f5(clk, rst, ~stallD, flushD, pc, pcD);  // 分支指令的pc

// ========================Decode========================
assign op = instrD[31:26];
assign rsD = instrD[25:21];
assign rtD0 = instrD[20:16];
assign rdD = instrD[15:11];
assign saD = instrD[10:6];
signext u_signext(instrD[15:0], op, immD);
link u_link(op, rtD0, instrD[5:0], linkD, linkPCD);
mux2 #(1) u_mux2_regwrite(regwrite, 1'b1, linkD, regwriteD0);
mux2 #(1) u_mux2_regwrite2(regwriteD0, 1'b0, jr, regwriteD);
mux2 #(5) u_mux2_rtD(rtD0, 5'b11111, linkD, rtD);
regfile u_regfile(clk, regwriteW, rsD, rtD, wregW, res, flagD_imm, flagW, rd1_data, rd2_data);
sl2 u_sl2(immD, immD_sl2);
adder branch_adder(immD_sl2, pc_plus4D, pc_branchD);

assign rd1D = rd1_data;
// assign rd2D = rd2_data;
mux2 #(32) u_mux2_pc8(rd2_data, pcD+8, linkPCD, rd2D);

// mux2 #(32) u_mux_e2d1(rd1D0, aluoutE[31:0], (rsD != 0 & rsD == rtE & regwriteE), rd1D);
// mux2 #(32) u_mux_e2d2(rd2D1, aluoutE[31:0], (rtD != 0 & rtD == rtE & regwriteE), rd2D);

// mux2 #(32) u_mux2_rd1t(rd1_data, aluoutM[31:0], forwardaD, rd1_data);
// mux2 #(32) u_mux2_rd2t(rd2D, aluoutM[31:0], forwardbD, rd2_data);
// assign pcsrcD = branch & (rd1_data == rd2_data ? 1'b1 : 1'b0);  // 提前分支

assign pcsrcPD = branch & pbranchD;

// hilo
hiloflag u_hiloflag(alucontrol, flagD_imm, flagD);

// 执行预测结果 TODO[2]

floprc #(32) d1(clk, rst, flushE, rd1D, rd1E);
floprc #(32) d2(clk, rst, flushE, rd2D, rd2E);
floprc #(5) d3(clk, rst, flushE, rsD, rsE);
floprc #(5) d4(clk, rst, flushE, rtD, rtE);
floprc #(5) d5(clk, rst, flushE, rdD, rdE);
floprc #(32) d6(clk, rst, flushE, immD, immE);
floprc #(32) d7(clk, rst, flushE, pc_plus4D, pc_plus4E);
floprc #(1) d8(clk, rst, flushE, pcsrcPD, pcsrcPE); 
floprc #(1) d9(clk, rst, flushE, pbranchD, pbranchE);
// floprc #(32) d10(clk, rst, flushE, fpcD, fpcE); // 预测错误时的pc
floprc #(32) d11(clk, rst, flushE, pcD, pcE); // 预测错误时的pc
floprc #(32) d12(clk, rst, flushE, saD, saE); // 预测错误时的pc
floprc #(6) d13(clk, rst, flushE, op, opE); // 预测错误时的pc
floprc #(5) d14(clk, rst, flushE, rtD0, rtE0);
floprc #(32) d15(clk, rst, flushE, instrD, instrE);
floprc #(32) d16(clk, rst, flushE, pc_branchD, pc_branchE);

floprc #(1) dc1(clk, rst, flushE, regwriteD, regwriteE);
floprc #(1) dc2(clk, rst, flushE, memtoreg, memtoregE);
floprc #(1) dc3(clk, rst, flushE, memwriteD, memwriteE);
floprc #(1) dc4(clk, rst, flushE, branch, branchE);
floprc #(5) dc5(clk, rst, flushE, alucontrol, alucontrolE);
floprc #(1) dc6(clk, rst, flushE, alusrc, alusrcE);
floprc #(1) dc7(clk, rst, flushE, regdst, regdstE);
floprc #(3) dc8(clk, rst, flushE, flagD, flagE);
floprc #(1) dc9(clk, rst, flushE, jump, jumpE);
floprc #(1) dc10(clk, rst, flushE, jr, jrE);
floprc #(1) dc11(clk, rst, flushE, jalr, jalrE);

// ========================Execute========================
mux2 #(5) u_mux2_rd(rtE, rdE, regdstE, wregE);
mux3 #(32) u_mux3_srca(rd1E, flagE[2] ? res[31:0] : (flagE[1] ? res[63:32] : res[31:0]), flagE[2] ? aluoutM[31:0] : (flagE[1] ? aluoutM[63:32] : aluoutM[31:0]), forwardaE, srca);
mux3 #(32) u_mux3_srcb(rd2E, res[31:0], aluoutM[31:0], forwardbE, srcbt);
mux2 #(32) u_mux2_src(srcbt, immE, alusrcE, srcb);
alu u_alu(srca, srcb, saE, alucontrolE, aluoutE, overflow, zeroE);

branchjudger u_branchjudger(srca, srcb, opE, rtE0, tbranch);
assign pcsrcE = branchE & tbranch; // execute阶段判断是否预测成功

// 判断是否预测成功 TODO[3]

floprc #(1) e1(clk, rst, flushM, zeroE, zero);
floprc #(64) e2(clk, rst, flushM, aluoutE, aluoutM);
floprc #(32) e3(clk, rst, flushM, srcbt, writedataM);
floprc #(32) e4(clk, rst, flushM, wregE, wregM);
floprc #(1) e5(clk, rst, flushM, pcsrcE, pcsrcM); // 真正的跳转
floprc #(1) e6(clk, rst, flushM, pcsrcPE, pcsrcPM); // 预测的跳转
floprc #(32) e7(clk, rst, flushM, fpcE, fpcM); // 预测错误时的pc
floprc #(32) e8(clk, rst, flushM, pcE, pcM); // 预测错误时的pc
floprc #(32) e9(clk, rst, flushM, instrE, instrM);

floprc #(1) ec1(clk, rst, flushM, regwriteE, regwriteM);
floprc #(1) ec2(clk, rst, flushM, memtoregE, memtoregM);
floprc #(1) ec3(clk, rst, flushM, memwriteE, memwriteM);
floprc #(1) ec4(clk, rst, flushM, branchE, branchM);
floprc #(3) ec5(clk, rst, flushM, flagE, flagM);

// ========================Memory========================
assign aluout = aluoutM[31:0];
assign writedata = instrM[31:26] == `SW ? writedataM : 
                   instrM[31:26] == `SH ? {2{writedataM[15:0]}} :
                   instrM[31:26] == `SB ? {4{writedataM[7:0]}} : 32'b0;

assign memwrite = instrM[31:26] == `SW ? 4'b1111 :
                  instrM[31:26] == `SH ? (
                    aluoutM[1] ? 4'b1100 : 4'b0011
                  ) :
                  instrM[31:26] == `SB ? (
                    aluoutM[1:0] == 2'b00 ? 4'b0001 : 
                    aluoutM[1:0] == 2'b01 ? 4'b0010 : 
                    aluoutM[1:0] == 2'b10 ? 4'b0100 : 4'b1000
                  ) : 4'b0000;

assign readdataM = instrM[31:26] == `LW ? readdata : 
                   instrM[31:26] == `LH ? (
                    aluoutM[1] ? {{16{readdata[31]}}, readdata[31:16]} : 
                                 {{16{readdata[15]}}, readdata[15:0]}
                   ) : 
                   instrM[31:26] == `LHU ? (
                    aluoutM[1] ? {{16{1'b0}}, readdata[31:16]} : 
                                 {{16{1'b0}}, readdata[15:0]}
                   ) : 
                   instrM[31:26] == `LB ? (
                    aluoutM[1:0] == 2'b00 ? {{24{readdata[7]}}, readdata[7:0]} : 
                    aluoutM[1:0] == 2'b01 ? {{24{readdata[15]}}, readdata[15:8]} : 
                    aluoutM[1:0] == 2'b10 ? {{24{readdata[23]}}, readdata[23:16]} : 
                                            {{24{readdata[31]}}, readdata[31:24]}
                   ) : 
                   instrM[31:26] == `LBU ? (
                    aluoutM[1:0] == 2'b00 ? {{24{1'b0}}, readdata[7:0]} : 
                    aluoutM[1:0] == 2'b01 ? {{24{1'b0}}, readdata[15:8]} : 
                    aluoutM[1:0] == 2'b10 ? {{24{1'b0}}, readdata[23:16]} : 
                                            {{24{1'b0}}, readdata[31:24]}
                   ) : 32'b0;

// 处理错误预测和更新PHT TODO[4]


floprc #(64) m1(clk, rst, 1'b0, aluoutM, aluoutW);
floprc #(32) m2(clk, rst, 1'b0, readdataM, readdataW);
floprc #(32) m3(clk, rst, 1'b0, wregM, wregW);
floprc #(32) m4(clk, rst, flushM, pcM, pcW);

floprc #(1) mc1(clk, rst, 1'b0, regwriteM, regwriteW);
floprc #(1) mc2(clk, rst, 1'b0, memtoregM, memtoregW);
floprc #(3) mc3(clk, rst, 1'b0, flagM, flagW);

// ========================Writeback========================
mux2 #(64) u_mux2_readdata(aluoutW, {32'b0, readdataW}, memtoregW, res);

// hazard
hazard u_hazard(
    //fetch
    stallF,
    //decode
    rsD,rtD,
    branch,
    forwardaD,forwardbD,
    stallD,
    //execute
    rsE,rtE,
    wregE,
    regwriteE,
    memtoregE,
    forwardaE,forwardbE,
    // flushE,
    //memory
    wregM,
    regwriteM,
    memtoregM,
    // flushM, // [1]新增flushM, 因为是在Memory阶段才处理错误，这时错误可能已经传到Execution到Memory阶段的寄存器中，所以需要清空
    //writeback
    wregW,
    regwriteW,
    // hilo
    flagE, flagM, flagW
);

// 分支预测 TODO[1]
branchpredictor bp(
    // input
    clk, rst,
    pc, // 当前pc
    pcsrcM, // 真正的方向
    pcsrcPM, // 预测的方向
    fpcM, // 预测错误后的pc
    pcM, // 之前的pc
    branchM, // 之前是否是分支
    pcD, // D阶段的pc
    branch, // D阶段的branch
    // output
    pbranchF, // 预测值
    pmis, // 是否预测错误
    flushD, // 清空F->D
    flushE, // 清空D->X
    flushM // 清空X->M
); // 分支预测器

endmodule