`timescale 1ns / 1ps

`include "./utils/aludefines.vh"

module alu(
	input wire[31:0] a,b,
	input wire[4:0] sa,
	input wire[4:0] op,
	output reg[63:0] y,
	output reg overflow,
	output wire zero
);
	always @(*) begin
		case(op)
			// 逻辑运算 
			`ALU_AND:  y <= a & b;
			`ALU_OR:   y <= a | b;
			`ALU_XOR:  y <= a ^ b;
			`ALU_NOR:  y <= ~(a | b);
			`ALU_LUI:  y <= {b[15:0], {16{1'b0}}};
			// 移位运算
			`ALU_SLL:  y <= b << sa;
			`ALU_SRL:  y <= b >> sa;
			`ALU_SRA:  y <= $signed(b) >>> sa;
			`ALU_SLLV: y <= b << a;
			`ALU_SRLV: y <= b >> a;
			`ALU_SRAV: y <= $signed(b) >>> a;
			// 数据移动
			`ALU_MFHI: y <= a;
			`ALU_MFLO: y <= a;
			`ALU_MTHI: y <= a;
			`ALU_MTLO: y <= a;
			// 算数运算
			`ALU_ADD:  y <= a + b;
			`ALU_ADDU: y <= a + b;
			`ALU_SUB:  y <= a - b;
			`ALU_SUBU: y <= a - b;
			`ALU_SLT:  y <= $signed(a) < $signed(b);
			`ALU_SLTU: y <= a < b;
			`ALU_DIV:  y <= {$signed(a) % $signed(b), $signed(a) / $signed(b)};
			`ALU_DIVU: y <= {a % b, a / b};
			`ALU_MULT: y <= $signed(a) * $signed(b);
			`ALU_MULTU: y <= {32'b0, a} * {32'b0, b};
			`ALU_DONOTHING: y <= {32'b0, b};
			`ALU_JR: y <= {32'b0, b};
			`ALU_JALR: y <= {32'b0, b};

			default:  y <= 64'b0;
		endcase
	end
endmodule


/*
	wire[31:0] s,bout;
	assign bout = op[3] ? ~b : b;
	assign s = a + bout + op[3];
	always @(*) begin
		case (op[1:0])
			2'b00: y <= a & bout;
			2'b01: y <= a | bout;
			2'b10: y <= s;
			2'b11: y <= s[31];

			default : y <= 32'b0;
		endcase	
	end
	assign zero = (y == 32'b0);

	always @(*) begin
		case (op[3:2])
			2'b01:overflow <= a[31] & b[31] & ~s[31] |
							~a[31] & ~b[31] & s[31];
			2'b11:overflow <= ~a[31] & b[31] & s[31] |
							a[31] & ~b[31] & ~s[31];
			default : overflow <= 1'b0;
		endcase	
	end
*/