module Keyboard_Decoder (
    // input
    input wire          clock,
    input wire          reset,
    input wire          ps2_clock,   // PS/2 时钟信号
    input wire          ps2_data,    // PS/2 数据信号
    
    // output
    output wire         locker,
    output wire [3: 0]  data
);

endmodule