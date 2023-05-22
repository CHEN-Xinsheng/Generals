module Game_Player
#(parameter VGA_WIDTH = 0, BORAD_WIDTH = 10, LOG2_BORAD_WIDTH = 4, LOG2_PLAYER_CNT = 3, LOG2_MAX_TROOP = 9, LOG2_MAX_ROUND = 12) (
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

typedef enum logic[LOG2_PLAYER_CNT - 1:0] {NPC, RED, BLUE}                           player_t;   // 玩家类型
typedef enum logic[1:0]  {TERRITORY,               MOUNTAIN,    CROWN,   CITY      } cell_t;     // 每个格子类型
                    //    普通领地（含空白格），     山，         王城，    塔（城市）
typedef struct {
    player_t                      owner;        // 该格子归属方
    cell_t                        cell_type;    // 该格子类型
    reg [LOG2_MAX_TROOP - 1: 0]   troop;        // 该格子兵力值
} Cell;

Cell cells [BORAD_WIDTH - 1: 0][BORAD_WIDTH - 1: 0];    // 棋盘结构体数组


player_t                            current_player;     // 当前玩家
logic    [LOG2_BORAD_WIDTH - 1: 0]  cursor_h;           // 当前光标位置的横坐标
logic    [LOG2_BORAD_WIDTH - 1: 0]  cursor_v;           // 当前光标位置的纵坐标
logic    [1: 0]                     cursor_type;        // 光标所处模式：选择模式(0x)，行棋模式(1x)
logic    [LOG2_MAX_ROUND: 0]        round;              // 当前回合（从 1 开始）


initial begin
    for (int i = 0; i < BORAD_WIDTH; i++) begin
        for (int j = 0; j < BORAD_WIDTH; j++) begin
            // 每个格子都初始化为 RED 玩家的 CITY 类型，兵力 43
            cells[i][j] = '{RED, CITY, 'd43};
            // cells[i][j].owner     = RED;
            // cells[i][j].cell_type = CITY;
            // cells[i][j].troop     = 'd43;
        end
    end
    current_player = player_t'(0);      // 初始回合玩家
    cursor_h     = 'd3;
    cursor_v     = 'd4;
    cursor_type  = 'd0;
    round        = 'd1;                 // 初始回合（从 1 开始）
end

assign use_gen = 1;
endmodule