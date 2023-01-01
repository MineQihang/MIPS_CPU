`timescale 1ns / 1ps

module signext(
    input wire[15:0] a,
    output wire[31:0] y
);

assign y = {{16{1'b0}}, a};
// assign y = {{16{a[15]}}, a};

endmodule