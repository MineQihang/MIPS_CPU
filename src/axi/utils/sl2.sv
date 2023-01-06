`timescale 1ns / 1ps

module sl2#(parameter WIDTH=32)(
    input wire[WIDTH-1:0] a,
    output wire[WIDTH-1:0] y
);

assign y = {a[WIDTH-3:0], 2'b00};

endmodule