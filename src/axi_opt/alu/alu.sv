`timescale 1ns / 1ps

`include "../defines/aludefines.vh"

module alu(
	input wire clk, rst,
	output wire div_stall,

	input wire[31:0] a,b,
	input wire[4:0] sa,
	input wire[4:0] op,
	output wire[63:0] ans,
	output wire overflow,
	output wire tohilo
);
	wire [63:0] y;
	wire [31:0] not_div_mult;
	// always @(*) begin
	// 	case(op)
	// 		// 逻辑运算 
	// 		`ALU_AND:  y[31:0] = a & b;
	// 		`ALU_OR:   y[31:0] = a | b;
	// 		`ALU_XOR:  y[31:0] = a ^ b;
	// 		`ALU_NOR:  y[31:0] = ~(a | b);
	// 		`ALU_LUI:  y[31:0] = {b[15:0], {16{1'b0}}};
	// 		// 移位运算
	// 		`ALU_SLL:  y[31:0] = b << sa;
	// 		`ALU_SRL:  y[31:0] = b >> sa;
	// 		`ALU_SRA:  y[31:0] = $signed(b) >>> sa;
	// 		`ALU_SLLV: y[31:0] = b << a[4:0];
	// 		`ALU_SRLV: y[31:0] = b >> a[4:0];
	// 		`ALU_SRAV: y[31:0] = $signed(b) >>> a[4:0];
	// 		// 数据移动
	// 		// `ALU_MFHI: y = {a, 32'b0};
	// 		// `ALU_MFLO: y = {32'b0, a};
	// 		// `ALU_MTHI: y = {a, 32'b0};
	// 		// `ALU_MTLO: y = {32'b0, a};
	// 		// 算数运算
	// 		`ALU_ADD:  y = $signed(a) + $signed(b);
	// 		`ALU_ADDU: y = a + b;
	// 		`ALU_SUB:  y = $signed(a) - $signed(b);
	// 		`ALU_SUBU: y = a - b;
	// 		`ALU_SLT:  y = $signed(a) < $signed(b);
	// 		`ALU_SLTU: y = a < b;
	// 		// `ALU_DIV:  y = {$signed(a) % $signed(b), $signed(a) / $signed(b)};
	// 		// `ALU_DIVU: y = {a % b, a / b};
	// 		`ALU_MULT: y = $signed(a) * $signed(b);
	// 		`ALU_MULTU: y = {32'b0, a} * {32'b0, b};
	// 		`ALU_B: y = {32'b0, b};

	// 		default:  y = 64'b0;
	// 	endcase
	// end
	// 逻辑运算 
	wire [31:0] res_and = a & b;
	wire [31:0] res_or = a | b;
	wire [31:0] res_xor = a ^ b;
	wire [31:0] res_nor = ~(a | b);
	wire [31:0] res_lui = {b[15:0], {16{1'b0}}};
	
	// 移位运算
	wire [31:0] res_sll = b << sa;
	wire [31:0] res_srl = b >> sa;
	wire [31:0] res_sra = $signed(b) >>> sa;
	wire [31:0] res_sllv = b << a[4:0];
	wire [31:0] res_srlv = b >> a[4:0];
	wire [31:0] res_srav = $signed(b) >>> a[4:0];

	// 算数运算
	wire [32:0] res_add = $signed(a) + $signed(b);
	wire [31:0] res_addu = a + b;
	wire [32:0] res_sub = $signed(a) - $signed(b);
	wire [31:0] res_subu = a - b;
	wire [31:0] res_slt = {31'b0, $signed(a) < $signed(b)};
	wire [31:0] res_sltu = {31'b0, a < b};
	wire [63:0] res_mult = $signed(a) * $signed(b);
	wire [63:0] res_multu = {32'b0, a} * {32'b0, b};
	wire [31:0] res_b = b;
	
	// 合并结果
	assign not_div_mult = 
				(res_and & {32{~|(op ^ `ALU_AND)}}) | 
				(res_or  & {32{~|(op ^ `ALU_OR)}}) | 
				(res_xor & {32{~|(op ^ `ALU_XOR)}}) | 
				(res_nor & {32{~|(op ^ `ALU_NOR)}}) | 
				(res_lui & {32{~|(op ^ `ALU_LUI)}}) | 

				(res_sll & {32{~|(op ^ `ALU_SLL)}}) | 
				(res_srl & {32{~|(op ^ `ALU_SRL)}}) | 
				(res_sra & {32{~|(op ^ `ALU_SRA)}}) | 
				(res_sllv & {32{~|(op ^ `ALU_SLLV)}}) | 
				(res_srlv & {32{~|(op ^ `ALU_SRLV)}}) | 
				(res_srav & {32{~|(op ^ `ALU_SRAV)}}) | 

				(res_add[31:0] & {32{~|(op ^ `ALU_ADD)}}) | 
				(res_addu & {32{~|(op ^ `ALU_ADDU)}}) | 
				(res_sub[31:0] & {32{~|(op ^ `ALU_SUB)}}) | 
				(res_subu & {32{~|(op ^ `ALU_SUBU)}}) | 
				(res_slt & {32{~|(op ^ `ALU_SLT)}}) | 
				(res_sltu & {32{~|(op ^ `ALU_SLTU)}}) | 
				(res_b & {32{~|(op ^ `ALU_B)}});

	wire div_valid = (op == `ALU_DIV || op == `ALU_DIVU) ? 1'b1 : 1'b0;
	wire mult_valid = (op == `ALU_MULT || op == `ALU_MULTU) ? 1'b1 : 1'b0;
	assign tohilo = div_valid | mult_valid;

	wire signed_div = (op == `ALU_DIV) ? 1'b1 : 1'b0;
	wire ready;
	wire start = div_valid & (~ready);
	wire annul = 1'b0;
	wire[63:0] div_ans;

	div u_div(
		.clk(clk),
		.rst(rst),
		.signed_div_i(signed_div),
		.a(a),
		.b(b),
		.start_i(start),
		.annul_i(annul),
		.result_o(div_ans),
		.ready_o(ready)
	);

	assign div_stall = start;

	assign y = {32'b0, not_div_mult & {32{~div_valid & ~mult_valid}}} |
				(res_mult & {64{~|(op ^ `ALU_MULT)}}) | 
				(res_multu & {64{~|(op ^ `ALU_MULTU)}});
	assign ans = div_valid ? div_ans : y;

	assign overflow = (~|(op ^ `ALU_ADD) & (res_add[32] ^ res_add[31])) | (~|(op ^ `ALU_SUB) & (res_sub[32] ^ res_sub[31]));
endmodule