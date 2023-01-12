`timescale 1ns / 1ps

module regfile(
    input wire clk, rst,
    input wire we3,
    input wire[4:0] ra1,ra2,wa3,
    input wire[31:0] wd3,
    // input wire[2:0] flagD, // 是否hilo
    // input wire[2:0] flagW, // 是否hilo
    output wire[31:0] rd1,rd2
);

reg [31:0] rf[31:0];
// reg [63:0] hilo;

always @(negedge clk) begin
    if(rst) begin
        rf <= '{default: 32'b0};
    end
    else if(we3) begin
        // case(flagW)
        //     3'b110: hilo <= {wd3[63:32], hilo[31:0]};
        //     3'b101: hilo <= {hilo[63:32], wd3[31:0]};
        //     3'b111: hilo <= wd3;
        //     3'b010: rf[wa3] <= wd3[63:32];
        //     3'b001: rf[wa3] <= wd3[31:0];
        //     default: 
        rf[wa3] <= wd3;
        // endcase
    end
end

assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
assign rd2 = (ra2 != 0) ? rf[ra2] : 0;

endmodule
