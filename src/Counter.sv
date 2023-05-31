/* 
    循环计数器。在足够高的时钟频率时，可用于抽签。
*/ 
module Counter
#(parameter BIT_WIDTH = 10) (
    // input
    input wire clock,
    input wire reset,
    // output
    output wire [BIT_WIDTH - 1: 0] number_o
);

logic [BIT_WIDTH - 1: 0] number;
initial number = 0;
always_ff @ (posedge clock, posedge reset) begin
    if (reset)
        number <= 0;
    else
        number <= number + 1;
end

assign number_o = number;
endmodule