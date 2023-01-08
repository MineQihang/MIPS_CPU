`timescale 1ns / 1ps

// 基于全局历史的分支预测
module bpglobal # (
    parameter PHT_DEPTH = 7, // PHT的深度
    parameter GHR_WIDTH = 4  // BHT的宽度
)(
    input wire clk, rst,
    input wire [(PHT_DEPTH-GHR_WIDTH)-1:0] hashed_pcF, hashed_pcM,
    input wire branchD,
    input wire branchM,
    input wire pcsrcM,
    input wire pcsrcPM,
    input wire flushE,
    input wire flushM,
    
    output wire pcsrcPF,
    output wire [PHT_DEPTH-1:0] PHT_indexF, PHT_indexM
);

//-----------------------Data-----------------------
reg [GHR_WIDTH-1:0] GHR, GHR_E, GHR_Retired, GHR2_D, GHR2_E, GHR2;
reg [1:0] PHT [(1<<PHT_DEPTH)-1:0];
// wire [PHT_DEPTH-1:0] PHT_indexF, PHT_indexM;

integer i;


//-----------------------Logic-----------------------
// 预测
assign PHT_indexF = {hashed_pcF, GHR};
assign pcsrcPF = PHT[PHT_indexF][1];

assign PHT_indexM = {hashed_pcM, GHR_Retired};
wire [1:0] next_state;
counter2 pht_update_global(PHT[PHT_indexM], pcsrcM, next_state); // 计算对应PHT表项下一个状态

always @(posedge clk) begin
    // 初始化
    if(rst) begin
        GHR <= 0; GHR_E <= 0; GHR_Retired <= 0; GHR2_D <= 0; GHR2_E <= 0; GHR2 <= 0;
        for(i = 0; i < (1<<PHT_DEPTH); i = i + 1) begin
            PHT[i] <= 2'b01;
        end
    end
    // 更新
    if(branchD) begin // Decode阶段更新
        GHR <= {GHR[GHR_WIDTH-2:0], pcsrcPF}; // 预测
        GHR2_D <= {GHR[GHR_WIDTH-2:0], ~pcsrcPF}; // 预测相反方向
    end
    // GHR传播
    if(!flushE) begin
        GHR_E <= GHR;
        GHR2_E <= GHR2_D;
    end
    if(!flushM) begin
        GHR_Retired <= GHR_E;
        GHR2 <= GHR2_E;
    end
    // 更新
    if(branchM) begin
        PHT[PHT_indexM] <= next_state; // 更新PHT
        // 预测错误
        if(pcsrcPM ^ pcsrcM) begin
            GHR <= GHR2; // checkpoint替换法
        end
    end
end


endmodule
