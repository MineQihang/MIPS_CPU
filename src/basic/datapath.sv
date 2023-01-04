`timescale 1ns / 1ps

`include "./utils/aludefines.vh"
`include "./utils/defines2.vh"

module datapath(
    input wire clk, rst,
    input wire[5:0] ext_int,
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
    output wire[31:0] instrD,

    input wire instrErrorD,

    //debug
    output wire [31:0]  debug_wb_pc,      
    output wire [3:0]   debug_wb_rf_wen,
    output wire [4:0]   debug_wb_rf_wnum, 
    output wire [31:0]  debug_wb_rf_wdata
);

// -------------------------data------------------------------
// controller
wire regwriteD0, regwriteD, regwriteE, memtoregE, branchE, alusrcE, regdstE;
wire memwriteE, memwriteM, memwriteM0;
wire[4:0] alucontrolE;
wire regwriteM, memtoregM, branchM;
wire regwriteW, memtoregW;
wire regwriteLD;
// fetch
wire stallF, stallD, pcsrcPD, pbranchF, flushD, pmis;
wire[31:0] nxt_pc, tmp_pc1, tmp_pc2D, tmp_pc2E, tmp_pc3, tmp_pc4, tmp_pc5, tmp_pc6, pc_plus4F, pc_plus4D, pc_plus4E, pc_plus4M, pc_branchD, pc_branchE, fpcF, fpcD, fpcE, fpcM, pcD, pcE, pcM, pcW;
// decode
wire flushE, pcsrcE, pbranchD, stallE;
wire[31:0] rd1D0, rd2D0, rd2D1, rd1D, rd2D, immD, immE, rd1E, rd2E, rd1_data, rd2_data, immD_sl2;
wire[63:0] res;
wire[4:0] rsD, rtD, rdD, rsE, rtE, rdE, rdM, wregE, wregM, wregW, saD, saE;
wire[4:0] rtD0, rtE0;
wire linkD, linkPCD, forwardaD, forwardbD;
wire[2:0] flagD_imm, flagD, flagE, flagM, flagW;
wire[5:0] op, opE;
wire jr, jalr, jumpE, jrE, jalrE;
// execute
wire zeroE, flushM, pcsrcPE, pbranchE, tbranch, stallM;
wire[31:0] srca, srcbt, srcb, write, writedataM;
wire[63:0] aluoutE, aluoutM;
wire[1:0] forwardaE, forwardbE;
wire[31:0] instrE;
wire tflushE;
// memory
wire[63:0] aluoutW;
wire[31:0] readdataW;
wire[31:0] pcsrcPM, pcsrcM;
wire[31:0] instrM;
wire[31:0] readdataM;
wire[5:0] opM;
wire stallW;
wire tflushM;
// 中断与异常
wire intM;
wire overflowM;
wire riM;
wire addrErrorL, addrErrorS, pcError;
wire breakD, breakE, breakM;
wire syscallD, syscallE, syscallM;
wire eretD, eretE, eretM;
wire indelayslotF, indelayslotD, indelayslotE, indelayslotM;
wire[5:0] exctype;
wire[31:0] cp0data;
wire isexc, isexcM;
wire writecp0D, writecp0E, writecp0M;
wire[31:0] badvaddr;
wire[31:0] epc;
wire[31:0] statusE, statusM, causeE, causeM;
wire instrErrorE, instrErrorM;

// c0
wire mfc0D, mtc0D, mfc0E, mtc0E, mfc0M, mtc0M;

// -------------------------logic------------------------------
// pc transfer
pc #(32) u_pc(clk, rst, ~stallF, pc_plus4F, tmp_pc1);

mux2 #(32) u_mux_pcbr1(pc_plus4D, pc_branchD, pcsrcPD, tmp_pc2D);
mux2 #(32) u_mux_pcf(pc_plus4D + 4, pc_branchD, ~pcsrcPD, fpcD);  // 预测失败时的pc
mux2 #(32) u_mux_branch(tmp_pc1, tmp_pc2E, branchE, tmp_pc3);  // 是否分支

assign jr = alucontrol == `ALU_JR;
assign jalr = alucontrol == `ALU_JALR;
mux2 #(32) u_mux_jump({pc_plus4E[31:28], instrE[25:0], 2'b00}, srca, jrE | jalrE, tmp_pc4);

mux2 #(32) u_mux_pc(tmp_pc3, tmp_pc4, jumpE | jrE | jalrE, tmp_pc5); // jump

mux2 #(32) u_mux_pcbr2(tmp_pc5, fpcM, pmis, tmp_pc6); // 失败的pc

mux2 #(32) u_mux_pc2(tmp_pc6, `EXC_ENTRY, isexc, nxt_pc); // 异常
mux2 #(32) u_mux_pc3(nxt_pc, epc, eretM, pc); // ERET

// ========================Fetch========================
adder pc_adder4(pc, 32'h4, pc_plus4F);
assign indelayslotF = jump | jr | jalr | (branch & ~tflushE);

flopenrc #(32) f1(clk, rst, ~stallD, flushD, instr, instrD);
flopenrc #(32) f2(clk, rst, ~stallD, flushD, pc_plus4F, pc_plus4D);
flopenrc #(1) f3(clk, rst, ~stallD, flushD, pbranchF, pbranchD);  // clk
flopenrc #(32) f5(clk, rst, ~stallD, flushD, pc, pcD);  // 分支指令的pc
flopenrc #(1) f6(clk, rst, ~stallD, flushD, indelayslotF, indelayslotD);

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

// 中断与异常判断
assign breakD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001101);
assign syscallD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001100);
assign eretD = (instrD == 32'b01000010000000000000000000011000);

// c0
assign mfc0D = (instrD[31:26] == `SPECIAL3_INST && instrD[25:21] == `MFC0) ? 1'b1 : 1'b0;
assign mtc0D = (instrD[31:26] == `SPECIAL3_INST && instrD[25:21] == `MTC0) ? 1'b1 : 1'b0;

// 执行预测结果 TODO[2]
assign tflushE = flushE | stallD | isexc;

floprc #(32) d1(clk, rst, tflushE, rd1D, rd1E);
floprc #(32) d2(clk, rst, tflushE, rd2D, rd2E);
floprc #(5) d3(clk, rst, tflushE, rsD, rsE);
floprc #(5) d4(clk, rst, tflushE, rtD, rtE);
floprc #(5) d5(clk, rst, tflushE, rdD, rdE);
floprc #(32) d6(clk, rst, tflushE, immD, immE);
floprc #(32) d7(clk, rst, tflushE, pc_plus4D, pc_plus4E);
floprc #(1) d8(clk, rst, tflushE, pcsrcPD, pcsrcPE); 
floprc #(1) d9(clk, rst, tflushE, pbranchD, pbranchE);
floprc #(32) d10(clk, rst, isexc, fpcD, fpcE); // 预测错误时的pc
floprc #(32) d11(clk, rst, isexc, pcD, pcE); // 预测错误时的pc
floprc #(32) d12(clk, rst, tflushE, saD, saE); // 预测错误时的pc
floprc #(6) d13(clk, rst, tflushE, op, opE); // 预测错误时的pc
floprc #(5) d14(clk, rst, tflushE, rtD0, rtE0);
floprc #(32) d15(clk, rst, tflushE, instrD, instrE);
floprc #(32) d16(clk, rst, tflushE, pc_branchD, pc_branchE);
floprc #(32) d17(clk, rst, tflushE, tmp_pc2D, tmp_pc2E);

floprc #(1) dc1(clk, rst, tflushE, regwriteD, regwriteE);
floprc #(1) dc2(clk, rst, tflushE, memtoreg, memtoregE);
floprc #(1) dc3(clk, rst, tflushE, memwriteD, memwriteE);
floprc #(1) dc4(clk, rst, tflushE, branch, branchE);
floprc #(5) dc5(clk, rst, tflushE, alucontrol, alucontrolE);
floprc #(1) dc6(clk, rst, tflushE, alusrc, alusrcE);
floprc #(1) dc7(clk, rst, tflushE, regdst, regdstE);
floprc #(3) dc8(clk, rst, tflushE, flagD, flagE);
floprc #(1) dc9(clk, rst, tflushE, jump, jumpE);
floprc #(1) dc10(clk, rst, tflushE, jr, jrE);
floprc #(1) dc11(clk, rst, tflushE, jalr, jalrE);
floprc #(1) dc12(clk, rst, tflushE, stallD, stallE);
floprc #(1) dc13(clk, rst, isexc, breakD, breakE);
floprc #(1) dc14(clk, rst, isexc, syscallD, syscallE);
floprc #(1) dc15(clk, rst, isexc, eretD, eretE);
floprc #(1) dc16(clk, rst, tflushE, mfc0D, mfc0E);
floprc #(1) dc17(clk, rst, tflushE, mtc0D, mtc0E);
floprc #(1) dc18(clk, rst, isexc, indelayslotD, indelayslotE);
floprc #(1) dc19(clk, rst, tflushE, instrErrorD, instrErrorE);

// ========================Execute========================
mux2 #(5) u_mux2_rd(rtE, rdE, regdstE, wregE);
mux3 #(32) u_mux3_srca(rd1E, (~flagE[2] & flagE[1]) | (~flagW[0] & flagW[1]) ? res[63:32] : res[31:0], (~flagE[2] & flagE[1]) | (~flagM[0] & flagM[1]) ? aluoutM[63:32] : aluoutM[31:0], forwardaE, srca);
mux3 #(32) u_mux3_srcb(rd2E, (~flagE[2] & flagE[1]) | (~flagW[0] & flagW[1]) ? res[63:32] : res[31:0], (~flagE[2] & flagE[1]) | (~flagM[0] & flagM[1]) ? aluoutM[63:32] : aluoutM[31:0], forwardbE, srcbt);
mux2 #(32) u_mux2_src(srcbt, immE, alusrcE, srcb);
alu u_alu(srca, srcb, saE, alucontrolE, aluoutE, overflow, zeroE);

branchjudger u_branchjudger(srca, srcb, opE, rtE0, tbranch);
assign pcsrcE = branchE & tbranch; // execute阶段判断是否预测成功

// 判断是否预测成功 TODO[3]
assign tflushM = isexc;

floprc #(1) e1(clk, rst, tflushM, zeroE, zero);
floprc #(64) e2(clk, rst, tflushM, mtc0E ? {32'b0, srcb} : (mfc0E ? {32'b0, cp0data} : aluoutE), aluoutM);
floprc #(32) e3(clk, rst, tflushM, srcbt, writedataM);
floprc #(5) e4(clk, rst, tflushM, wregE, wregM);
floprc #(1) e5(clk, rst, tflushM, pcsrcE, pcsrcM); // 真正的跳转
floprc #(1) e6(clk, rst, tflushM, pcsrcPE, pcsrcPM); // 预测的跳转
floprc #(32) e7(clk, rst, isexc, fpcE, fpcM); // 预测错误时的pc
floprc #(32) e8(clk, rst, isexc, pcE, pcM); // 预测错误时的pc
floprc #(32) e9(clk, rst, tflushM, instrE, instrM);
floprc #(5) e10(clk, rst, tflushM, rdE, rdM);
floprc #(5) e11(clk, rst, tflushM, overflow, overflowM);

floprc #(1) ec1(clk, rst, tflushM, regwriteE, regwriteM);
floprc #(1) ec2(clk, rst, tflushM, memtoregE, memtoregM);
floprc #(1) ec3(clk, rst, tflushM, memwriteE, memwriteM0);
floprc #(1) ec4(clk, rst, tflushM, branchE, branchM);
floprc #(3) ec5(clk, rst, tflushM, flagE, flagM);
floprc #(1) ec6(clk, rst, tflushM, stallE, stallM);
floprc #(1) ec7(clk, rst, isexc, breakE, breakM);
floprc #(1) ec8(clk, rst, isexc, syscallE, syscallM);
floprc #(1) ec9(clk, rst, isexc, eretE, eretM);
floprc #(1) ec10(clk, rst, tflushM, mfc0E, mfc0M);
floprc #(1) ec11(clk, rst, tflushM, mtc0E, mtc0M);
floprc #(32) ec12(clk, rst, tflushM, statusE, statusM);
floprc #(1) ec13(clk, rst, isexc, indelayslotE, indelayslotM);
floprc #(1) ec14(clk, rst, tflushM, instrErrorE, instrErrorM);
floprc #(32) ec15(clk, rst, tflushM, causeE, causeM);


// ========================Memory========================
assign opM = instrM[31:26];
assign aluout = aluoutM[31:0];
assign memwriteM = isexc ? 1'b0 : memwriteM0;
assign writedata = opM == `SW ? writedataM : 
                   opM == `SH ? {2{writedataM[15:0]}} :
                   opM == `SB ? {4{writedataM[7:0]}} : 32'b0;

assign memwrite = memwriteM ? (opM == `SW ? 4'b1111 :
                  opM == `SH ? (
                    aluoutM[1] ? 4'b1100 : 4'b0011
                  ) :
                  opM == `SB ? (
                    aluoutM[1:0] == 2'b00 ? 4'b0001 : 
                    aluoutM[1:0] == 2'b01 ? 4'b0010 : 
                    aluoutM[1:0] == 2'b10 ? 4'b0100 : 4'b1000
                  ) : 4'b0000) : 4'b0000;

assign readdataM = opM == `LW ? readdata : 
                   opM == `LH ? (
                    aluoutM[1] ? {{16{readdata[31]}}, readdata[31:16]} : 
                                 {{16{readdata[15]}}, readdata[15:0]}
                   ) : 
                   opM == `LHU ? (
                    aluoutM[1] ? {{16{1'b0}}, readdata[31:16]} : 
                                 {{16{1'b0}}, readdata[15:0]}
                   ) : 
                   opM == `LB ? (
                    aluoutM[1:0] == 2'b00 ? {{24{readdata[7]}}, readdata[7:0]} : 
                    aluoutM[1:0] == 2'b01 ? {{24{readdata[15]}}, readdata[15:8]} : 
                    aluoutM[1:0] == 2'b10 ? {{24{readdata[23]}}, readdata[23:16]} : 
                                            {{24{readdata[31]}}, readdata[31:24]}
                   ) : 
                   opM == `LBU ? (
                    aluoutM[1:0] == 2'b00 ? {{24{1'b0}}, readdata[7:0]} : 
                    aluoutM[1:0] == 2'b01 ? {{24{1'b0}}, readdata[15:8]} : 
                    aluoutM[1:0] == 2'b10 ? {{24{1'b0}}, readdata[23:16]} : 
                                            {{24{1'b0}}, readdata[31:24]}
                   ) : 32'b0;

assign addrErrorS = opM == `SW ? (|aluout[1:0]) :
                    opM == `SH ? aluout[0] : 1'b0;

assign addrErrorL = opM == `LW ? (|aluout[1:0]) :
                    opM == `LH ? aluout[0] :
                    opM == `LHU ? aluout[0] : 1'b0;

assign pcError = (pcM[1:0] != 2'b00) ? 1'b1 : 1'b0;

assign badvaddr = pcError ? pcM : 
                  (addrErrorS | addrErrorL) ? aluout[31:0] : 31'b0;

// 异常与中断
assign riM = instrErrorM;
assign intM = statusM[0] && ~statusM[1] && (
              ( |(statusM[9:8] & causeM[9:8]) ) ||     //soft interupt
              ( |(statusM[15:10] & ext_int) )           //hard interupt
);
assign exctype = (intM)                  ? `EXC_TYPE_INT :
                 (addrErrorL | pcError)  ? `EXC_TYPE_ADEL :
                 (addrErrorS)            ? `EXC_TYPE_ADES :
                 (syscallM)              ? `EXC_TYPE_SYS :
                 (breakM)                ? `EXC_TYPE_BP :
                 (riM)                   ? `EXC_TYPE_RI :
                 (overflowM)             ? `EXC_TYPE_OV :
                 (eretM)                 ? `EXC_TYPE_ERET :
                                           `EXC_TYPE_NOEXC;

assign isexc = (exctype == `EXC_TYPE_NOEXC) ? 1'b0 : 1'b1;

cp0_reg u_cp0_reg(
    .clk(clk), .rst(rst),
    .en(isexc),
    .enw(mtc0M),

    .indelayslot(indelayslotM),
    .pc(pcM),
    .badvaddr(badvaddr),
    
    .exctype(exctype),
    .raddr(rdE),
    .waddr(rdM),

    .writedata(aluoutM[31:0]),
    .readdata(cp0data),

    .epc(epc),
    .status(statusE),
    .cause(causeE)
);

wire regwriteW0, isexcW;

floprc #(64) m1(clk, rst, 1'b0, aluoutM, aluoutW);
floprc #(32) m2(clk, rst, 1'b0, readdataM, readdataW);
floprc #(5) m3(clk, rst, 1'b0, wregM, wregW);
floprc #(32) m4(clk, rst, 1'b0, pcM, pcW);

floprc #(1) mc1(clk, rst, 1'b0, regwriteM, regwriteW0);
floprc #(1) mc2(clk, rst, 1'b0, memtoregM, memtoregW);
floprc #(3) mc3(clk, rst, 1'b0, flagM, flagW);
floprc #(3) mc4(clk, rst, 1'b0, stallM, stallW);
floprc #(1) mc5(clk, rst, 1'b0, isexc, isexcW);

assign regwriteW = isexcW ? 1'b0 : regwriteW0;

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


//debug
assign debug_wb_pc = pcW;
assign debug_wb_rf_wen = {4{regwriteW & ~stallW}};
assign debug_wb_rf_wnum = wregW;
assign debug_wb_rf_wdata = flagW[1] ? res[63:32] : res[31:0]; //memtoregM ? readdataM: aluoutM[31:0] ;

endmodule