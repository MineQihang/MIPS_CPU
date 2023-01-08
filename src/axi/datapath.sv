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
    //new1
    output wire mem_enM,
    output wire stall_all,
    input wire i_stall,
    input wire d_stall,
    output wire inst_en,
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
wire jr, jalr, jumpE, jrE, jalrE, jal, jalE;
// execute
wire zeroE, flushM, pcsrcPE, pbranchE, tbranch, stallM;
wire[31:0] srca, srcbt, srcbt1, srcb, write, writedataM;
wire[63:0] aluoutE, aluoutM;
wire[1:0] forwardaE, forwardbE;
wire[31:0] instrE;
wire tflushE;
wire div_stall, div_stallM;
// memory
wire[63:0] aluoutW;
wire[31:0] readdataW;
wire pcsrcPM, pcsrcM;  // new1
wire[31:0] instrM;
wire[31:0] readdataM;
wire[5:0] opM;
wire stallW;
wire tflushM;
// 中断与异�?
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

wire flushE_stallD ;

// c0
wire mfc0D, mtc0D, mfc0E, mtc0E, mfc0M, mtc0M;

// -------------------------logic------------------------------
// pc transfer new1
pc #(32) u_pc(clk, rst, ~(stallF | (div_stall & ~isexc) | stall_all), pc_plus4F, tmp_pc1);

mux2 #(32) u_mux_pcbr1(pc_plus4D, pc_branchD, pcsrcPD, tmp_pc2D);
mux2 #(32) u_mux_pcf(pc_plus4D + 4, pc_branchD, ~pcsrcPD, fpcD);  // 预测失败时的pc

assign jr = alucontrol == `ALU_JR;
assign jalr = alucontrol == `ALU_JALR;
assign jal = op == `JAL;
mux2 #(32) u_mux_jump({pc_plus4E[31:28], instrE[25:0], 2'b00}, srca, jrE | jalrE, tmp_pc3);

mux2 #(32) u_mux_pc(tmp_pc1, tmp_pc3, (jumpE | jrE | jalrE) & ~tflushE, tmp_pc4); // jump

mux2 #(32) u_mux_branch(tmp_pc4, tmp_pc2E, (branchE & ~tflushE), tmp_pc5);  // 是否分支

mux2 #(32) u_mux_pcbr2(tmp_pc5, fpcM, pmis, tmp_pc6); // 失败的pc

mux2 #(32) u_mux_pc2(tmp_pc6, `EXC_ENTRY, isexc, nxt_pc); // 异常
mux2 #(32) u_mux_pc3(nxt_pc, epc, eretM, pc); // ERET

// ========================Fetch========================
adder pc_adder4(pc, 32'h4, pc_plus4F);
assign indelayslotF = (jump | jr | jalr | branch) & ~tflushE;
wire tflushD = flushD;
assign inst_en = 1'b1;

// new1
flopenrc #(32) f1(clk, rst, ~(stallD | (div_stall & ~isexc) | stall_all), tflushD, instr, instrD);
flopenrc #(32) f2(clk, rst, ~(stallD | (div_stall & ~isexc) | stall_all), tflushD, pc_plus4F, pc_plus4D);
flopenrc #(1)  f3(clk, rst, ~(stallD | (div_stall & ~isexc) | stall_all), tflushD, pbranchF, pbranchD);  // clk
flopenrc #(32) f5(clk, rst, ~(stallD | (div_stall & ~isexc) | stall_all), tflushD, pc, pcD);  // 分支指令的pc
flopenrc #(1)  f6(clk, rst, ~(stallD | (div_stall & ~isexc) | stall_all), tflushD, indelayslotF, indelayslotD);


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

// 中断与异常判�?
assign breakD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001101);
assign syscallD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001100);
assign eretD = (instrD == 32'b01000010000000000000000000011000);

// c0
assign mfc0D = (instrD[31:26] == `SPECIAL3_INST && instrD[25:21] == `MFC0) ? 1'b1 : 1'b0;
assign mtc0D = (instrD[31:26] == `SPECIAL3_INST && instrD[25:21] == `MTC0) ? 1'b1 : 1'b0;

// 执行预测结果 TODO[2]
// new1
assign flushE_stallD = stallD & ~stall_all;
wire flushE2;
assign tflushE = flushE2 | isexc |flushE_stallD; 
// new1
flopenrc #(32) d1(clk, rst, ~stall_all & ~stallD, tflushE, rd1D, rd1E);
flopenrc #(32) d2(clk, rst, ~stall_all & ~stallD, tflushE, rd2D, rd2E);
flopenrc #(5)  d3(clk, rst, ~stall_all & ~stallD, tflushE, rsD, rsE);
flopenrc #(5)  d4(clk, rst, ~stall_all & ~stallD, tflushE, rtD, rtE);
flopenrc #(5)  d5(clk, rst, ~stall_all & ~stallD, tflushE, rdD, rdE);
flopenrc #(32) d6(clk, rst, ~stall_all & ~stallD, tflushE, immD, immE);
flopenrc #(32) d7(clk, rst, ~stall_all & ~stallD, tflushE, pc_plus4D, pc_plus4E);
flopenrc #(1)  d8(clk, rst, ~stall_all & ~stallD, tflushE, pcsrcPD, pcsrcPE); 
flopenrc #(1)  d9(clk, rst, ~stall_all & ~stallD, tflushE, pbranchD, pbranchE);
flopenrc #(32) d10(clk, rst, ~stall_all & ~stallD, isexc, fpcD, fpcE); // 预测错误时的pc
flopenrc #(32) d11(clk, rst, ~stall_all & ~stallD, isexc, pcD, pcE); // 预测错误时的pc
flopenrc #(5) d12(clk, rst, ~stall_all & ~stallD, tflushE, saD, saE); // 预测错误时的pct
flopenrc #(6)  d13(clk, rst, ~stall_all & ~stallD, tflushE, op, opE); // 预测错误时的pct
flopenrc #(5)  d14(clk, rst, ~stall_all & ~stallD, tflushE, rtD0, rtE0);
flopenrc #(32) d15(clk, rst, ~stall_all & ~stallD, tflushE, instrD, instrE);
flopenrc #(32) d16(clk, rst, ~stall_all & ~stallD, tflushE, pc_branchD, pc_branchE);
flopenrc #(32) d17(clk, rst, ~stall_all & ~stallD, tflushE, tmp_pc2D, tmp_pc2E);

flopenrc #(1)  dc1(clk, rst, ~stall_all & ~stallD, tflushE, regwriteD, regwriteE);
flopenrc #(1)  dc2(clk, rst, ~stall_all & ~stallD, tflushE, memtoreg, memtoregE);
flopenrc #(1)  dc3(clk, rst, ~stall_all & ~stallD, tflushE, memwriteD, memwriteE);
flopenrc #(1)  dc4(clk, rst, ~stall_all & ~stallD, tflushE, branch, branchE);
flopenrc #(5)  dc5(clk, rst, ~stall_all & ~stallD, tflushE, alucontrol, alucontrolE);
flopenrc #(1)  dc6(clk, rst, ~stall_all & ~stallD, tflushE, alusrc, alusrcE);
flopenrc #(1)  dc7(clk, rst, ~stall_all & ~stallD, tflushE, regdst, regdstE);
flopenrc #(3)  dc8(clk, rst, ~stall_all & ~stallD, tflushE, flagD, flagE);
flopenrc #(1)  dc9(clk, rst, ~stall_all & ~stallD, tflushE, jump, jumpE);
flopenrc #(1) dc10(clk, rst, ~stall_all & ~stallD, tflushE, jr, jrE);
flopenrc #(1) dc11(clk, rst, ~stall_all & ~stallD, tflushE, jalr, jalrE);
flopenrc #(1) dc12(clk, rst, ~stall_all & ~stallD, tflushE, jal, jalE);
flopenrc   #(1) dc13(clk, rst, ~stall_all, isexc, breakD, breakE);
flopenrc   #(1) dc14(clk, rst, ~stall_all, isexc, syscallD, syscallE);
flopenrc   #(1) dc15(clk, rst, ~stall_all, isexc, eretD, eretE);
flopenrc #(1) dc16(clk, rst, ~stall_all & ~stallD, tflushE, mfc0D, mfc0E);
flopenrc #(1) dc17(clk, rst, ~stall_all & ~stallD, tflushE, mtc0D, mtc0E);
flopenrc   #(1) dc18(clk, rst, ~stall_all, isexc, indelayslotD, indelayslotE);
flopenrc #(1) dc19(clk, rst, ~stall_all & ~stallD, tflushE, instrErrorD, instrErrorE);

flopenrc #(1) dc20(clk, rst, ~stall_all & ~stallD, tflushE, flushE, flushE2);

// ========================Execute========================
mux2 #(5) u_mux2_rd(rtE, rdE, regdstE, wregE);
mux3 #(32) u_mux3_srca(rd1E, (~flagE[2] & flagE[1]) | (~flagW[0] & flagW[1]) ? res[63:32] : res[31:0], (~flagE[2] & flagE[1]) | (~flagM[0] & flagM[1]) ? aluoutM[63:32] : aluoutM[31:0], forwardaE, srca);
mux3 #(32) u_mux3_srcb(rd2E, (~flagE[2] & flagE[1]) | (~flagW[0] & flagW[1]) ? res[63:32] : res[31:0], (~flagE[2] & flagE[1]) | (~flagM[0] & flagM[1]) ? aluoutM[63:32] : aluoutM[31:0], forwardbE, srcbt);
mux2 #(32) u_mux2_src(srcbt, immE, alusrcE, srcbt1);
mux2 #(32) u_mux2_srcbj(srcbt1, pcE + 8, jalrE | jalE, srcb);
alu u_alu(clk, rst, div_stall,
  srca, srcb, saE, alucontrolE, aluoutE, overflow, zeroE);

branchjudger u_branchjudger(srca, srcb, opE, rtE0, tbranch);
assign pcsrcE = branchE & tbranch; // execute阶段判断是否预测成功

// 判断是否预测成功 TODO[3]
assign tflushM = isexc;
// new1
flopenrc #(1)  e1(clk, rst, ~stall_all, tflushM, zeroE, zero);
flopenrc #(64) e2(clk, rst, ~stall_all, 1'b0, mtc0E ? {32'b0, srcb} : (mfc0E ? {32'b0, cp0data} : aluoutE), aluoutM);
flopenrc #(32) e3(clk, rst, ~stall_all, tflushM, srcbt, writedataM);
flopenrc #(5)  e4(clk, rst, ~stall_all, tflushM, wregE, wregM);
flopenrc #(1)  e5(clk, rst, ~stall_all, tflushM, pcsrcE, pcsrcM); // 真正的跳�?
flopenrc #(1)  e6(clk, rst, ~stall_all, tflushM, pcsrcPE, pcsrcPM); // 预测的跳�?
flopenrc #(32) e7(clk, rst, ~stall_all, 1'b0, fpcE, fpcM); // 预测错误时的pc
flopenrc #(32) e8(clk, rst, ~stall_all, 1'b0, pcE, pcM); // 预测错误时的pc
flopenrc #(32) e9(clk, rst, ~stall_all, 1'b0, instrE, instrM);
flopenrc #(5) e10(clk, rst, ~stall_all, tflushM, rdE, rdM);
flopenrc #(1) e11(clk, rst, ~stall_all, 1'b0, overflow, overflowM);

flopenrc #(1)   ec1(clk, rst, ~stall_all, tflushM, regwriteE, regwriteM);
flopenrc #(1)   ec2(clk, rst, ~stall_all, tflushM, memtoregE, memtoregM);
flopenrc #(1)   ec3(clk, rst, ~stall_all, tflushM, memwriteE, memwriteM0);
flopenrc #(1)   ec4(clk, rst, ~stall_all, tflushM, branchE, branchM);
flopenrc #(3)   ec5(clk, rst, ~stall_all, tflushM, flagE, flagM);
// flopenrc #(1)   ec6(clk, rst, ~stall_all, tflushM, stallE, stallM);
flopenrc #(1)   ec7(clk, rst, ~stall_all, 1'b0, breakE, breakM);
flopenrc #(1)   ec8(clk, rst, ~stall_all, 1'b0, syscallE, syscallM);
flopenrc #(1)   ec9(clk, rst, ~stall_all, 1'b0, eretE, eretM);
flopenrc #(1)  ec10(clk, rst, ~stall_all, tflushM, mfc0E, mfc0M);
flopenrc #(1)  ec11(clk, rst, ~stall_all, tflushM, mtc0E, mtc0M);
flopenrc #(32) ec12(clk, rst, ~stall_all, 1'b0, statusE, statusM);
flopenrc #(1)  ec13(clk, rst, ~stall_all, 1'b0, indelayslotE, indelayslotM);
flopenrc #(1)  ec14(clk, rst, ~stall_all, 1'b0, instrErrorE, instrErrorM);
flopenrc #(32) ec15(clk, rst, ~stall_all, 1'b0, causeE, causeM);


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

//new1
assign mem_enM = (memwriteM | (opM == `LW || opM == `LH || opM == `LHU || opM == `LB || opM == `LBU) ? 1'b1 : 1'b0) & ~isexc;

// new1
flopenrc #(64) m1(clk, rst, ~stall_all, 1'b0, aluoutM, aluoutW);
flopenrc #(32) m2(clk, rst, ~stall_all, 1'b0, readdataM, readdataW);
flopenrc #(5)  m3(clk, rst, ~stall_all, 1'b0, wregM, wregW);
flopenrc #(32) m4(clk, rst, ~stall_all, 1'b0, pcM, pcW);

flopenrc #(1) mc1(clk, rst, ~stall_all, 1'b0, regwriteM, regwriteW0);
flopenrc #(1) mc2(clk, rst, ~stall_all, 1'b0, memtoregM, memtoregW);
flopenrc #(3) mc3(clk, rst, ~stall_all, 1'b0, flagM, flagW);
// flopenrc #(3) mc4(clk, rst, ~stall_all, 1'b0, stallM, stallW);
floprc #(1) mc5(clk, rst, 1'b0, isexc, isexcW);

assign regwriteW = regwriteW0; //  isexcW ? 1'b0 : 

// ========================Writeback========================
assign stallW = 1'b0;

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
    // flushM, // [1]新增flushM, 因为是在Memory阶段才处理错误，这时错误可能已经传到Execution到Memory阶段的寄存器中，�?以需要清�?
    //writeback
    wregW,
    regwriteW,
    // hilo
    flagE, flagM, flagW
);
// new1
assign stall_all = i_stall | d_stall | div_stall;

// 分支预测 TODO[1]
branchpredictor bp(
    // input
    clk, rst,
    pc, // 当前pc
    pcsrcM, // 真正的方�?
    pcsrcPM, // 预测的方�?
    fpcM, // 预测错误后的pc
    pcM, // 之前的pc
    branchM, // 之前是否是分�?
    pcD, // D阶段的pc
    branch, // D阶段的branch
    // output
    pbranchF, // 预测�?
    pmis, // 是否预测错误
    flushD, // 清空F->D
    flushE, // 清空D->X
    flushM // 清空X->M
); // 分支预测�?


//debug
assign debug_wb_pc = pcW;
assign debug_wb_rf_wen = {4{regwriteW & ~stallW & ~stall_all}};
assign debug_wb_rf_wnum = wregW;
assign debug_wb_rf_wdata = flagW[1] ? res[63:32] : res[31:0]; //memtoregM ? readdataM: aluoutM[31:0] ;

endmodule