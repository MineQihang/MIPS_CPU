`timescale 1ns / 1ps

`include "./defines/aludefines.vh"
`include "./defines/defines2.vh"

module datapath(
    input   wire        clk, 
    input   wire        rst,
    input   wire [5:0]  ext_int,

    // instruction
    output  wire [31:0] pc,
    input   wire [31:0] inst,
    output  wire        inst_en,
    input   wire        i_stall,

    // data
    output  wire [31:0] addr,
    output  wire [31:0] writedata,
    input   wire [31:0] readdata,
    output  wire [3:0]  mem_wen,
    output  wire        mem_en,
    input   wire        d_stall,

    // stall
    output  wire        stall_all,

    //debug
    output  wire [31:0] debug_wb_pc,      
    output  wire [3:0]  debug_wb_rf_wen,
    output  wire [4:0]  debug_wb_rf_wnum, 
    output  wire [31:0] debug_wb_rf_wdata
);

///////////////////////////////Data///////////////////////////////
//============================Basic=============================//
    wire [31:0] instD, instE;
    wire        stallFD, stallDE, stallEM, stallMW;
    wire        flushFD, flushDE, flushEM, flushMW;
    wire [31:0] pcD, pcE, pcM, pcW;

//============================Control=============================//
    // alu
    wire [4:0] alucontrolD, alucontrolE;
    wire alusrcD, alusrcE;
    // regfile
    wire regdstD, regdstE;
    wire regwriteD, regwriteE, regwriteM, regwriteW;
    wire savepcD, savepcE;
    // memory
    wire memtoregD, memtoregE, memtoregM, memtoregW;
    wire memwriteD, memwriteE, memwriteM, memwriteM0;
    wire memreadD, memreadE, memreadM;
    // branch
    wire branchD, branchE, branchM;
    wire jumpD, jumpE;
    wire jrD, jrE;
    // exception
    wire instErrorD, instErrorE, instErrorM;
    wire breakD, breakE, breakM;
    wire syscallD, syscallE, syscallM;
    wire eretD, eretE, eretM;
    wire mfc0D, mtc0D, mfc0E, mtc0E, mfc0M, mtc0M;
    wire indelayslotF, indelayslotD, indelayslotE, indelayslotM;
    // data move
    wire mfhiD, mfhiE, mfloD, mfloE, mthiD, mthiE, mtloD, mtloE;

//============================Stage=============================//
    // Fetch
    wire[31:0] pc_plus4F, pc_plus4D, pc_plus4E;
    wire pc_en;
    // Decode
    wire[5:0] opD, opE, opM;
    wire[4:0] rsD, rsE;
    wire[4:0] rtD, rtE;
    wire[4:0] rdD, rdE, rdM;
    wire[4:0] saD, saE;
    wire[31:0] immD, immE, immD_sl2;
    wire[31:0] rd1D, rd2D, rd1E, rd2E;
    wire[31:0] pc_branchD, pc_branchE;
    // wire[2:0] flagD_imm, flagD, flagE, flagM, flagW;
    wire pcsrcE, pcsrcM;
    wire pcsrcPD, pcsrcPE, pcsrcPM;
    // Execute
    wire[4:0] wregE0, wregE, wregM, wregW;
    wire[1:0] forwardaE, forwardbE;
    wire[63:0] aluoutE;
    wire[31:0] aluoutM, aluoutW;
    wire[31:0] pc_jumpE, pc_pmisE, pc_pmisM;
    wire[31:0] srca, srcbt, srcbt1, srcb;
    wire div_stall;
    wire tohilo;
    wire[31:0] hi, lo;
    // Memory
    wire[31:0] writedataM;
    // wire[31:0] addr;
    wire[31:0] readdataM, readdataW;
    // Writeback
    wire[31:0] res;
    // Hazard
    wire hstallF, hstallD;
    // branch
    wire pbranchF, pbranchD;
    wire flushE;
    wire tbranch;
    wire pmisE, pmisM;
    // Exception
    wire intM;
    wire overflowE, overflowM;
    wire riM;
    wire addrErrorL, addrErrorS, pcError;
    wire[4:0] exctype;
    wire isexc;
    wire[31:0] badvaddr;
    wire[31:0] statusE, statusM, causeE, causeM;
    wire[31:0] epc;
    wire[31:0] cp0data;
    

///////////////////////////////Logic///////////////////////////////
//============================Fetch==============================//
    assign pc_en = ~(hstallF | (div_stall & ~isexc) | stall_all);
    pc #(32) u_pc(
        .clk(clk), .rst(rst), 
        // 是否转移
        .en     (pc_en), 
        // 备选pc
        .pc_seq (pc_plus4F),    // 顺序取到的pc
        .pc_jump(pc_jumpE),      // 跳转时的pc
        .pc_pmis(pc_pmisM),      // 分支预测失败时的pc
        .pc_exc (`EXC_ENTRY),   // 发生异常时的pc
        .pc_eret(epc),          // 从异常模块返回时的pc
        // 控制信号
        .jump   ((jumpE | branchE) & ~flushDE),
        .pmis   (pmisM),
        .exc    (isexc),
        .eret   (eretM),
        // 选择pc
        .des    (pc)
    );

    assign pc_plus4F = pc + 32'h4;

    assign indelayslotF = (jumpD | branchD) & ~flushDE;
    assign inst_en = 1'b1;
    
    assign stallFD = hstallD | (div_stall & ~isexc) | stall_all;
    assign flushFD = 1'b0;

    flopenrc #(32) f1(clk, rst, ~stallFD, flushFD, inst, instD);
    flopenrc #(32) f2(clk, rst, ~stallFD, flushFD, pc_plus4F, pc_plus4D);
    flopenrc #(1)  f3(clk, rst, ~stallFD, flushFD, pbranchF, pbranchD);  // clk
    flopenrc #(32) f5(clk, rst, ~stallFD, flushFD, pc, pcD);  // 分支指令的pc
    flopenrc #(1)  f6(clk, rst, ~stallFD, flushFD, indelayslotF, indelayslotD);

//============================Decode=============================//
    decoder u_decoder(
        .inst       (instD),
        // alu
        .alucontrol (alucontrolD),
        .alusrc     (alusrcD),
        // regfile
        .regdst     (regdstD),
        .regwrite   (regwriteD),
        .savepc     (savepcD),
        // memory
        .memtoreg   (memtoregD),
        .memwrite   (memwriteD),
        .memread    (memreadD),
        // branch
        .branch     (branchD),
        .jump       (jumpD),
        .jr         (jrD),
        // exception
        .instError  (instErrorD),
        .breakD     (breakD),
        .syscall    (syscallD),
        .eret       (eretD),
        .mfc0       (mfc0D),
        .mtc0       (mtc0D),
        // data move
        .mthi       (mthiD),
        .mtlo       (mtloD),
        .mfhi       (mfhiD),
        .mflo       (mfloD)
    );
    assign opD = instD[31:26];
    assign rsD = instD[25:21];
    assign rtD = instD[20:16];
    assign rdD = instD[15:11];
    assign saD = instD[10:6];

    signext u_signext(instD[15:0], opD, immD);
    sl2 u_sl2(immD, immD_sl2);

    regfile u_regfile(
        .clk(clk), .rst(rst),
        .we3(regwriteW),
        .ra1(rsD),
        .ra2(rtD),
        .wa3(wregW),
        .wd3(res),
        // .flagD(flagD_imm),
        // .flagW(flagW), 
        .rd1(rd1D), 
        .rd2(rd2D)
    );
    
    assign pc_branchD = immD_sl2 + pc_plus4D;

    assign pcsrcPD = branchD & pbranchD;

    wire flushE2;
    assign stallDE = stall_all | hstallD;
    assign flushDE = flushE2 | isexc | (hstallD & ~stall_all); 

    flopenrc #(32) d1(clk, rst, ~stallDE, flushDE, rd1D, rd1E);
    flopenrc #(32) d2(clk, rst, ~stallDE, flushDE, rd2D, rd2E);
    flopenrc #(5)  d3(clk, rst, ~stallDE, flushDE, rsD, rsE);
    flopenrc #(5)  d4(clk, rst, ~stallDE, flushDE, rtD, rtE);
    flopenrc #(5)  d5(clk, rst, ~stallDE, flushDE, rdD, rdE);
    flopenrc #(32) d6(clk, rst, ~stallDE, flushDE, immD, immE);
    flopenrc #(32) d7(clk, rst, ~stallDE, flushDE, pc_plus4D, pc_plus4E);

    flopenrc #(1)  d8(clk, rst, ~stallDE, flushDE, pcsrcPD, pcsrcPE); 
    flopenrc #(32) d11(clk, rst, ~stallDE, isexc, pcD, pcE);
    flopenrc #(5) d12(clk, rst, ~stallDE, flushDE, saD, saE);
    flopenrc #(6)  d13(clk, rst, ~stallDE, flushDE, opD, opE);
    flopenrc #(32) d15(clk, rst, ~stallDE, flushDE, instD, instE);
    flopenrc #(32) d16(clk, rst, ~stallDE, isexc, pc_branchD, pc_branchE);

    flopenrc #(1)  dc1(clk, rst, ~stallDE, flushDE, regwriteD, regwriteE);
    flopenrc #(1)  dc2(clk, rst, ~stallDE, flushDE, memtoregD, memtoregE);
    flopenrc #(1)  dc3(clk, rst, ~stallDE, flushDE, memwriteD, memwriteE);
    flopenrc #(1)  dc4(clk, rst, ~stallDE, flushDE, branchD, branchE);
    flopenrc #(5)  dc5(clk, rst, ~stallDE, flushDE, alucontrolD, alucontrolE);
    flopenrc #(1)  dc6(clk, rst, ~stallDE, flushDE, alusrcD, alusrcE);
    flopenrc #(1)  dc7(clk, rst, ~stallDE, flushDE, regdstD, regdstE);
    flopenrc #(1)  dc9(clk, rst, ~stallDE, flushDE, jumpD, jumpE);
    flopenrc #(1) dc10(clk, rst, ~stallDE, flushDE, jrD, jrE);
    flopenrc #(1) dc13(clk, rst, ~stall_all, pmisM & ~stall_all, breakD, breakE);
    flopenrc #(1) dc14(clk, rst, ~stall_all, pmisM & ~stall_all, syscallD, syscallE);
    flopenrc #(1) dc15(clk, rst, ~stall_all, pmisM & ~stall_all, eretD, eretE);
    flopenrc #(1) dc16(clk, rst, ~stallDE, flushDE, mfc0D, mfc0E);
    flopenrc #(1) dc17(clk, rst, ~stallDE, flushDE, mtc0D, mtc0E);
    flopenrc #(1) dc18(clk, rst, ~stall_all, pmisM & ~stall_all, indelayslotD, indelayslotE);
    flopenrc #(1) dc19(clk, rst, ~stallDE, flushDE, instErrorD, instErrorE);
    flopenrc #(1) dc20(clk, rst, ~stallDE, flushDE, flushE, flushE2);
    flopenrc #(1) dc21(clk, rst, ~stallDE, flushDE, savepcD, savepcE);
    flopenrc #(1) dc22(clk, rst, ~stallDE, flushDE, jrD, jrE);
    flopenrc #(1) dc23(clk, rst, ~stallDE, flushDE, memreadD, memreadE);
    flopenrc #(1) dc24(clk, rst, ~stallDE, flushDE, mthiD, mthiE);
    flopenrc #(1) dc25(clk, rst, ~stallDE, flushDE, mtloD, mtloE);
    flopenrc #(1) dc26(clk, rst, ~stallDE, flushDE, mfhiD, mfhiE);
    flopenrc #(1) dc27(clk, rst, ~stallDE, flushDE, mfloD, mfloE);

//============================Execute=============================//
    // 写回reg
    mux2 #(5) u_mux2_rd(rtE, rdE, regdstE, wregE0);
    mux2 #(5) u_mux2_rd2(wregE0, 5'b11111, savepcE, wregE);
    // alu输入1
    mux3 #(32) u_mux3_srca(rd1E, res, aluoutM, forwardaE, srca);
    // alu输入2
    mux3 #(32) u_mux3_srcb(rd2E, res, aluoutM, forwardbE, srcbt);
    mux2 #(32) u_mux2_src(srcbt, immE, alusrcE, srcbt1);
    mux2 #(32) u_mux2_srcbj(srcbt1, pcE + 8, savepcE, srcb);
    // alu
    alu u_alu(
        .clk(clk), .rst(rst), 
        .div_stall(div_stall),
        .a(srca),
        .b(srcb),
        .sa(saE),
        .op(alucontrolE), 
        .ans(aluoutE), 
        .overflow(overflowE),
        .tohilo(tohilo)
    );
    // hilo
    hilo_reg u_hiloreg(
        .clk(clk), .rst(rst),
        .we((tohilo | mthiE | mtloE) & ~isexc),
        .hi_i(mthiE ? srca : (mtloE ? hi : aluoutE[63:32])),
        .lo_i(mthiE ? lo : (mtloE ? srca : aluoutE[31:0])),
        .hi_o(hi),
        .lo_o(lo)
    );
    // branch
    assign pc_jumpE = jumpE ? (jrE ? srca : {pc_plus4E[31:28], instE[25:0], 2'b00}) : (pcsrcPE ? pc_branchE : pc_plus4E + 4);
    assign pc_pmisE = pcsrcPE ? pc_plus4E + 4 : pc_branchE;
    branchjudger u_branchjudger(srca, srcb, instE[31:26], instE[20:16], tbranch);
    assign pcsrcE = branchE & tbranch; // execute阶段判断是否预测成功
    assign pmisE = pcsrcE ^ pcsrcPE;

    assign stallEM = stall_all;
    assign flushEM = isexc;

    wire [31:0] aluoutE0;
    assign aluoutE0 = mfc0E ? cp0data : 
                      mfhiE ? hi : 
                      mfloE ? lo :
                              aluoutE[31:0];
    
    // flopenrc #(1)  e1(clk, rst, ~stallEM, flushEM, zeroE, zero);
    flopenrc #(32) e2(clk, rst, ~stallEM, 1'b0, aluoutE0, aluoutM);
    flopenrc #(32) e3(clk, rst, ~stallEM, flushEM, srcbt, writedataM);
    flopenrc #(5)  e4(clk, rst, ~stallEM, flushEM, wregE, wregM);
    flopenrc #(1)  e5(clk, rst, ~stallEM, flushEM, pcsrcE, pcsrcM); // 真正跳转
    flopenrc #(1)  e6(clk, rst, ~stallEM, flushEM, pcsrcPE, pcsrcPM); // 预测的跳转
    flopenrc #(32) e7(clk, rst, ~stallEM, 1'b0, pc_pmisE, pc_pmisM); // 预测错误时的pc
    flopenrc #(32) e8(clk, rst, ~stallEM, 1'b0, pcE, pcM); // 预测错误时的pc
    flopenrc #(6) e9(clk, rst, ~stallEM, 1'b0, opE, opM);
    flopenrc #(5) e10(clk, rst, ~stallEM, flushEM, rdE, rdM);
    flopenrc #(1) e11(clk, rst, ~stallEM, 1'b0, overflowE, overflowM);

    flopenrc #(1)   ec1(clk, rst, ~stallEM, flushEM, regwriteE, regwriteM);
    flopenrc #(1)   ec2(clk, rst, ~stallEM, flushEM, memtoregE, memtoregM);
    flopenrc #(1)   ec3(clk, rst, ~stallEM, flushEM, memwriteE, memwriteM0);
    flopenrc #(1)   ec4(clk, rst, ~stallEM, flushEM, branchE, branchM);
    // flopenrc #(3)   ec5(clk, rst, ~stallEM, flushEM, flagE, flagM);
    // flopenrc #(1)   ec6(clk, rst, ~stallEM, flushEM, stallE, stallM);
    flopenrc #(1)   ec7(clk, rst, ~stallEM, 1'b0, breakE, breakM);
    flopenrc #(1)   ec8(clk, rst, ~stallEM, 1'b0, syscallE, syscallM);
    flopenrc #(1)   ec9(clk, rst, ~stallEM, 1'b0, eretE, eretM);
    flopenrc #(1)  ec13(clk, rst, ~stallEM, 1'b0, indelayslotE, indelayslotM);
    flopenrc #(1)  ec14(clk, rst, ~stallEM, 1'b0, instErrorE, instErrorM);
    flopenrc #(1)  ec10(clk, rst, ~stallEM, flushEM, mfc0E, mfc0M);
    flopenrc #(1)  ec11(clk, rst, ~stallEM, flushEM, mtc0E, mtc0M);
    flopenrc #(32) ec12(clk, rst, ~stallEM, 1'b0, statusE, statusM);
    flopenrc #(32) ec15(clk, rst, ~stallEM, 1'b0, causeE, causeM);
    flopenrc #(1)  ec16(clk, rst, ~stallEM, 1'b0, pmisE, pmisM);
    flopenrc #(1)  ec17(clk, rst, ~stallEM, 1'b0, memreadE, memreadM);


//============================Memory=============================//
    assign addr = aluoutM;
    assign memwriteM = isexc ? 1'b0 : memwriteM0;
    assign writedata = opM == `SW ? writedataM : 
                       opM == `SH ? {2{writedataM[15:0]}} :
                       opM == `SB ? {4{writedataM[7:0]}} : 32'b0;
    assign mem_en = (memwriteM | memreadM) & ~isexc;
    assign mem_wen = memwriteM ? (opM == `SW ? 4'b1111 :
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

    assign addrErrorS = opM == `SW ? (|addr[1:0]) :
                        opM == `SH ? addr[0] : 1'b0;

    assign addrErrorL = opM == `LW ? (|addr[1:0]) :
                        opM == `LH ? addr[0] :
                        opM == `LHU ? addr[0] : 1'b0;

    assign pcError = (pcM[1:0] != 2'b00) ? 1'b1 : 1'b0;

    assign badvaddr = pcError ? pcM : 
                    (addrErrorS | addrErrorL) ? addr : 32'b0;

    // 异常与中断
    assign riM = instErrorM;
    assign intM = statusM[0] & ~statusM[1] & (
                ( |(statusM[9:8] & causeM[9:8]) ) |     //soft interupt
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

        .writedata(aluoutM),
        .readdata(cp0data),

        .epc(epc),
        .status(statusE),
        .cause(causeE)
    );

    assign stallMW = stall_all;
    assign flushMW = 1'b0;

    flopenrc #(32) m1(clk, rst, ~stallMW, flushMW, aluoutM, aluoutW);
    flopenrc #(32) m2(clk, rst, ~stallMW, flushMW, readdataM, readdataW);
    flopenrc #(5)  m3(clk, rst, ~stallMW, flushMW, wregM, wregW);
    flopenrc #(32) m4(clk, rst, ~stallMW, flushMW, pcM, pcW);

    flopenrc #(1) mc1(clk, rst, ~stallMW, flushMW, regwriteM, regwriteW);
    flopenrc #(1) mc2(clk, rst, ~stallMW, flushMW, memtoregM, memtoregW);
    // flopenrc #(3) mc3(clk, rst, ~stallMW, flushMW, flagM, flagW);

//============================Writeback=============================//
    mux2 #(32) u_mux2_readdata(aluoutW, readdataW, memtoregW, res);

//=============================Hazard==============================//
    hazard u_hazard(
        //fetch
        hstallF,
        //decode
        rsD,rtD,
        branchD,
        // forwardaD,forwardbD,
        hstallD,
        //execute
        rsE,rtE,
        wregE,
        regwriteE,
        memtoregE,
        forwardaE,forwardbE,
        //memory
        wregM,
        regwriteM,
        memtoregM,
        //writeback
        wregW,
        regwriteW
        // hilo
        // flagE, flagM, flagW
    );
    
    assign stall_all = i_stall | d_stall | div_stall;

//=========================Branch Prediction==========================//
    branchpredictor bp(
        // input
        clk, rst,
        pc, // 当前pc
        pcsrcM, // 真正的方�?
        pcsrcPM, // 预测的方�?
        pc_pmisM, // 预测错误后的pc
        pcM, // 之前的pc
        branchM, // 之前是否是分�?
        pcD, // D阶段的pc
        branchD, // D阶段的branch
        // output
        pbranchF, // 预测�?
        pmisM, // 是否预测错误
        // flushD, // 清空F->D
        flushE // 清空D->X
        // flushM // 清空X->M
    ); // 分支预测�?

//============================Debug=============================//
    assign debug_wb_pc = pcW;
    assign debug_wb_rf_wen = {4{regwriteW & ~stall_all}};
    assign debug_wb_rf_wnum = wregW;
    assign debug_wb_rf_wdata = res;

endmodule