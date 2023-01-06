`timescale 1ns / 1ps

`include "defines2.vh"

module link(
    input wire[5:0] op,
    input wire[4:0] rt,
    input wire[5:0] funct,
    output reg linkD,
    output reg linkPCD
);
	always @(*) begin
		case(op)
			`REGIMM_INST: case(rt)
                `BGEZAL: begin
                    linkD <= 1'b1;
                    linkPCD <= 1'b1;
                end
                `BLTZAL: begin
                    linkD <= 1'b1;
                    linkPCD <= 1'b1;
                end
                default: begin
                    linkD <= 1'b0;
                    linkPCD <= 1'b0;
                end
            endcase
            `JAL: begin
                linkD <= 1'b1;
                linkPCD <= 1'b1;
            end
            `R_TYPE: begin
                case(funct)
                    `JALR: begin
                        linkD <= 1'b0;
                        linkPCD <= 1'b1;
                    end
                    default: begin
                        linkD <= 1'b0;
                        linkPCD <= 1'b0;
                    end
                endcase
            end
			default: begin
                linkD <= 1'b0;
                linkPCD <= 1'b0;
            end
		endcase
	end
endmodule