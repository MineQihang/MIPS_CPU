`timescale 1ns / 1ps

`include "defines2.vh"

module branchjudger(
    input wire[31:0] srca,
    input wire[31:0] srcb,
    input wire[5:0] op,
    input wire[4:0] rt,
    output reg branch
);

    always @(*) begin
        case(op)
            `BEQ: branch <= (srca == srcb);
            `BNE: branch <= (srca != srcb);
            `BGTZ: branch <= ($signed(srca) > 0);
            `BLEZ: branch <= ($signed(srca) <= 0);
            `REGIMM_INST: case(rt)
                `BGEZ: branch <= ($signed(srca) >= 0);
                `BGEZAL: branch <= ($signed(srca) >= 0);
                `BLTZ: branch <= ($signed(srca) < 0);
                `BLTZAL: branch <= ($signed(srca) < 0);
                default: branch <= 1'b0;
            endcase
            default: branch <= 1'b0;
        endcase
    end

endmodule
