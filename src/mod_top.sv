module mod_top (
    // 时钟、复位
    input  wire clk_100m,           // 100M 输入时钟
    input  wire reset_n,            // 上电复位信号，低有效

    // 开关、LED 等
    input  wire clock_btn,          // 右侧微动开关，推荐作为手动时钟，带消抖电路，按下时为 1
    input  wire reset_btn,          // 左侧微动开关，推荐作为手动复位，带消抖电路，按下时为 1
    input  wire [3:0]  touch_btn,   // 四个按钮开关，按下时为 0
    input  wire [15:0] dip_sw,      // 16 位拨码开关，拨到 “ON” 时为 0
    output wire [31:0] leds,        // 32 位 LED 灯，输出 1 时点亮
    output wire [7: 0] dpy_digit,   // 七段数码管笔段信号
    output wire [7: 0] dpy_segment, // 七段数码管位扫描信号

    // PS/2 键盘、鼠标接口
    input  wire        ps2_clock,   // PS/2 时钟信号
    input  wire        ps2_data,    // PS/2 数据信号

    // // USB 转 TTL 调试串口
    // output wire        uart_txd,    // 串口发送数据
    // input  wire        uart_rxd,    // 串口接收数据

    // // 4MB SRAM 内存
    // inout  wire [31:0] base_ram_data,   // SRAM 数据
    // output wire [19:0] base_ram_addr,   // SRAM 地址
    // output wire [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效。如果不使用字节使能，请保持为0
    // output wire        base_ram_ce_n,   // SRAM 片选，低有效
    // output wire        base_ram_oe_n,   // SRAM 读使能，低有效
    // output wire        base_ram_we_n,   // SRAM 写使能，低有效

    // HDMI 图像输出
    output wire [7: 0] video_red,   // 红色像素，8位
    output wire [7: 0] video_green, // 绿色像素，8位
    output wire [7: 0] video_blue,  // 蓝色像素，8位
    output wire        video_hsync, // 行同步（水平同步）信号
    output wire        video_vsync, // 场同步（垂直同步）信号
    output wire        video_clk,   // 像素时钟输出
    output wire        video_de     // 行数据有效信号，用于区分消隐区

    // // RS-232 串口
    // input  wire        rs232_rxd,   // 接收数据
    // output wire        rs232_txd,   // 发送数据
    // input  wire        rs232_cts,   // Clear-To-Send 控制信号
    // output wire        rs232_rts,   // Request-To-Send 控制信号

    // // SD 卡（SPI 模式）
    // output wire        sd_sclk,     // SPI 时钟
    // output wire        sd_mosi,
    // input  wire        sd_miso,
    // output wire        sd_cs,       // SPI 片选，低有效
    // input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    // input  wire        sd_wp,       // 写保护检测，0 表示写保护状态

    // // SDRAM 内存，信号具体含义请参考数据手册
    // output wire [12:0] sdram_addr,
    // output wire [1: 0] sdram_bank,
    // output wire        sdram_cas_n,
    // output wire        sdram_ce_n,
    // output wire        sdram_cke,
    // output wire        sdram_clk,
    // inout wire [15:0] sdram_dq,
    // output wire        sdram_dqmh,
    // output wire        sdram_dqml,
    // output wire        sdram_ras_n,
    // output wire        sdram_we_n,

    // // GMII 以太网接口、MDIO 接口，信号具体含义请参考数据手册
    // output wire        eth_gtx_clk,
    // output wire        eth_rst_n,
    // input  wire        eth_rx_clk,
    // input  wire        eth_rx_dv,
    // input  wire        eth_rx_er,
    // input  wire [7: 0] eth_rxd,
    // output wire        eth_tx_clk,
    // output wire        eth_tx_en,
    // output wire        eth_tx_er,
    // output wire [7: 0] eth_txd,
    // input  wire        eth_col,
    // input  wire        eth_crs,
    // output wire        eth_mdc,
    // inout  wire        eth_mdio
);

/* =========== Demo code begin =========== */
wire clk_100M = clk_100m;

// PLL 分频演示，从输入产生不同频率的时钟
wire clk_50M;
wire clk_vga;
ip_pll u_ip_pll(
    .inclk0 (clk_100M),
    .c0     (clk_50M ),  // 50MHz 像素时钟
    .c1     (clk_vga )   // 25MHz 像素时钟
);

// 七段数码管扫描演示
reg [31: 0] number;
dpy_scan u_dpy_scan (
    .clk     (clk_100M    ),
    .number  (number      ),
    .dp      (7'b0        ),
    .digit   (dpy_digit   ),
    .segment (dpy_segment )
);

//// 参数设定
// 游戏逻辑相关
parameter BORAD_WIDTH           = 10;  // 棋盘宽度
parameter LOG2_BORAD_WIDTH      = $clog2(BORAD_WIDTH);   // 棋盘宽度，对 2 取对数（向上取整）
parameter MAX_PLAYER_CNT        = 7;   // 玩家数量
parameter LOG2_MAX_PLAYER_CNT   = $clog2(MAX_PLAYER_CNT + 1);   // 玩家数量加上 1(NPC) 后，对 2 取对数（向上取整）
parameter LOG2_PIECE_TYPE_CNT   = 2;   // 棋子种类数量，对 2 取对数（向上取整）
parameter LOG2_MAX_TROOP        = 9;   // 格子最大兵力数，对 2 取对数（向上取整）
parameter LOG2_MAX_ROUND        = 12;  // 允许的最大回合数，对 2 取对数（向上取整）
parameter LOG2_MAX_CURSOR_TYPE  = 2;   // 光标种类数，对 2 取对数（向上取整）
parameter MAX_STEP_TIME         = 15;  // 每次操作最长允许时间
parameter LOG2_MAX_STEP_TIME    = $clog2(MAX_STEP_TIME);   // 每次操作最长允许时间，对 2 取对数（向上取整）
// vga 相关
parameter VGA_WIDTH = 10;
parameter HSIZE     = 640;
parameter HFP       = 688;
parameter HSP       = 784;
parameter HMAX      = 800;
parameter VSIZE     = 480;
parameter VFP       = 490;
parameter VSP       = 492;
parameter VMAX      = 525;
parameter HSPP      = 1;
parameter VSPP      = 1;


// // [TEST BEGIN] 测试键盘处理模块的输出
// assign number[31:20] = 12'b0;  // 最高 4 位 hex 显示 0
// assign number[19:16] = {3'b0, clock_btn};
// assign number[15:12] = {3'b0, keyboard_ready};
// assign number[11: 8] = {3'b0, keyboard_data[2]};
// assign number[7:  4] = {3'b0, keyboard_data[1]};
// assign number[3:  0] = {3'b0, keyboard_data[0]};
// // [TEST END] test keyoard

// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
logic [LOG2_BORAD_WIDTH - 1: 0]     cursor_h_o_test;         // 当前光标位置的横坐标（h 坐标）
logic [LOG2_BORAD_WIDTH - 1: 0]     cursor_v_o_test;         // 当前光标位置的纵坐标（v 坐标）
logic [LOG2_MAX_TROOP - 1: 0]       troop_o_test;            // 当前格兵力
logic [LOG2_MAX_PLAYER_CNT - 1: 0]  owner_o_test;            // 当前格归属方
logic [LOG2_PIECE_TYPE_CNT - 1: 0]  piece_type_o_test;       // 当前格棋子类型
logic [LOG2_MAX_PLAYER_CNT - 1: 0]  current_player_o_test;   // 当前回合玩家
logic [LOG2_MAX_PLAYER_CNT - 1: 0]  next_player_o_test;      // 下一回合玩家
logic [LOG2_MAX_CURSOR_TYPE -1: 0]  cursor_type_o_test;      // 当前光标类型
logic [2: 0]                        operation_o_test;        // 当前操作队列

assign number[31:28] = cursor_h_o_test;       // 1   当前光标位置的横坐标（h 坐标）
assign number[27:24] = cursor_v_o_test;       // 2   当前光标位置的纵坐标（v 坐标）
assign number[23:16] = troop_o_test[7:0];     // 3-4 当前格兵力
assign number[15:12] = owner_o_test;          // 5   当前格归属方
assign number[11: 8] = piece_type_o_test;     // 6   当前格棋子类型
assign number[ 7: 4] = current_player_o_test; // 7   当前回合玩家
assign number[ 3: 0] = cursor_type_o_test;    // 8   当前光标类型
// assign number[ 3: 0] = next_player_o_test;    // 8   下一回合玩家
// [TEST END]


// // 自增计数器，用于数码管演示
// reg [31: 0] counter;
// always @(posedge clk_100M or posedge reset_btn) begin
//     if (reset_btn) begin
// 	     counter <= 32'b0;
// 		  number <= 32'b0;
// 	 end else begin
//         counter <= counter + 32'b1;
//         if (counter == 32'd5_000_000) begin
//             counter <= 32'b0;
//             number <= number + 32'b1;
//         end
// 	 end
// end

// LED
assign leds[15:0] = number[15:0];
assign leds[31:16] = ~(dip_sw);



// 键盘输入处理模块
logic        keyboard_ready;        // 键盘输入模块 -> 逻辑模块 的信号，1表示有新数据
logic        keyboard_read_fin;     // 逻辑模块 -> 键盘输入模块 的信号，1表示数据已经被读取
logic [2: 0] keyboard_data;
Keyboard_Decoder keyboard_decoder (
    //// input 
    .clock      (clk_100M),
    .reset      (reset_btn),
    .ps2_clock  (ps2_clock),
    .ps2_data   (ps2_data),
    .read_fin   (keyboard_read_fin), // 逻辑模块 -> 键盘输入模块 的信号，1表示数据已经被读取
    // [TEST BEGIN] 用手动时钟作为 逻辑模块 -> 键盘输入模块 的 表示数据已被读取的信号，用于单独测试 Keyboard_Decoder
    // .read_fin   (clock_btn),
    // [TEST END]

    //// output
    .ready      (keyboard_ready),    // 键盘输入模块 -> 逻辑模块 的信号，1表示有新数据
    .data       (keyboard_data)
);


// 游戏逻辑与显示模块
wire [VGA_WIDTH - 1:0] hdata;    // 当前横坐标
wire [VGA_WIDTH - 1:0] vdata;    // 当前纵坐标
wire [7:0]             gen_red;  // 游戏逻辑部分生成的图像
wire [7:0]             gen_green;
wire [7:0]             gen_blue;
wire                   use_gen;  // 当前像素是使用游戏逻辑生成的图像(1)还是背景图(0)
Game_Player #(
        .VGA_WIDTH             (VGA_WIDTH),
        .BORAD_WIDTH           (BORAD_WIDTH), 
        .LOG2_BORAD_WIDTH      (LOG2_BORAD_WIDTH),
        .MAX_PLAYER_CNT        (MAX_PLAYER_CNT),
        .LOG2_MAX_PLAYER_CNT   (LOG2_MAX_PLAYER_CNT), 
        .LOG2_PIECE_TYPE_CNT   (LOG2_PIECE_TYPE_CNT), 
        .LOG2_MAX_TROOP        (LOG2_MAX_TROOP), 
        .LOG2_MAX_ROUND        (LOG2_MAX_ROUND),
        .LOG2_MAX_CURSOR_TYPE  (LOG2_MAX_CURSOR_TYPE),
        .MAX_STEP_TIME         (MAX_STEP_TIME),
        .LOG2_MAX_STEP_TIME    (LOG2_MAX_STEP_TIME)
    ) game_player (
        //// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
        .cursor_h_o_test       (cursor_h_o_test),
        .cursor_v_o_test       (cursor_v_o_test),
        .troop_o_test          (troop_o_test),
        .owner_o_test          (owner_o_test),
        .piece_type_o_test     (piece_type_o_test),
        .current_player_o_test (current_player_o_test),
        .next_player_o_test    (next_player_o_test),
        .cursor_type_o_test    (cursor_type_o_test),
        .operation_o_test      (operation_o_test),
        //// [TEST END]

        //// input
        // 时钟信号和重置信号
        .clock             (clk_50M),
        .start             (clock_btn),
        .reset             (reset_btn),
        .clk_vga           (clk_vga),
        // 与 Keyboard_Decoder 交互：获取键盘操作信号
        .keyboard_ready    (keyboard_ready),  // 键盘输入模块 -> 逻辑模块 的信号，1表示有新数据
        .keyboard_data     (keyboard_data),
        // 与 Pixel_Controller（的 vga 模块）交互： 获取当前的横纵坐标
        .hdata             (hdata),
        .vdata             (vdata),

        //// output
        // 与 Keyboard_Decoder 交互：输出键盘操作已被读取的信号
        .keyboard_read_fin (keyboard_read_fin), // 逻辑模块 -> 键盘输入模块 的信号，1表示数据已经被读取
        // 与 Pixel_Controller 交互：输出当前像素棋局图像，以及该像素是显示背景(use_gen=0)还是棋子(use_gen=1)
        .gen_red           (gen_red),
        .gen_green         (gen_green),
        .gen_blue          (gen_blue),
        .use_gen           (use_gen)
);


// 显示控制模块
Pixel_Controller #(
        .VGA_WIDTH  (VGA_WIDTH),
        .HSIZE      (HSIZE),
        .HFP        (HFP),
        .HSP        (HSP),
        .HMAX       (HMAX),
        .VSIZE      (VSIZE),
        .VFP        (VFP),
        .VSP        (VSP),
        .VMAX       (VMAX),
        .HSPP       (HSPP),
        .VSPP       (VSPP)
    ) pixel_controller (
        //// input 
        // 时钟、复位
        .clk_vga       (clk_vga),       // vga 输入时钟 (25M)
        .reset_n       (reset_n),       // 上电复位信号，低有效
        // 游戏逻辑生成的图像
        .gen_red       (gen_red),
        .gen_green     (gen_green),
        .gen_blue      (gen_blue),
        .use_gen       (use_gen),
        
        //// output
        // 生成当前横纵坐标
        .hdata_o       (hdata),
        .vdata_o       (vdata),
        // 以下输出直接接到 mod_top 的对应输出
        .video_red_O   (video_red),
        .video_green_O (video_green),
        .video_blue_O  (video_blue),
        .video_hsync_O (video_hsync),
        .video_vsync_O (video_vsync),
        .video_clk_O   (video_clk),
        .video_de_O    (video_de)
);

// 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz，显示渐变色彩条
// 生成彩条数据，分别取坐标低位作为 RGB 值
// 警告：该图像生成方式仅供演示，请勿使用横纵坐标驱动大量逻辑！！
//assign video_red = ((vdata>=50&&vdata<=550)&&(hdata>=50&&hdata<=550)&&!((vdata%50==0) || (hdata%50==0))) ? 255 : 0;
//assign video_green = ((vdata>=50&&vdata<=550)&&(hdata>=50&&hdata<=550)&&!((vdata%50==0) || (hdata%50==0)))  ? 255 : 0;
//assign video_blue = ((vdata>=50&&vdata<=550)&&(hdata>=50&&hdata<=550)&&!((vdata%50==0) || (hdata%50==0))) ? 255 : 0;

/* =========== Demo code end =========== */

endmodule
