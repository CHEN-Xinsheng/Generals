module Game_Player
#(parameter VGA_WIDTH = 0, BORAD_WIDTH = 10, LOG2_BORAD_WIDTH = 4, LOG2_PLAYER_CNT = 3, LOG2_PIECE_TYPE_CNT = 2, LOG2_MAX_TROOP = 9, LOG2_MAX_ROUND = 12) (
    //// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
    output wire [LOG2_BORAD_WIDTH - 1: 0]   cursor_h_o_test,         // 当前光标位置的横坐标（h 坐标）
    output wire [LOG2_BORAD_WIDTH - 1: 0]   cursor_v_o_test,         // 当前光标位置的纵坐标（v 坐标）
    output wire [LOG2_MAX_TROOP - 1: 0]     troop_o_test,            // 当前格兵力
    output wire [LOG2_PLAYER_CNT - 1:0]     owner_o_test,            // 当前格归属方
    output wire [LOG2_PIECE_TYPE_CNT - 1:0] piece_type_o_test,       // 当前格棋子类型
    output wire [LOG2_PLAYER_CNT - 1:0]     current_player_o_test,   // 当前回合玩家，正常情况下应与当前格归属方一致
    //// [TEST END]

    //// input
    input wire                    clock,
    input wire                    reset,
    input wire                    clk_vga,
    // 与 Keyboard_Decoder 交互：获取键盘操作信号 
    input wire                    keyboard_ready,
    input wire [2: 0]             keyboard_data,

    // 与 Pixel_Controller（的 vga 模块）交互： 获取当前的横纵坐标
    input wire [VGA_WIDTH - 1: 0] hdata,
    input wire [VGA_WIDTH - 1: 0] vdata,

    //// output
    // 与 Keyboard_Decoder 交互：输出键盘操作已被读取的信号
    output wire                   keyboard_read_fin,  // 逻辑模块 -> 键盘输入模块 的信号，1表示数据已经被读取
    // 游戏逻辑生成的图像
    output wire [7: 0]            gen_red,
    output wire [7: 0]            gen_green,
    output wire [7: 0]            gen_blue,
    output wire                   use_gen    // 当前像素是使用游戏逻辑生成的图像(1)还是背景图(0)
);

//// [游戏内部数据 BEGIN]
// 玩家类型
typedef enum logic [LOG2_PLAYER_CNT - 1:0]        {NPC, RED, BLUE} Player;
// 每个棋子类型
typedef enum logic [LOG2_PIECE_TYPE_CNT - 1:0]    {TERRITORY,           MOUNTAIN,    CROWN,   CITY      } Piece;
                                                // 普通领地（含空白格）， 山，         王城，    塔（城市）
// 单元格结构体
typedef struct {
    Player                        owner;        // 该格子归属方
    Piece                         piece_type;   // 该棋子类型
    reg [LOG2_MAX_TROOP - 1: 0]   troop;        // 该格子兵力值
} Cell;
// 平面坐标结构体
typedef struct {
    logic [LOG2_BORAD_WIDTH - 1: 0]  h;         // 位置的横坐标（h 坐标）
    logic [LOG2_BORAD_WIDTH - 1: 0]  v;         // 位置的纵坐标（v 坐标）
} Position;
// 键盘操作类型
typedef enum logic[2:0]  {W, A, S, D, SPACE, Z, NONE} Operation;
//   - W：000
//   - A：001
//   - S：010
//   - D：011
//   - 空格：100
//   - Z：101
//   - NONE: 110 表示没有操作


// 游戏数据
Cell cells [BORAD_WIDTH - 1: 0][BORAD_WIDTH - 1: 0];  // 棋盘结构体数组

Operation                         operation;          // 最新一次操作。 operation == NONE 表示最近一次操作已被结算，否则尚未结算
Player                            current_player;     // 当前玩家
Position                          cursor;             // 当前光标位置
logic    [1: 0]                   cursor_type;        // 光标所处模式：选择模式(0x)，行棋模式(1x)
logic    [LOG2_MAX_ROUND: 0]      round;              // 当前回合（从 1 开始）

// 游戏数据初始化
initial begin
    for (int i = 0; i < BORAD_WIDTH; i++) begin
        for (int j = 0; j < BORAD_WIDTH; j++) begin
            // 每个格子都初始化为 RED 玩家的 CITY 类型，兵力 0x43
            cells[i][j] = '{RED, CITY, 'h43};
        end
    end
    operation      = NONE;              // 初始时，操作队列置空
    current_player = Player'(1);        // 初始回合玩家
    cursor         = '{'d0, 'd7};
    cursor_type    = 'd0;
    round          = 'd1;               // 初始回合（从 1 开始）
end

// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
assign cursor_h_o_test       = cursor.h;                                   // 当前光标位置的横坐标（h 坐标）
assign cursor_v_o_test       = cursor.v;                                   // 当前光标位置的纵坐标（v 坐标）
assign troop_o_test          = cells[cursor.h][cursor.v].troop;            // 当前格兵力
assign owner_o_test          = cells[cursor.h][cursor.v].owner;            // 当前格归属方
assign piece_type_o_test     = cells[cursor.h][cursor.v].piece_type;       // 当前格棋子类型
assign current_player_o_test = current_player;                             // 当前回合玩家，正常情况下应与当前格归属方一致
// [TEST END]

//// [游戏内部数据 END]


//// [与输入模块交互部分 BEGIN]
always_ff @ (posedge clock) begin
    // 如果键盘输入模块有新数据 
    if (keyboard_ready) begin
        // 缓存一次未结算的操作
        if (keyboard_data <= 'b101) begin
            operation <= Operation'(keyboard_data);
        end
        // 并给键盘处理模块返回读取已完成的信号
        keyboard_read_fin <= 'b1;
    end else begin
        keyboard_read_fin <= 'b0;
    end
end
//// [与输入模块交互部分 END]


//// [游戏逻辑部分 BEGIN]
always_ff @ (posedge clock) begin
    // 如果当前有尚未结算的操作，那么结算一次操作
    if (operation != NONE) begin
        casez (operation)
            : 
            // 判断操作是否合法
            default: 
        endcase

        // 操作结算完成，将光标移动到下一回合玩家的王城
        
        // 标记当前已无尚未结算的操作
        operation <= NONE;
    end
end


//// [游戏逻辑部分 END]



//// [游戏显示部分 BEGIN]
logic [15:0] address;
logic [31:0] ramdata;
logic [31:0] indata = 32'b0;
assign address = (vdata%50)*50 + (hdata%50);
assign gen_red = (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50)? ramdata[7:0]:0;
assign gen_green = (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50)? ramdata[15:8]:0;
assign gen_blue = (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50)? ramdata[23:16]:0;
ram_bluecity ram_bluecity_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(ramdata)
);
always_comb begin
    if (hdata == 50 || hdata==100 || hdata==150 || hdata == 200|| hdata == 250 || hdata==300 || hdata==350 || hdata == 400 || hdata==450 || hdata==500 || hdata==550 || vdata == 50 || vdata==100 || vdata==150 || vdata == 200 || vdata == 250 || vdata==300 || vdata==350 || vdata == 400 || vdata==450 || vdata==500 || vdata==550) begin
        use_gen = 0;
    end else begin
        use_gen = 1;
    end
end
//// [游戏显示部分 END]
endmodule