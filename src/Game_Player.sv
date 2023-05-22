module Game_Player
#(parameter VGA_WIDTH = 0, BORAD_WIDTH = 10) (
    //// input
    // 与 Keyboard_Decoder 交互：获取键盘操作信号 
    input wire                    keyboard_locker,
    input wire [2: 0]             keyboard_data,

    // 与 Pixel_Controller（的 vga 模块）交互： 获取当前的横纵坐标
    input wire [VGA_WIDTH - 1: 0] hdata,
    input wire [VGA_WIDTH - 1: 0] vdata,
    
    //// output
    // 游戏逻辑生成的图像
    output wire [7: 0]            gen_red,
    output wire [7: 0]            gen_green,
    output wire [7: 0]            gen_blue,
    output wire                   use_gen    // 当前像素是使用游戏逻辑生成的图像(1)还是背景图(0)
);

assign use_gen = 0;
endmodule