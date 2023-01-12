`timescale 1ns / 1ps
`include "../defines/defines2.vh"

module cp0_reg(
	input wire clk,
	input wire rst,

	input wire en, // 是否出现异常(同样是需要写寄存器的)
	input wire enw, // 是否要写寄存器

	input wire indelayslot, // 指令是否在延迟槽内
	input wire[31:0] pc, // 指令的pc
	input wire[31:0] badvaddr, // 错误的地址

	input wire[4:0] exctype, // 异常类型
	input wire[4:0] raddr, // 读哪个CPO寄存器
	input wire[4:0] waddr, // 要写哪个寄存器

	input wire[31:0] writedata, // 要写的数据
	output reg[31:0] readdata, // 读出的寄存器的数据

	output wire[31:0] epc,
	output wire[31:0] status,
	output wire[31:0] cause
);
	reg[31:0] BadVAddr, Count, Status, Cause, Epc;

	// 写CP0数据
	always @(negedge clk ) begin
		if(rst) begin
			BadVAddr <= 32'b0;
			Count    <= 32'b0; 
			Status   <= 32'b000000000_1_0000000000000000000000;
			Cause    <= 32'b0;
			Epc      <= 32'b0;
		end else begin
			// Count寄存器计数
			Count <= Count + 1;
			// 寄存器数据写到CP0
			if(enw) begin
				case(waddr) 
					5'd8: ; // BadVAddr只读
					5'd9: Count <= writedata;
					5'd12: begin
						Status <= {Status[31:16], writedata[15:8], Status[7:2], writedata[1:0]};
						if(writedata[1] == 1'b1) Epc <= pc + 4;
					end
					5'd13: Cause <= {Cause[31:10], writedata[9:8], Cause[7:0]};
					5'd14: Epc <= writedata;
					default: ;
				endcase
			end
			// 遇到异常写CP0数据
			if(en) begin
				if(exctype == `EXC_TYPE_ERET) begin Status[1] <= 0; end
				else begin
					Status[1] <= 1;
					Cause[6:2] <= exctype;
					if(indelayslot) begin
						Epc <= pc - 4;
						Cause[31] <= 1'b1;
					end else begin
						Epc <= pc;
						Cause[31] <= 1'b0;
					end
				end
				if(exctype == `EXC_TYPE_ADEL || exctype == `EXC_TYPE_ADES) begin
					BadVAddr <= badvaddr;
				end
			end
		end
	end

	// 读CP0数据
	always @(*) begin
		if(rst) begin readdata = 32'b0; end
		case(raddr) 
			5'd8: readdata = BadVAddr;
			5'd9: readdata = Count;
			5'd12: readdata = Status;
			5'd13: readdata = Cause;
			5'd14: readdata = Epc;
			default: readdata = 32'b0;
		endcase
	end

	assign epc = Epc;
	assign status = Status;
	assign cause = Cause;
endmodule
