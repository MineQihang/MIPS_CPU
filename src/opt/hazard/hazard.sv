`timescale 1ns / 1ps

module hazard(
	//fetch
	output wire stallF,
	//decode
	input wire[4:0] rsD,rtD,
	input wire branchD,
	output wire[1:0] forwardaD,forwardbD,
	output wire stallD,
	//execute
	input wire[4:0] rsE,rtE,
	input wire[4:0] writeregE,
	input wire regwriteE,
	input wire memtoregE,
	output wire[1:0] forwardaE,forwardbE,
	// output wire flushE,
	//memory
	input wire[4:0] writeregM,
	input wire regwriteM,
	input wire memtoregM,
	// output wire flushM,
	//writeback
	input wire[4:0] writeregW,
	input wire regwriteW
	//hilo
	// input wire hilowriteE, 
	// input wire hireadD, 
	// input wire loreadD
);

// 数据冒险(and, or, sub ...) -> 数据前推
assign forwardaE = (rsE == 0) ? 2'b00 :
                   (rsE == writeregM & regwriteM) ? 2'b10 : // rs数据在Memory阶段
                   (rsE == writeregW & regwriteW) ? 2'b01 : // rs数据在Writeback阶段
                   2'b00;
assign forwardbE = (rtE == 0) ? 2'b00 :
                   (rtE == writeregM & regwriteM) ? 2'b10 : // rt数据在Memory阶段
                   (rtE == writeregW & regwriteW) ? 2'b01 : // rt数据在Writeback阶段
                   2'b00;


// 数据冒险(lw, beq) -> 流水线暂停
// lw 访存冲突
wire lwstallD;
assign lwstallD = memtoregE & // 是否写入
			      (rsD != 0 | rsE != 0) &
                  (rtE == rsD | rtE == rtD); // 判断decode阶段rs或rt的地址是否是lw指令要写入的地址
// branch
// wire branchstallD;
// assign branchstallD = branchD & // 是否跳转
//                       (regwriteE & // 是否写入寄存器堆
//                       (writeregE == rsD | writeregE == rtD) | // (1)Decode阶段写入
//                        memtoregM & // (2)写入Data Memory
//                       (writeregM == rsD | writeregM == rtD)); // (3)Memory阶段写入
// merge
assign stallD = lwstallD; // | branchstallD;
assign stallF = stallD; // Fetch, Decode阶段暂停
// assign flushE = stallD; // 对Execute阶段的数据进行刷新
// assign flushM = 1'b0; // 对Memory阶段的数据进行刷新

// 控制冒险 + 数据冒险(beq) -> 数据前推 
assign forwardaD = (rsD == 0) ? 2'b00 :
                   (rsD == writeregE & regwriteE) ? 2'b01 : // rs数据在Execute阶段
                   (rsD == writeregM & regwriteM) ? 2'b10 : // rs数据在Memory阶段
                   2'b00;
assign forwardbD = (rtD == 0) ? 2'b00 :
                   (rtD == writeregE & regwriteE) ? 2'b01 : // rt数据在Execute阶段
                   (rtD == writeregM & regwriteM) ? 2'b10 : // rt数据在Memory阶段
                   2'b00;


endmodule