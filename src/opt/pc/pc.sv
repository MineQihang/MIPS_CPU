`timescale 1ns / 1ps

module pc #(parameter WIDTH = 32)(
	input	wire clk,rst,en,
	// 备选
	input	wire [WIDTH-1:0]	pc_seq,
	input	wire [WIDTH-1:0]	pc_jump,
	input	wire [WIDTH-1:0]	pc_pmis,
	input	wire [WIDTH-1:0]	pc_exc,
	input	wire [WIDTH-1:0]	pc_eret,
	// 控制信号
	input	wire				jump,
	input	wire				pmis,
	input	wire				exc,
	input	wire				eret,
	// 选择
	output	reg  [WIDTH-1:0] 	des
);
	reg [31:0] nxt_pc;

	always @(posedge clk, posedge rst) begin
		if(rst) begin
			des <= 32'hbfc00000;
		end else if(en) begin
			des <= nxt_pc;
		end
	end

	assign nxt_pc = eret ? pc_eret : 
				    exc  ? pc_exc  : 
				    pmis ? pc_pmis :
				    jump ? pc_jump : 
					       pc_seq;
endmodule