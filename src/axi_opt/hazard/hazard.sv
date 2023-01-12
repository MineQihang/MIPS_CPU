`timescale 1ns / 1ps

module hazard(
	//fetch
	output wire stallFD, flushFD,
	//decode
	input wire[4:0] rsD,rtD,
	input wire branchD,
	output wire[1:0] forwardaD,forwardbD,
	output wire stallDE, flushDE,
	//execute
	input wire[4:0] rsE,rtE,
	input wire[4:0] writeregE,
	input wire regwriteE,
	input wire memtoregE,
	output wire[1:0] forwardaE,forwardbE,
	output wire stallEM, flushEM,
	//memory
	input wire[4:0] writeregM,
	input wire regwriteM,
	input wire memtoregM,
	output wire stallMW, flushMW,
	//writeback
	input wire[4:0] writeregW,
	input wire regwriteW,
	//input
	input wire stall_all, isexc, pmisM, div_stall
);

// 数据前推到EX阶段
// assign forwardaE = (rsE == 0) ? 2'b00 :
//                    (rsE == writeregM & regwriteM) ? 2'b10 : // rs数据在Memory阶段
//                    (rsE == writeregW & regwriteW) ? 2'b01 : // rs数据在Writeback阶段
//                    2'b00;
// assign forwardbE = (rtE == 0) ? 2'b00 :
//                    (rtE == writeregM & regwriteM) ? 2'b10 : // rt数据在Memory阶段
//                    (rtE == writeregW & regwriteW) ? 2'b01 : // rt数据在Writeback阶段
//                    2'b00;


// 访存冲突
wire lwstallD;
assign lwstallD = memtoregE & // 是否写入
			      (rsD != 0 | rsE != 0) &
                  (rtE == rsD | rtE == rtD); // 判断decode阶段rs或rt的地址是否是lw指令要写入的地址

// branch跳转
// wire branchstallD;
// assign branchstallD = branchD & // 是否跳转
//                       (regwriteE & // 是否写入寄存器堆
//                       (writeregE == rsD | writeregE == rtD) | // (1)Decode阶段写入
//                        memtoregM & // (2)写入Data Memory
//                       (writeregM == rsD | writeregM == rtD)); // (3)Memory阶段写入

// 数据前推到ID
assign forwardaD = (rsD == 0) ? 2'b00 :
                   (rsD == writeregE & regwriteE) ? 2'b01 : // rs数据在Execute阶段
                   (rsD == writeregM & regwriteM) ? 2'b10 : // rs数据在Memory阶段
                   2'b00;
assign forwardbD = (rtD == 0) ? 2'b00 :
                   (rtD == writeregE & regwriteE) ? 2'b01 : // rt数据在Execute阶段
                   (rtD == writeregM & regwriteM) ? 2'b10 : // rt数据在Memory阶段
                   2'b00;

assign stallFD = lwstallD | (div_stall & ~isexc) | stall_all;
assign flushFD = 1'b0;

assign stallDE = stall_all | lwstallD;
assign flushDE = isexc | ((lwstallD | pmisM) & ~stall_all); //flushE |  | flushE2; 

assign stallEM = stall_all;
assign flushEM = isexc & ~stall_all;

assign stallMW = stall_all;
assign flushMW = 1'b0;

endmodule