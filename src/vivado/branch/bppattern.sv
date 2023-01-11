`timescale 1ns / 1ps

// 基于局部历史的分支预测
module bppattern # (
    parameter PHT_DEPTH = 7,  // PHT的深度
    parameter BHT_DEPTH = 3  // BHT的深度
)(
    input wire clk, rst,
    input wire [BHT_DEPTH-1:0] hashed_pcF, hashed_pcM,
    input wire [BHT_DEPTH-1:0] hashed_pc2F, hashed_pc2M,
    input wire branchM,
    input wire pcsrcM,
    output wire pcsrcPF
);

//-----------------------Data-----------------------
reg [1:0] PHT [(1<<PHT_DEPTH)-1: 0]; // PHT
reg [(PHT_DEPTH-BHT_DEPTH)-1:0] BHT [(1<<BHT_DEPTH)-1:0]; // BHT
wire [(PHT_DEPTH-BHT_DEPTH)-1:0] BHRF, BHRM;
wire [PHT_DEPTH-1:0] PHT_indexF, PHT_indexM;
wire [1:0] next_state;

integer i;


//-----------------------Logic-----------------------
// 预测
assign BHRF = BHT[hashed_pcF]; // 得到BHR
assign PHT_indexF = {hashed_pc2F, BHRF}; // 拼接得到PHT的索引
assign pcsrcPF = PHT[PHT_indexF][1]; // 局部预测结果

// 更新
assign BHRM = BHT[hashed_pcM];
assign PHT_indexM = {hashed_pc2M, BHRM};
counter2 pht_update_pattern(PHT[PHT_indexM], pcsrcM, next_state); // 计算对应PHT表项下一个状态

always @(posedge clk) begin
    // 初始化
    if(rst) begin
        for(i = 0; i < (1<<PHT_DEPTH); i = i + 1) begin
            PHT[i] <= 2'b01;
        end
        for(i = 0; i < (1<<BHT_DEPTH); i = i + 1) begin
            BHT[i] <= 0;
        end
        // PHT <= '{default: '0};
        // BHT <= '{default: '0};
    end
    // 更新
    if(branchM) begin
        BHT[hashed_pcM] <= {BHRM[(PHT_DEPTH-BHT_DEPTH)-2:0], pcsrcM}; // 更新BHT
        PHT[PHT_indexM] <= next_state; // 更新PHT
    end
end

endmodule
