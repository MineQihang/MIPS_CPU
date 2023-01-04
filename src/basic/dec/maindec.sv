`timescale 1ns / 1ps

`include "../utils/defines2.vh"

module maindec(
    input  wire[31:0] instrD,
    output wire memtoreg, branch, alusrc, regdst, regwrite, jump,
    output wire memwrite,
    output reg instrError
);

wire[5:0] op;
wire[4:0] rs;
wire[5:0] funct; 
assign op = instrD[31:26];
assign rs = instrD[25:21];
assign funct = instrD[5:0];
reg[6:0] controls;

assign {regwrite, regdst, alusrc, branch, memtoreg, jump, memwrite} = controls;
always @(*) begin
    case (op)
        `R_TYPE: case(instrD)
            32'b0: controls <= 7'b0000000;
            default: controls <= 7'b1100000;
        endcase
        `SW: controls <= 7'b0010001;
        `SH: controls <= 7'b0010001;
        `SB: controls <= 7'b0010001;
        `LB: controls <= 7'b1010100;
        `LBU: controls <= 7'b1010100;
        `LH: controls <= 7'b1010100;
        `LHU: controls <= 7'b1010100;
        `LW: controls <= 7'b1010100;
        `BEQ: controls <= 7'b0001000;
        `BNE: controls <= 7'b0001000;
        `BGTZ: controls <= 7'b0001000;
        `BLEZ: controls <= 7'b0001000;
        `REGIMM_INST: controls <= 7'b0001000;
        `J: controls <= 7'b0000010;
        `JAL: controls <= 7'b0000010;
        `ANDI: controls <= 7'b1010000;
        `XORI: controls <= 7'b1010000;
        `LUI:  controls <= 7'b1010000;
        `ORI:  controls <= 7'b1010000;
        `ADDI: controls <= 7'b1010000;
        `ADDIU: controls <= 7'b1010000;
        `SLTI: controls <= 7'b1010000;
        `SLTIU: controls <= 7'b1010000;
        //mfc0 and mtc0
        `SPECIAL3_INST: case(rs)
            `MTC0:controls <= 7'b0000000; //控制信号;
            `MFC0:controls <= 7'b1000000; //控制信号;
            `ERET:controls <= 7'b0000000; //控制信号;
            default: controls <= 7'b0000000;//无效指令
        endcase
        default: controls <= 7'b0000000;
    endcase
end

always @(*) begin
    instrError <= 1'b0;
    case(op)
        `R_TYPE:
            case(funct)
                `ADD,`ADDU,`SUB,`SUBU,`SLTU,`SLT ,
                `AND,`NOR, `OR, `XOR,
                `SLLV, `SLL, `SRAV, `SRA, `SRLV, `SRL,
                `MFHI, `MFLO, 
                `JR, `MULT, `MULTU, `DIV, `DIVU, `MTHI, `MTLO,
                `SYSCALL, `BREAK,
                `JALR: ;
                default: instrError <=  1'b1;
            endcase
        `ADDI, `SLTI, `SLTIU, `ADDIU, `ANDI, `LUI, `XORI, `ORI,
        `BEQ, `BNE, `BLEZ, `BGTZ,
        `BRANCHS,
        `LW, `LB, `LBU, `LH, `LHU,
        `SW, `SB, `SH,
        `J,
        `JAL,
        `SPECIAL3_INST: ;
        default: instrError <= 1'b1;
    endcase
end


endmodule