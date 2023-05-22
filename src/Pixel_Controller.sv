module Pixel_Controller
#(parameter WIDTH = 0, HSIZE = 0, HFP = 0, HSP = 0, HMAX = 0, VSIZE = 0, VFP = 0, VSP = 0, VMAX = 0, HSPP = 0, VSPP = 0)
(
    // 时钟、复位
    input  wire clk_vga,             // vga 输入时钟 (50M)
    input  wire reset_n,             // 上电复位信号，低有效

    // 游戏逻辑生成的图像
    input  wire [7: 0] gen_red,
    input  wire [7: 0] gen_green,
    input  wire [7: 0] gen_blue,
    input  wire        use_gen,      // 当前像素是使用游戏逻辑生成的图像(1)还是背景图(0)

    // 当前横纵坐标
    output wire [WIDTH - 1: 0] hdata_o,
    output wire [WIDTH - 1: 0] vdata_o,

    // HDMI 图像输出
    // '_O' 后缀表示该输出将直接接到 mod_top 的对应输出
    output wire [7: 0] video_red_O,   // 红色像素，8位
    output wire [7: 0] video_green_O, // 绿色像素，8位
    output wire [7: 0] video_blue_O,  // 蓝色像素，8位
    output wire        video_hsync_O, // 行同步（水平同步）信号
    output wire        video_vsync_O, // 场同步（垂直同步）信号
    output wire        video_clk_O,   // 像素时钟输出
    output wire        video_de_O     // 行数据有效信号，用于区分消隐区

);

assign video_clk_O = clk_vga;

// 当前横纵坐标
logic [WIDTH - 1: 0] hdata;
logic [WIDTH - 1: 0] vdata;
<<<<<<< src/Pixel_Controller.sv
assign hdata_o = hdata;
assign vdata_o = vdata;
=======
logic [15:0] address;
logic [31:0] ramdata;
logic [31:0] indata = 32'b0;
logic [7:0] red;
logic [7:0] green;
logic [7:0] blue;
assign vdata_o = vdata;
assign hdata_o = hdata;
assign address = (vdata%50)*50 + (hdata%50);
assign red = (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50)? ramdata[7:0]:0;
assign green = (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50)? ramdata[15:8]:0;
assign blue = (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50)? ramdata[23:16]:0;
>>>>>>> src/Pixel_Controller.sv

// 背景的当前像素 RGB 值
logic [7: 0] background_red;
logic [7: 0] background_green;
logic [7: 0] background_blue;


// vga 模块
vga #(WIDTH, HSIZE, HFP, HSP, HMAX, VSIZE, VFP, VSP, VMAX, HSPP, VSPP) vga800x600at75 (
    // input
    .clk          (clk_vga),
    // output 
    .hdata        (hdata),
    .vdata        (vdata),
    .hsync        (video_hsync_O),
    .vsync        (video_vsync_O),
    .data_enable  (video_de_O)
);

// 背景图绘制模块
Background_Painter background_painter (
    // input
    .hdata        (hdata),
    .vdata        (vdata),
    // output
    .video_red    (background_red),
    .video_green  (background_green),
    .video_blue   (background_blue)
);
ram_bluecity ram_bluecity_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(ramdata)
);
// 图层选择
always_comb begin
    if (use_gen) begin
        video_red_O   = red;
        video_green_O = green;
        video_blue_O  = blue;
    end else begin
        video_red_O   = background_red;
        video_green_O = background_green;
        video_blue_O  = background_blue;
    end
end

endmodule