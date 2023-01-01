`timescale 1ns / 1ps

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
    output wire memwrite,
    output wire[31:0] instrD
);

// -------------------------data------------------------------
// controller
wire regwriteE, memtoregE, memwriteE, branchE, alusrcE, regdstE;
wire[4:0] alucontrolE;
wire regwriteM, memtoregM, memwriteM, branchM;
wire regwriteW, memtoregW;
// fetch
wire stallF, stallD, pcsrcPD, pbranchF, flushD, pmis;
wire[31:0] nxt_pc, tmp_pc1, tmp_pc2, tmp_pc3, pc_plus4F, pc_plus4D, pc_plus4E, pc_plus4M, pc_branchD, fpcF, fpcD, fpcE, fpcM, pcD, pcE, pcM, pcW;
// decode
wire flushE, pcsrcE, pbranchD;
wire[31:0] rd1D, rd2D, immD, immE, res, rd1E, rd2E, rd1_data, rd2_data, immD_sl2;
wire[4:0] rsD, rtD, rdD, rsE, rtE, rdE, wregE, wregM, wregW;
wire forwardaD, forwardbD;
// execute
wire zeroE, flushM, pcsrcPE, pbranchE;
wire[31:0] srca, srcbt, srcb, write, aluoutE, aluoutM, writedataM;
wire[1:0] forwardaE, forwardbE;
// memory
wire [31:0] aluoutW, readdataW;
wire[31:0] pcsrcPM, pcsrcM;

// -------------------------logic------------------------------
// pc transfer
pc #(32) u_pc(clk, rst, ~stallF, pc_plus4F, tmp_pc1);
mux2 #(32) u_mux_pcbr1(pc_plus4D, pc_branchD, pcsrcPD, tmp_pc2);
mux2 #(32) u_mux_pcf(pc_plus4D, pc_branchD, ~pcsrcPD, fpcD);  // 预测失败时的pc
mux2 #(32) u_mux_branch(tmp_pc1, tmp_pc2, branch, tmp_pc3);  // 是否分支

mux2 #(32) u_mux_pc(tmp_pc3, {pc_plus4D[31:28], instrD[25:0], 2'b00}, jump, nxt_pc); // jump
mux2 #(32) u_mux_pcbr2(nxt_pc, fpcM, pmis, pc); // 失败的pc


// ========================Fetch========================
adder pc_adder4(pc, 32'h4, pc_plus4F);

flopenrc #(32) f1(clk, rst, ~stallD, flushD, instr, instrD);
flopenrc #(32) f2(clk, rst, ~stallD, flushD, pc_plus4F, pc_plus4D);
flopenrc #(1) f3(clk, rst, ~stallD, flushD, pbranchF, pbranchD);  // clk
flopenrc #(32) f5(clk, rst, ~stallD, flushD, pc, pcD);  // 分支指令的pc

// ========================Decode========================
assign rsD = instrD[25:21];
assign rtD = instrD[20:16];
assign rdD = instrD[15:11];
signext u_signext(instrD[15:0], immD);
regfile u_regfile(clk, regwriteW, rsD, rtD, wregW, res, rd1D, rd2D);
sl2 u_sl2(immD, immD_sl2);
adder branch_adder(immD_sl2, pc_plus4D, pc_branchD);

mux2 #(32) u_mux2_rd1t(rd1D, aluoutM, forwardaD, rd1_data);
mux2 #(32) u_mux2_rd2t(rd2D, aluoutM, forwardbD, rd2_data);
// assign pcsrcD = branch & (rd1_data == rd2_data ? 1'b1 : 1'b0);  // 提前分支
assign pcsrcPD = branch & pbranchD;

// 执行预测结果 TODO[2]

floprc #(32) d1(clk, rst, flushE, rd1D, rd1E);
floprc #(32) d2(clk, rst, flushE, rd2D, rd2E);
floprc #(5) d3(clk, rst, flushE, rsD, rsE);
floprc #(5) d4(clk, rst, flushE, rtD, rtE);
floprc #(5) d5(clk, rst, flushE, rdD, rdE);
floprc #(32) d6(clk, rst, flushE, immD, immE);
// floprc #(32) d7(clk, rst, flushE, pc_plus4D, pc_plus4E);
floprc #(1) d7(clk, rst, flushE, pcsrcPD, pcsrcPE);
floprc #(1) d8(clk, rst, flushE, pbranchD, pbranchE);
floprc #(32) d9(clk, rst, flushE, fpcD, fpcE); // 预测错误时的pc
floprc #(32) d10(clk, rst, flushE, pcD, pcE); // 预测错误时的pc

floprc #(1) dc1(clk, rst, flushE, regwrite, regwriteE);
floprc #(1) dc2(clk, rst, flushE, memtoreg, memtoregE);
floprc #(1) dc3(clk, rst, flushE, memwriteD, memwriteE);
floprc #(1) dc4(clk, rst, flushE, branch, branchE);
floprc #(5) dc5(clk, rst, flushE, alucontrol, alucontrolE);
floprc #(1) dc6(clk, rst, flushE, alusrc, alusrcE);
floprc #(1) dc7(clk, rst, flushE, regdst, regdstE);

// ========================Execute========================
mux2 #(5) u_mux2_rd(rtE, rdE, regdstE, wregE);
mux3 #(32) u_mux3_srca(rd1E, res, aluoutM, forwardaE, srca);
mux3 #(32) u_mux3_srcb(rd2E, res, aluoutM, forwardbE, srcbt);
mux2 #(32) u_mux2_src(srcbt, immE, alusrcE, srcb);
alu u_alu(srca, srcb, alucontrolE, aluoutE, overflow, zeroE);

assign pcsrcE = branchE & (srca == srcb); // execute阶段判断是否预测成功

// 判断是否预测成功 TODO[3]

floprc #(1) e1(clk, rst, flushM, zeroE, zero);
floprc #(32) e2(clk, rst, flushM, aluoutE, aluoutM);
floprc #(32) e3(clk, rst, flushM, srcbt, writedataM);
floprc #(32) e4(clk, rst, flushM, wregE, wregM);
floprc #(1) e5(clk, rst, flushM, pcsrcE, pcsrcM); // 真正的跳转
floprc #(1) e6(clk, rst, flushM, pcsrcPE, pcsrcPM); // 预测的跳转
floprc #(32) e7(clk, rst, flushM, fpcE, fpcM); // 预测错误时的pc
floprc #(32) e8(clk, rst, flushM, pcE, pcM); // 预测错误时的pc

floprc #(1) ec1(clk, rst, flushM, regwriteE, regwriteM);
floprc #(1) ec2(clk, rst, flushM, memtoregE, memtoregM);
floprc #(1) ec3(clk, rst, flushM, memwriteE, memwriteM);
floprc #(1) ec4(clk, rst, flushM, branchE, branchM);

// ========================Memory========================
assign aluout = aluoutM;
assign writedata = writedataM;
assign memwrite = memwriteM;

// 处理错误预测和更新PHT TODO[4]


floprc #(32) m1(clk, rst, 1'b0, aluoutM, aluoutW);
floprc #(32) m2(clk, rst, 1'b0, readdata, readdataW);
floprc #(32) m3(clk, rst, 1'b0, wregM, wregW);
floprc #(32) m4(clk, rst, flushM, pcM, pcW);

floprc #(1) mc1(clk, rst, 1'b0, regwriteM, regwriteW);
floprc #(1) mc2(clk, rst, 1'b0, memtoregM, memtoregW);

// ========================Writeback========================
mux2 #(32) u_mux2_readdata(aluoutW, readdataW, memtoregW, res);

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
    regwriteW
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