`timescale 1ns / 1ps

// 两位饱和计数器
module counter2(
    input wire [1:0] state, // 当前状态
    input wire action, // 转移动作
    output reg [1:0] next_state // 下一个状态
);

parameter NT = 1'b0, T = 1'b1;
parameter SNT = 2'b00, WNT = 2'b01, WT = 2'b10, ST = 2'b11;

// 更新计数器
always @(*) begin
    case(state)
        SNT:
            case(action)
                NT: next_state = SNT;
                T:  next_state = WNT;
                default: ;
            endcase
        WNT:
            case(action)
                NT: next_state = SNT;
                T:  next_state = WT;
                default: ;
            endcase
        WT:
            case(action)
                NT: next_state = WNT;
                T:  next_state = ST;
                default: ;
            endcase
        ST:
            case(action)
                NT: next_state = WT;
                T:  next_state = ST;
                default: ;
            endcase
        default: ;
    endcase
end

endmodule
