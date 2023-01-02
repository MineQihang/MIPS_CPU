`timescale 1ns / 1ps

`include "defines2.vh"

module signext(
    input wire[15:0] a,
    input wire[5:0] op,
    output reg[31:0] y
);

always @(*) begin
    case(op)
        `ANDI: y <= {{16{1'b0}}, a};
        `XORI: y <= {{16{1'b0}}, a};
        `LUI:  y <= {{16{1'b0}}, a};
        `ORI:  y <= {{16{1'b0}}, a};
        default: y <= {{16{a[15]}}, a};
    endcase
end

endmodule