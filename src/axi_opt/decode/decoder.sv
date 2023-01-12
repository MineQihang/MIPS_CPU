`timescale 1ns / 1ps

`include "../defines/defines2.vh"
`include "../defines/aludefines.vh"

module decoder(
    input   wire [31:0] inst,
    // alu
    output  reg  [4:0]  alucontrol,
    output  reg         alusrc,
    // regfile
    output  reg         regdst,
    output  reg         regwrite,
    output  reg         savepc,
    // memory
    output  reg         memtoreg,
    output  reg         memwrite,
    output  reg         memread,
    // branch
    output  reg         branch,
    output  reg         jump,
    output  reg         jr,
    // exception
    output  reg         instError,
    output  reg         breakD,
    output  reg         syscall,
    output  reg         eret,
    output  reg         mfc0,
    output  reg         mtc0,
    // data move
    output  reg         mthi,
    output  reg         mtlo,
    output  reg         mfhi,
    output  reg         mflo
);

wire[5:0] op;
wire[5:0] funct;
wire[4:0] rs, rt;
// reg [6:0] controls;

assign op    = inst[31:26];
assign funct = inst[5:0];
assign rs    = inst[25:21];
assign rt    = inst[20:16];

always @(*) begin
    alucontrol  = `ALU_ZERO;
    alusrc      = 1'b0;
    regdst      = 1'b0;
    regwrite    = 1'b0;
    savepc      = 1'b0;
    memtoreg    = 1'b0;
    memwrite    = 1'b0;
    memread     = 1'b0;
    branch      = 1'b0;
    jump        = 1'b0;
    jr          = 1'b0;
    instError   = 1'b0;
    breakD      = 1'b0;
    syscall     = 1'b0;
    eret        = 1'b0;
    mfc0        = 1'b0;
    mtc0        = 1'b0;
    mthi        = 1'b0;
    mtlo        = 1'b0;
    mfhi        = 1'b0;
    mflo        = 1'b0;
    case (op)
        `R_TYPE:
            case(funct)
                // 算数指令（10条，总14条）
                `ADD: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_ADD;
                end
                `ADDU: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_ADDU;
                end
                `SUB: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SUB;
                end
                `SUBU: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SUBU;
                end
                `SLT: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SLT;
                end
                `SLTU: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SLTU;
                end
                `MULT: begin
                    // regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_MULT;
                end
                `MULTU: begin
                    // regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_MULTU;
                end
                `DIV: begin
                    // regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_DIV;
                end
                `DIVU: begin
                    // regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_DIVU;
                end
                // 逻辑运算指令（4条，共8条）
                `AND: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_AND;
                end
                `NOR: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_NOR;
                end
                `OR: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_OR;
                end
                `XOR: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_XOR;
                end
                // 移位指令（6条，共6条）
                `SLL: if(|inst) begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SLL;
                end
                `SLLV: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SLLV;
                end
                `SRA: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SRA;
                end
                `SRAV: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SRAV;
                end
                `SRL: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SRL;
                end
                `SRLV: begin
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    alucontrol = `ALU_SRLV;
                end
                // 分支跳转指令（2条，共12条）
                `JR: begin
                    regdst   = 1'b1;
                    jr       = 1'b1;
                    jump     = 1'b1;
                    alucontrol = `ALU_B;
                end
                `JALR: begin
                    savepc = 1'b1;
                    regwrite = 1'b1;
                    regdst   = 1'b1;
                    jr       = 1'b1;
                    jump     = 1'b1;
                    alucontrol = `ALU_B;
                end
                // 数据移动指令（4条，共4条）
                `MFHI: begin
                    mfhi = 1'b1;
                    regwrite = 1'b1;
                    regdst = 1'b1;
                end
                `MFLO: begin
                    mflo = 1'b1;
                    regwrite = 1'b1;
                    regdst = 1'b1;
                end 
                `MTHI: begin
                    mthi = 1'b1;
                end
                `MTLO: begin
                    mtlo = 1'b1;
                end
                // 自陷指令（2条，共2条）
                `SYSCALL: begin
                    syscall = 1'b1;
                end
                `BREAK: begin
                    breakD = 1'b1;
                end
                // 无效指令
                default: instError =  1'b1;
            endcase
        // 算数指令（4条，共14条）
        `ADDI: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `ADDIU: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_ADDU;
        end
        `SLTI: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_SLT;
        end
        `SLTIU: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_SLTU;
        end
        // 逻辑运算指令（4条，共8条）
        `ANDI: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_AND;
        end
        `LUI: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_LUI;
        end
        `XORI: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_XOR;
        end
        `ORI: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            alucontrol = `ALU_OR;
        end
        // 分支跳转指令（4+4=8条，共12条）
        `BEQ: begin
            branch = 1'b1;
        end
        `BNE: begin
            branch = 1'b1;
        end
        `BLEZ: begin
            branch = 1'b1;
        end
        `BGTZ: begin
            branch = 1'b1;
        end
        `BRANCHS: begin // BGEZ, BLTZ, BLTZAL, BGEZAL
            branch = 1'b1;
            case(rt)
                `BLTZAL: begin
                    savepc = 1'b1;
                    regwrite = 1'b1;
                    alucontrol = `ALU_B;
                end
                `BGEZAL: begin
                    savepc = 1'b1;
                    regwrite = 1'b1;
                    alucontrol = `ALU_B;
                end
                default: regwrite = 1'b0;
            endcase
        end
        // 分支跳转指令（2条，共12条）
        `J: begin
            jump = 1'b1;
        end
        `JAL: begin
            savepc = 1'b1;
            jump = 1'b1;
            regwrite = 1'b1;
            alucontrol = `ALU_B;
        end
        // 访存指令（8条，共8条）
        `LW: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            memtoreg = 1'b1;
            memread  = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `LB: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            memtoreg = 1'b1;
            memread  = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `LBU: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            memtoreg = 1'b1;
            memread  = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `LH: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            memtoreg = 1'b1;
            memread  = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `LHU: begin
            regwrite = 1'b1;
            alusrc   = 1'b1;
            memtoreg = 1'b1;
            memread  = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `SW: begin
            alusrc   = 1'b1;
            memwrite = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `SB: begin
            alusrc   = 1'b1;
            memwrite = 1'b1;
            alucontrol = `ALU_ADD;
        end
        `SH: begin
            alusrc   = 1'b1;
            memwrite = 1'b1;
            alucontrol = `ALU_ADD;
        end
        // 特权指令（3条，共3条）
        `SPECIAL3_INST: case(rs)
            `MTC0: begin
                mtc0 = 1'b1;
                alucontrol = `ALU_B;
            end
            `MFC0: begin
                regwrite = 1'b1;
                mfc0 = 1'b1;
            end
            `ERET: begin
                eret = 1'b1;
            end
            default: instError = 1'b1; // 无效指令
        endcase
        default: instError = 1'b1; // 无效指令
    endcase
end

endmodule