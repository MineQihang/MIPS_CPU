`timescale 1ns / 1ps

module branchpredictor(
    input wire clk, rst,
    input wire [31:0] pc, // 当前pc
    input wire pcsrcM, // 真正的方向
    input wire pcsrcPM, // 预测的方向
    input wire [31:0] fpcM, // 预测错误后的pc
    input wire [31:0] pcM, // 之前的pc
    input wire branchM, // 之前那条指令是否是分支指令
    input wire [31:0] pcD, // D阶段的pc
    input wire branchD, // D阶段的branch

    output wire pcsrcPF, // 预测值
    output wire pmis, // 是否预测错误
    output wire flushD, // 清空F->D
    output wire flushE, // 清空D->X
    output wire flushM // 清空X->M
);
//-----------------------Data-----------------------
parameter PHT_DEPTH = 7; // PHT深度
parameter BHT_DEPTH = 3; // BHT深度
parameter BHR_WIDTH = PHT_DEPTH - BHT_DEPTH; // BHR宽度
parameter GHR_WIDTH = 4; // GHR宽度

reg [1:0] CPHT [(1<<PHT_DEPTH)-1:0]; // Choice PHT
wire [BHT_DEPTH-1:0] hashed_pcF, hashed_pcM, hashed_pc2F, hashed_pc2M; // 哈希后的pc
wire [PHT_DEPTH-1:0] CPHT_indexF, CPHT_indexM; // CPHT的索引
wire choice; // 选择使用哪一个分支预测
wire pmis_pattern; // 局部分支预测是否错误
wire pmis_global; // 全局分支预测是否错误

wire pcsrcPF_pattern, pcsrcPF_global; // 预测结果传播(fetch)
wire pcsrcPD_pattern, pcsrcPD_global; // 预测结果传播(decode)
wire pcsrcPE_pattern, pcsrcPE_global; // 预测结果传播(execution)
wire pcsrcPM_pattern, pcsrcPM_global; // 预测结果传播(memory)

integer i; // 循环初始化用


//-----------------------Logic-----------------------
// 初始化
always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
            // CPHT[i] <= 2'b01;
        end
    end
end

// 哈希pc
assign hashed_pcF = pc[30:28];  // F阶段的pc
assign hashed_pcM = pcM[30:28];  // M阶段的pc
assign hashed_pc2F = pc[4:2];  // F阶段的pc(取后3位)
assign hashed_pc2M = pcM[4:2];  // M阶段的pc(取后3位)

// 预测
/// P1: 全局
bpglobal #(PHT_DEPTH, GHR_WIDTH) p1(
    // input
    clk, rst,
    hashed_pcF, hashed_pcM, 
    branchD,
    branchM,
    pcsrcM,
    pcsrcPM,
    flushE,
    flushM,
    // output
    pcsrcPF_global,
    CPHT_indexF,
    CPHT_indexM
);

/// P2: 局部
bppattern #(PHT_DEPTH, BHT_DEPTH) p2(
    //input
    clk, rst,
    hashed_pcF, hashed_pcM,
    hashed_pc2F, hashed_pc2M,
    branchM,
    pcsrcM,
    // output
    pcsrcPF_pattern
);

// 选择哪种预测方法
assign choice = CPHT[CPHT_indexF][1]; // CPHT[CPHT_indexF][1];
assign pcsrcPF = 1'b1; // (choice ? pcsrcPF_pattern : pcsrcPF_global); // 0->全局, 1->局部

// 预测结果传播
floprc #(1) fd1(clk, rst, flushD, pcsrcPF_pattern, pcsrcPD_pattern);
floprc #(1) de1(clk, rst, flushE, pcsrcPD_pattern, pcsrcPE_pattern);
floprc #(1) em1(clk, rst, flushM, pcsrcPE_pattern, pcsrcPM_pattern);

floprc #(1) fd2(clk, rst, flushD, pcsrcPF_global, pcsrcPD_global);
floprc #(1) de2(clk, rst, flushE, pcsrcPD_global, pcsrcPE_global);
floprc #(1) em2(clk, rst, flushM, pcsrcPE_global, pcsrcPM_global);

// 更新CPHT
assign pmis_pattern = pcsrcPM_pattern ^ pcsrcPM; // 局部预测是否成功
assign pmis_global = pcsrcPM_global ^ pcsrcPM; // 全局预测是否成功
always @(posedge clk) begin
    if(branchM) begin // 分支指令才更新
        case({pmis_global, pmis_pattern}) // (P1, P2)
            2'b10: // P1预测错误
                case(CPHT[CPHT_indexM])
                    2'b11: ; // 选择P2的饱和态
                    default: CPHT[CPHT_indexM] <= CPHT[CPHT_indexM] + 1;
                endcase
            2'b01: // P2预测错误
                case(CPHT[CPHT_indexM])
                    2'b00: ; // 选择P1的饱和态
                    default: CPHT[CPHT_indexM] <= CPHT[CPHT_indexM] - 1;
                endcase
            default: ;
        endcase
    end
end

// 是否预测失败
assign pmis = pcsrcM ^ pcsrcPM;

// 预测失败flush掉数据
assign flushD = 1'b0;
assign flushE = pmis;
assign flushM = pmis;

endmodule
