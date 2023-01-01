`timescale 1ns / 1ps

module regfile(
    input wire clk,
    input wire we3,
    input wire[4:0] ra1,ra2,wa3,
    input wire[63:0] wd3,
    input wire[2:0] flagD, // 是否hilo
    input wire[2:0] flagW, // 是否hilo
    output wire[31:0] rd1,rd2
);

reg [31:0] rf[31:0];
reg [63:0] hilo;

always @(negedge clk) begin
    if(we3) begin
        if (flagW[2]) hilo <= wd3;
        else rf[wa3] <= wd3[31:0];
    end
end

assign rd1 = flagD[2] ? (flagD[1] ? hilo[63:32] : hilo[31:0])
                     : ((ra1 != 0) ? rf[ra1] : 0);
assign rd2 = (ra2 != 0) ? rf[ra2] : 0;

endmodule
