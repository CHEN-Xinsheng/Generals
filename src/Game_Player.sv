module Game_Player
#(parameter VGA_WIDTH            = 0, 
            BORAD_WIDTH          = 10, 
            LOG2_BORAD_WIDTH     = 4, 
            MAX_PLAYER_CNT       = 7, 
            LOG2_MAX_PLAYER_CNT  = 3, 
            LOG2_PIECE_TYPE_CNT  = 2, 
            LOG2_MAX_TROOP       = 9, 
            LOG2_MAX_ROUND       = 12,
            LOG2_MAX_CURSOR_TYPE = 2,
            MAX_STEP_TIME        = 15,
            LOG2_MAX_STEP_TIME   = 5) (
    //// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
    output wire [LOG2_BORAD_WIDTH - 1: 0]       cursor_h_o_test,         // 当前光标位置的横坐标（h 坐标）
    output wire [LOG2_BORAD_WIDTH - 1: 0]       cursor_v_o_test,         // 当前光标位置的纵坐标（v 坐标）
    output wire [LOG2_MAX_TROOP - 1: 0]         troop_o_test,            // 当前格兵力
    output wire [LOG2_MAX_PLAYER_CNT - 1: 0]    owner_o_test,            // 当前格归属方
    output wire [LOG2_PIECE_TYPE_CNT - 1: 0]    piece_type_o_test,       // 当前格棋子类型
    output wire [LOG2_MAX_PLAYER_CNT - 1: 0]    current_player_o_test,   // 当前回合玩家
    output wire [LOG2_MAX_PLAYER_CNT - 1: 0]    next_player_o_test,      // 下一回合玩家
    output wire [LOG2_MAX_CURSOR_TYPE -1: 0]    cursor_type_o_test,      // 当前光标类型
    output wire [2: 0]                          operation_o_test,        // 当前操作队列
    output wire [LOG2_MAX_STEP_TIME -1: 0]      step_timer_o_test,       // 当前回合剩余时间
    //// [TEST END]

    //// input
    input wire                    clock,
    input wire                    start,              // 游戏开始
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
    output wire                   use_gen             // 当前像素是使用游戏逻辑生成的图像(1)还是背景图(0)
);

//// [游戏内部数据 BEGIN]
// 玩家类型
typedef enum logic [LOG2_MAX_PLAYER_CNT - 1:0]    {NPC, RED, BLUE} Player;
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
// 光标类型
typedef enum logic [LOG2_MAX_CURSOR_TYPE - 1:0] {
    CHOOSE     = 2'b00,
    MOVE_TOTAL = 2'b10,
    MOVE_HALF  = 2'b11
} Cursor_type;
// 键盘操作类型
typedef enum logic [2:0] {
    W     = 3'b000, 
    A     = 3'b001, 
    S     = 3'b010, 
    D     = 3'b011, 
    SPACE = 3'b100, 
    Z     = 3'b101, 
    NONE  = 3'b110   // 表示没有操作
} Operation;
// 游戏状态
typedef enum logic [2:0] {
    READY,         // 游戏准备开始
    IN_ROUND,      // 回合内
    CHECK_WIN,     // 判断胜负
    ROUND_SWITCH,  // 回合切换中
    GAME_OVER      // 游戏结束
} State;


// 游戏数据
Cell      cells      [BORAD_WIDTH - 1: 0][BORAD_WIDTH - 1: 0];  // 棋盘结构体数组
Position  crowns_pos [MAX_PLAYER_CNT - 1:0];        // 每个玩家王城的位置

Operation                           operation;          // 最新一次操作。 operation == NONE 表示最近一次操作已被结算，否则尚未结算
Player                              current_player;     // 当前玩家
Position                            cursor;             // 当前光标位置
Cursor_type                         cursor_type;        // 光标所处模式：选择模式(0x)，行棋模式(1x)
logic [LOG2_MAX_ROUND:     0]       step_cnt;           // 已经进行的行棋操作次数（包括超时，视为空操作）
logic [LOG2_MAX_ROUND - 1: 0]       round;              // 当前回合（从 1 开始）
Player                              winner;             // 胜者，该值仅当 state == GAME_OVER 时有效
State                               state;              // 当前游戏状态
logic [LOG2_MAX_STEP_TIME -1: 0]    step_timer;         // 当前回合剩余时间

assign round = (step_cnt + 1) >> 1;

// 游戏常数：玩家顺序表
Player  next_player_table [MAX_PLAYER_CNT - 1:0];   // 每个玩家的下一玩家
initial begin
    next_player_table[RED]  = BLUE;
    next_player_table[BLUE] = RED;
    // assert 以下情况在游戏中不应出现
    for (byte i = 0; i < MAX_PLAYER_CNT; ++i) begin
        if (i != RED && i != BLUE) begin
            next_player_table[i] = NPC;   
        end
    end
end

// 游戏数据初始化
initial begin
    // 各方王城坐标
    crowns_pos[RED]  = '{'d2, 'd3};
    crowns_pos[BLUE] = '{'d8, 'd7};
    // 初始化棋盘
    for (int h = 0; h < BORAD_WIDTH; h++) begin
        for (int v = 0; v < BORAD_WIDTH; v++) begin
            if          (h == crowns_pos[RED ].h && v == crowns_pos[RED ].v) begin
                cells[h][v] = '{RED, CROWN, 'h57};
            end else if (h == crowns_pos[BLUE].h && v == crowns_pos[BLUE].v) begin
                cells[h][v] = '{BLUE, CROWN, 'h59};
            end else begin
                // 初始化为 RED 玩家的 CITY 类型，兵力 0x43
                cells[h][v] = '{RED, CITY, 'h43};
            end
        end
    end

    operation      = NONE;              // 初始时，操作队列置空
    current_player = Player'(1);        // 先手玩家
    cursor         = '{'d0, 'd0};
    cursor_type    = CHOOSE;
    step_cnt       = 'd0;
    winner         = NPC;               // 胜者，winner == NPC 表示尚未分出胜负
    state          = IN_ROUND;          // 初始游戏状态为回合进行中（TODO：更改）
end

// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
assign cursor_h_o_test       = cursor.h;                                // 当前光标位置的横坐标（h 坐标）
assign cursor_v_o_test       = cursor.v;                                // 当前光标位置的纵坐标（v 坐标）
assign troop_o_test          = cells[cursor.h][cursor.v].troop;         // 当前格兵力
assign owner_o_test          = cells[cursor.h][cursor.v].owner;         // 当前格归属方
assign piece_type_o_test     = cells[cursor.h][cursor.v].piece_type;    // 当前格棋子类型
assign current_player_o_test = current_player;                          // 当前回合玩家
assign next_player_o_test    = next_player_table[current_player];       // 下一回合玩家
assign cursor_type_o_test    = cursor_type;                             // 当前光标类型
assign operation_o_test      = operation;                               // 当前操作队列
assign step_timer_o_test     = step_timer;                              // 当前回合剩余时间 
// [TEST END]

//// [游戏内部数据 END]


//// [游戏逻辑部分 BEGIN]
// 与键盘输入模块交互+游戏逻辑部分 顶层 always 块
always_ff @ (posedge clock, posedge reset) begin
    if (reset) begin
        state <= READY;
        // TODO 开始计时
    end else begin
        // 如果键盘输入模块有新数据，那么本周期读取数据，不运行游戏逻辑
        if (keyboard_ready) begin
            // 缓存一次未结算的操作
            if (keyboard_data <= 'b101) begin
                operation <= Operation'(keyboard_data);
            end
            // 并给键盘处理模块返回读取已完成的信号
            keyboard_read_fin <= 'b1;
        // 否则，本周期运行游戏逻辑
        end else begin
            keyboard_read_fin <= 'b0;
            casez (state)
                READY:        ready();
                IN_ROUND:     in_round();
                CHECK_WIN:    check_win();
                ROUND_SWITCH: round_switch();
                GAME_OVER:    ;
                default: ; // assert 这种情况不应出现
            endcase
        end
        // TODO 计时，用于生成随机初始局面
    end
end

// step_timer 倒计时秒表
logic [26: 0] step_timer_50M;
task step_timer_tick();
    if (step_timer_50M == 'd49_999_999) begin
        step_timer_50M <= 0;
        step_timer     <= step_timer - 1;
    end else begin
        step_timer_50M <= step_timer_50M + 1;
    end
endtask
task step_timer_reset();
    step_timer     <= MAX_STEP_TIME;
    step_timer_50M <= 0;
endtask

// 回合进行中
task automatic in_round();
    // 如果已超时，直接切换回合
    if (step_timer == 0) begin
        state <= ROUND_SWITCH;
    end else begin
    // 如果当前有尚未结算的操作，那么：结算一次操作、将操作队列清空、计时
        if (operation != NONE) begin
            casez (cursor_type)
                CHOOSE: begin
                    casez (operation)
                        W: // 上移
                            if (cursor.v >= 1)                cursor.v <= cursor.v - 1;
                        A: // 左移
                            if (cursor.h >= 1)                cursor.h <= cursor.h - 1;
                        S: // 下移
                            if (cursor.v <= BORAD_WIDTH - 2)  cursor.v <= cursor.v + 1;
                        D: // 右移
                            if (cursor.h <= BORAD_WIDTH - 2)  cursor.h <= cursor.h + 1;
                        Z: ;  // 选择模式下无法切换“全移/半移”
                        SPACE: // 切换“选择模式/行棋模式”
                            if (cells[cursor.h][cursor.v].owner == current_player && 
                                cells[cursor.h][cursor.v].troop >= 2)
                                cursor_type <= MOVE_TOTAL;  // 如果当前格子属于操作方，且兵力至少是 2，从选择模式切换到行棋模式是合法的
                        default: ; // assert 这种情况不应出现
                    endcase
                end
                MOVE_HALF, MOVE_TOTAL: begin
                    // 保证当前格子属于操作方，且兵力至少是 2
                    casez (operation)
                        // 如果当前操作是切换光标模式
                        Z: // 切换“全移/半移”
                            casez(cursor_type)
                                MOVE_HALF:  cursor_type <= MOVE_TOTAL;
                                MOVE_TOTAL: cursor_type <= MOVE_HALF;
                                default:    cursor_type <= MOVE_TOTAL;  // assert 这种情况不应出现
                            endcase
                        SPACE: // 切换“选择模式/行棋模式”
                            cursor_type <= CHOOSE;
                        // 如果当前操作是行棋：
                        // 如果操作合法（在 move_piece_to 中判断），走一步棋并进行胜负判断；否则不做响应
                        W: // 上移
                            if (cursor.v >= 1)
                                move_piece_to('{cursor.h,     cursor.v - 1});
                        A: // 左移
                            if (cursor.h >= 1)
                                move_piece_to('{cursor.h - 1, cursor.v    });
                        S: // 下移
                            if (cursor.v <= BORAD_WIDTH - 2)
                                move_piece_to('{cursor.h,     cursor.v + 1});
                        D: // 右移
                            if (cursor.h <= BORAD_WIDTH - 2)
                                move_piece_to('{cursor.h + 1, cursor.v    });
                        default: ; // assert 这种情况不应出现
                    endcase
                end
                default: ; // assert 这种情况不应出现
            endcase
            // 标记当前操作队列为空
            operation <= NONE;
        end
        // 计时
        step_timer_tick();
    end
endtask

// 判断是否合法并执行一次行棋操作，然后进行胜负判断
task automatic move_piece_to(Position target_pos);
    // 保证当前格子属于操作方，且兵力至少是 2
    // 保证目标位置仍在棋盘内

    // 如果目标位置属于 NPC
    if (cells[target_pos.h][target_pos.v].owner == NPC) begin
        casez (cells[target_pos.h][target_pos.v].piece_type)
            // 如果目标位置是 NPC 空地或 NPC 城市
            TERRITORY, CITY: begin
                if (cursor_type == MOVE_TOTAL) begin
                    update_troop_and_owner(cells[cursor.h][cursor.v].troop - 1,  target_pos);
                end else begin
                    update_troop_and_owner(cells[cursor.h][cursor.v].troop >> 1, target_pos);
                end
                // 接下来进行回合切换
                state <= ROUND_SWITCH;
            end
            // 如果目标位置是山
            MOUNTAIN: ; // 不做响应
            default:  ; // assert 这种情况不应出现
        endcase
    // 如果目标位置属于己方
    end else if (cells[target_pos.h][target_pos.v].owner == current_player) begin
        if (cursor_type == MOVE_TOTAL) begin
            update_troop_and_owner(cells[cursor.h][cursor.v].troop - 1,  target_pos);
        end else begin
            update_troop_and_owner(cells[cursor.h][cursor.v].troop >> 1, target_pos);
        end
        // 接下来进行回合切换
        state <= ROUND_SWITCH;
    // 如果目标位置属于其他玩家
    end else begin
        if (cursor_type == MOVE_TOTAL) begin
            update_troop_and_owner(cells[cursor.h][cursor.v].troop - 1,  target_pos);
        end else begin
            update_troop_and_owner(cells[cursor.h][cursor.v].troop >> 1, target_pos);
        end
        // 接下来进行胜负判断
        state <= CHECK_WIN;
    end
endtask

// 基于派出的兵力，更新源位置和目标位置兵力，并可能更新目标位置归属方
task automatic update_troop_and_owner(logic [LOG2_MAX_TROOP - 1: 0] dispatched_troop, Position target_pos);
    // 如果目标位置属于己方
    if (cells[target_pos.h][target_pos.v].owner == current_player) begin
        cells[target_pos.h][target_pos.v].troop <= cells[target_pos.h][target_pos.v].troop + dispatched_troop;
        cells[cursor.    h][cursor    .v].troop <= cells[cursor.    h][cursor    .v].troop - dispatched_troop;
    // 如果目标位置属于其他玩家，或者目标位置是 NPC 的空地/城市
    end else begin
        // 如果派出的兵力严格大于对方兵力
        if (dispatched_troop > cells[target_pos.h][target_pos.v].troop) begin
            // 目标位置归属方更改
            cells[target_pos.h][target_pos.v].owner <= current_player;
            // 源位置、目标位置兵力更改
            cells[target_pos.h][target_pos.v].troop <= dispatched_troop - cells[target_pos.h][target_pos.v].troop;
            cells[cursor.    h][cursor    .v].troop <= cells[cursor.h][cursor.v].troop - dispatched_troop;
        // 如果派出的兵力不严格大于对方兵力
        end else begin 
            // 仅对源位置、目标位置兵力进行更改，不改变目标位置归属方
            cells[target_pos.h][target_pos.v].troop <= cells[target_pos.h][target_pos.v].troop - dispatched_troop;
            cells[cursor.    h][cursor    .v].troop <= cells[cursor.h][cursor.v].troop - dispatched_troop;
        end
    end
endtask

// 胜负判断，并记录胜者（如果胜负已分）
task automatic check_win();
    // 如果某方王城位置归属不再是自己，游戏结束
    if          (cells[crowns_pos[RED ].h][crowns_pos[RED ].v].owner != RED)  begin
        winner <= BLUE;
        state  <= GAME_OVER;
    end else if (cells[crowns_pos[BLUE].h][crowns_pos[BLUE].v].owner != BLUE) begin
        winner <= RED;
        state  <= GAME_OVER;
    // 否则，游戏继续，进行回合切换
    end else begin
        state <= ROUND_SWITCH;
    end
endtask

// 回合切换
task automatic round_switch();
    // 操作执行完成后
    // 将光标移动到下一回合玩家的王城，光标模式设置为选择模式
    current_player <=            next_player_table[current_player] ;
    cursor         <= crowns_pos[next_player_table[current_player]];
    cursor_type    <= CHOOSE;
    // 更新 step_cnt （round 随之自动更新）
    step_cnt <= step_cnt + 1;
    // 每回合结束时，增加兵力
    if (step_cnt[0] == 1) begin
        // 每 15 回合结束时，所有玩家的格子增加 1 兵力
        if (round[3:0] == 4'b0000) begin
            for (byte h = 0; h < BORAD_WIDTH; ++h) begin
                for (byte v = 0; v < BORAD_WIDTH; ++v) begin
                    if (belong_to_player(h, v)) begin
                        cells[h][v].troop <= cells[h][v].troop + 1;
                    end
                end
            end
        // 如果是普通的回合结束，所有玩家的王城和城市均增加 1 兵力
        end else begin
            for (byte h = 0; h < BORAD_WIDTH; ++h) begin
                for (byte v = 0; v < BORAD_WIDTH; ++v) begin
                    if (is_player_city_or_crown(h, v)) begin
                        cells[h][v].troop <= cells[h][v].troop + 1;
                    end
                end
            end
        end
    end
    // 状态切换到回合中
    state <= IN_ROUND;
    // 重启计时器
    step_timer_reset();
endtask

function automatic logic belong_to_player (logic [LOG2_BORAD_WIDTH - 1: 0] h, logic [LOG2_BORAD_WIDTH - 1: 0] v);
    if (cells[h][v].owner == RED || cells[h][v].owner == BLUE)
        return 1;
    else
        return 0;
endfunction

function automatic logic is_player_city_or_crown (logic [LOG2_BORAD_WIDTH - 1: 0] h, logic [LOG2_BORAD_WIDTH - 1: 0] v);
    if (belong_to_player(h, v) && (cells[h][v].piece_type == CITY || cells[h][v].piece_type == CROWN))
        return 1;
    else 
        return 0;
endfunction

// 等待开始游戏
task automatic ready();
    // 如果此时开始按钮处于按下状态，那么开始游戏
    if (start) begin
        // TODO 生成随机初始局面
        // 各方王城坐标
        crowns_pos[RED]  <= '{'d2, 'd3};
        crowns_pos[BLUE] <= '{'d8, 'd7};
        // 初始化棋盘
        for (int h = 0; h < BORAD_WIDTH; h++) begin
            for (int v = 0; v < BORAD_WIDTH; v++) begin
                // CROWN
                if          (h == crowns_pos[RED ].h && v == crowns_pos[RED ].v) begin
                    cells[h][v] <= '{RED, CROWN, 'd87};
                end else if (h == crowns_pos[BLUE].h && v == crowns_pos[BLUE].v) begin
                    cells[h][v] <= '{BLUE, CROWN, 'd89};
                // NPC
                end else if (v == 5) begin
                    cells[h][v] <= '{NPC, CITY, 'd0};
                end else if (h + v == 9 && h >= 6) begin
                    cells[h][v] <= '{NPC, MOUNTAIN, 'd0};
                // RED
                end else if (2 <= h && h <= 5 && 2 <= v && v <= 5) begin
                    cells[h][v] <= '{RED, CITY, 'd25};
                // BLUE
                end else if (7 <= h && h <= 9 && 5 <= v && v <= 9) begin
                    cells[h][v] <= '{BLUE, CITY, 'd37};
                // NPC TERRITORY
                end else begin
                    cells[h][v] <= '{NPC, TERRITORY, 'd0};
                end
            end
        end

        operation      <= NONE;             // 操作队列初始化为空
        current_player <= Player'(1);       // TODO 先手玩家
        cursor         <= '{'d2, 'd3};      // TODO 坐标在先手玩家的王城
        cursor_type    <= CHOOSE;
        step_cnt       <= 'd0;
        winner         <= NPC;              // 胜者，winner == NPC 表示尚未分出胜负
        // 开始游戏
        state <= IN_ROUND;
        // 重启计时器
        step_timer_reset();
    end
endtask 

//// [游戏逻辑部分 END]



//// [游戏显示部分 BEGIN]
logic [15:0] address;//ram地址
logic [15:0] numaddress;
logic [31:0] bluecity_ramdata;
logic [31:0] bluecrown_ramdata;
logic [31:0] redcity_ramdata;
logic [31:0] redcrown_ramdata;
logic [31:0] mountain_ramdata;
logic [31:0] neutralcity_ramdata;
logic [31:0] blue_ramdata;
logic [31:0] red_ramdata;
logic [31:0] number1_ramdata;
logic [31:0] number0_ramdata;
logic [31:0] number2_ramdata;
logic [31:0] number3_ramdata;
logic [31:0] number4_ramdata;
logic [31:0] number5_ramdata;
logic [31:0] number6_ramdata;
logic [31:0] number7_ramdata;
logic [31:0] number8_ramdata;
logic [31:0] number9_ramdata;
logic [31:0] bignumber0_ramdata;
logic [31:0] bignumber1_ramdata;
logic [31:0] bignumber2_ramdata;
logic [31:0] bignumber3_ramdata;
logic [31:0] bignumber4_ramdata;
logic [31:0] bignumber5_ramdata;
logic [31:0] bignumber6_ramdata;
logic [31:0] bignumber7_ramdata;
logic [31:0] bignumber8_ramdata;
logic [31:0] bignumber9_ramdata;
logic [31:0] white_ramdata;
logic [31:0] numberdata;
logic [31:0] bignumberdata;
logic [31:0] ramdata;//选择后的用作输出的ram数据
logic [31:0] indata = 32'b0;//用于为ram输入赋值（没用）
logic [VGA_WIDTH - 1: 0] vdata_to_ram = 0;//取模后的v
logic [VGA_WIDTH - 1: 0] hdata_to_ram = 0;//取模后的h
logic [LOG2_BORAD_WIDTH - 1:0] cur_v;//从像素坐标转换到数组v坐标
logic [LOG2_BORAD_WIDTH - 1:0] cur_h;//从像素坐标转换到数组h坐标
logic is_gen;
logic [7:0] cur_owner;
logic [7:0] cur_piecetype;
logic [8:0] cur_troop;
logic [3:0] cur_hundreds;
logic [3:0] cur_tens;
logic [3:0] cur_ones;
logic [3:0] big_hundreds;
logic [3:0] big_tens;
logic [3:0] big_ones;
logic [8:0] bignumber;
assign cur_owner = cells[cur_h][cur_v].owner;
assign cur_piecetype = cells[cur_h][cur_v].piece_type;
assign cur_troop = cells[cur_h][cur_v].troop;
int cursor_array [0:9] = '{'d40, 'd80, 'd120, 'd160, 'd200, 'd240, 'd280, 'd320, 'd360, 'd400};
assign address = vdata_to_ram*40 + hdata_to_ram;
assign bignumber = (vdata>100) ? step_timer:round;

always_comb begin
    if((hdata == cursor_array[cursor.h]+1 || hdata == cursor_array[cursor.h]+39 || vdata == cursor_array[cursor.v]+1 || vdata==cursor_array[cursor.v]+39)
    &&(vdata<=cursor_array[cursor.v]+39 && vdata>=cursor_array[cursor.v]+1 && hdata<=cursor_array[cursor.h]+39 && hdata>=cursor_array[cursor.h]+1)) begin
        gen_red = 0;
        gen_green = 255;
        gen_blue = 0;
    end else 
    if ((cursor_type == MOVE_TOTAL || cursor_type == MOVE_HALF)
    && (((hdata == cursor_array[cursor.h]+2 || hdata == cursor_array[cursor.h]+38 || vdata == cursor_array[cursor.v]+2 || vdata==cursor_array[cursor.v]+38)
    &&(vdata<=cursor_array[cursor.v]+38 && vdata>=cursor_array[cursor.v]+2 && hdata<=cursor_array[cursor.h]+38 && hdata>=cursor_array[cursor.h]+2))
    || ((hdata == cursor_array[cursor.h]+3 || hdata == cursor_array[cursor.h]+37 || vdata == cursor_array[cursor.v]+3 || vdata==cursor_array[cursor.v]+37)
    &&(vdata<=cursor_array[cursor.v]+37 && vdata>=cursor_array[cursor.v]+3 && hdata<=cursor_array[cursor.h]+37 && hdata>=cursor_array[cursor.h]+3)))) begin
        gen_red = 0;
        gen_green = 255;
        gen_blue = 0;
    end else
    if (vdata<=440&&vdata>=40&&hdata<=440&&hdata>=40) begin
        gen_red = ramdata[7:0];
        gen_green = ramdata[15:8];
        gen_blue = ramdata[23:16];
    end else 
    if (((vdata <= 80 && vdata > 40) ||(vdata <= 160 && vdata > 120)) && hdata >= 480 && hdata <= 600 && bignumberdata[31:24]!=0) begin
        if (step_timer <= 5 && (vdata <= 160 && vdata > 120)) begin 
            gen_red = 255;
            gen_green = 0;
            gen_blue = 0;
        end
        else begin        
            gen_red = bignumberdata[7:0];
            gen_green = bignumberdata[15:8];
            gen_blue = bignumberdata[23:16];
        end
    end else 
    if ((vdata <= 120 && vdata > 80)&& hdata >= 520 && hdata <= 560 ) begin
        if (current_player == RED) begin
            gen_red = red_ramdata[7:0];
            gen_green = red_ramdata[15:8];
            gen_blue = red_ramdata[23:16];
        end else begin
            gen_red = blue_ramdata[7:0];
            gen_green = blue_ramdata[15:8];
            gen_blue = blue_ramdata[23:16]; 
        end           
    end else begin
        gen_red = 0;
        gen_green = 0;
        gen_blue = 0;
    end
end
always_comb begin
    if (hdata_to_ram <= 17) begin
        numaddress = (vdata_to_ram)*40+hdata_to_ram+6;
    end else if (hdata_to_ram >= 23) begin
        numaddress = (vdata_to_ram)*40+hdata_to_ram-6;
    end else begin 
        numaddress = (vdata_to_ram)*40+hdata_to_ram;
    end
end
//通过打表避免使用除法取模，找到对应ram中的坐标和棋盘坐标
// Coordinate_Transfer #(
//         .VGA_WIDTH(VGA_WIDTH),
//         .LOG2_BORAD_WIDTH(LOG2_BORAD_WIDTH)
//     ) coordinate_transfer_h (
//         .coordinate(hdata),
//         .coordinate_to_ram(hdata_to_ram),
//         .coordinate_in_board(cur_h)
// );
// Coordinate_Transfer #(
//         .VGA_WIDTH(VGA_WIDTH),
//         .LOG2_BORAD_WIDTH(LOG2_BORAD_WIDTH)
//     ) coordinate_transfer_v (
//         .coordinate(vdata),
//         .coordinate_to_ram(vdata_to_ram),
//         .coordinate_in_board(cur_v)
//);
always_comb begin
    if (hdata>=0 && hdata<40) begin
        hdata_to_ram = hdata;
        cur_h = 0;
    end else if (hdata>=40 && hdata<80) begin
        hdata_to_ram = hdata - 40;
        cur_h = 0;
    end else if (hdata>=80 && hdata<120) begin
        hdata_to_ram = hdata - 80;
        cur_h = 1;
    end else if (hdata>=120 && hdata<160) begin
        hdata_to_ram = hdata - 120;
        cur_h = 2;
    end else if (hdata>=160 && hdata<200) begin
        hdata_to_ram = hdata - 160;
        cur_h = 3;
    end else if (hdata>=200 && hdata<240) begin
        hdata_to_ram = hdata - 200;
        cur_h = 4;
    end else if (hdata>=240 && hdata<280) begin
        hdata_to_ram = hdata - 240;
        cur_h = 5;
    end else if (hdata>=280 && hdata<320) begin
        hdata_to_ram = hdata - 280;
        cur_h = 6;
    end else if (hdata>=320 && hdata<360) begin
        hdata_to_ram = hdata - 320;
        cur_h = 7;
    end else if (hdata>=360 && hdata<400) begin
        hdata_to_ram = hdata - 360;
        cur_h = 8;
    end else if (hdata>=400 && hdata<440) begin
        hdata_to_ram = hdata - 400;
        cur_h = 9;
    end else if (hdata>=480 && hdata<520) begin
        hdata_to_ram = hdata - 480;
        cur_h = 0;
    end else if (hdata>=520 && hdata<560) begin
        hdata_to_ram = hdata - 520;
        cur_h = 0;
    end else if (hdata>=560 && hdata<600) begin
        hdata_to_ram = hdata - 560;
        cur_h = 0;
    end else begin
        hdata_to_ram = 0;
        cur_h = 0;
    end
end
always_comb begin
    if (vdata>=0 && vdata<40) begin
        vdata_to_ram = vdata;
        cur_v = 0;
    end else if (vdata>=40 && vdata<80) begin
        vdata_to_ram = vdata - 40;
        cur_v = 0;
    end else if (vdata>=80 && vdata<120) begin
        vdata_to_ram = vdata - 80;
        cur_v = 1;
    end else if (vdata>=120 && vdata<160) begin
        vdata_to_ram = vdata - 120;
        cur_v = 2;
    end else if (vdata>=160 && vdata<200) begin
        vdata_to_ram = vdata - 160;
        cur_v = 3;
    end else if (vdata>=200 && vdata<240) begin
        vdata_to_ram = vdata - 200;
        cur_v = 4;
    end else if (vdata>=240 && vdata<280) begin
        vdata_to_ram = vdata - 240;
        cur_v = 5;
    end else if (vdata>=280 && vdata<320) begin
        vdata_to_ram = vdata - 280;
        cur_v = 6;
    end else if (vdata>=320 && vdata<360) begin
        vdata_to_ram = vdata - 320;
        cur_v = 7;
    end else if (vdata>=360 && vdata<400) begin
        vdata_to_ram = vdata - 360;
        cur_v = 8;
    end else if (vdata>=400 && vdata<440) begin
        vdata_to_ram = vdata - 400;
        cur_v = 9;
    end else begin
        vdata_to_ram = 0;
        cur_v = 0;
    end
end

always_comb begin
    if (hdata_to_ram <= 17) begin
        if (cur_hundreds == 0) begin
            numberdata = number0_ramdata;
        end else if (cur_hundreds == 1) begin
            numberdata = number1_ramdata;
        end else if (cur_hundreds == 2) begin
            numberdata = number2_ramdata;
        end else if (cur_hundreds == 3) begin
            numberdata = number3_ramdata;
        end else if (cur_hundreds == 4) begin
            numberdata = number4_ramdata;
        end else if (cur_hundreds == 5) begin
            numberdata = number5_ramdata;
        end else if (cur_hundreds == 6) begin
            numberdata = number6_ramdata;
        end else if (cur_hundreds == 7) begin
            numberdata = number7_ramdata;
        end else if (cur_hundreds == 8) begin
            numberdata = number8_ramdata;
        end else begin
            numberdata = number9_ramdata;
        end
    end
    else if (hdata_to_ram >= 23) begin
        if (cur_ones == 0) begin
            numberdata = number0_ramdata;
        end else if (cur_ones == 1) begin
            numberdata = number1_ramdata;
        end else if (cur_ones == 2) begin
            numberdata = number2_ramdata;
        end else if (cur_ones == 3) begin
            numberdata = number3_ramdata;
        end else if (cur_ones == 4) begin
            numberdata = number4_ramdata;
        end else if (cur_ones == 5) begin
            numberdata = number5_ramdata;
        end else if (cur_ones == 6) begin
            numberdata = number6_ramdata;
        end else if (cur_ones == 7) begin
            numberdata = number7_ramdata;
        end else if (cur_ones == 8) begin
            numberdata = number8_ramdata;
        end else begin
            numberdata = number9_ramdata;
        end            
    end
    else begin
        if (cur_tens == 0) begin
            numberdata = number0_ramdata;
        end else if (cur_tens == 1) begin
            numberdata = number1_ramdata;
        end else if (cur_tens == 2) begin
            numberdata = number2_ramdata;
        end else if (cur_tens == 3) begin
            numberdata = number3_ramdata;
        end else if (cur_tens == 4) begin
            numberdata = number4_ramdata;
        end else if (cur_tens == 5) begin
            numberdata = number5_ramdata;
        end else if (cur_tens == 6) begin
            numberdata = number6_ramdata;
        end else if (cur_tens == 7) begin
            numberdata = number7_ramdata;
        end else if (cur_tens == 8) begin
            numberdata = number8_ramdata;
        end else begin
            numberdata = number9_ramdata;
        end
    end
end
always_comb begin
    if (hdata<=520 && hdata>=480) begin
        if (big_hundreds == 0) begin
            bignumberdata = bignumber0_ramdata;
        end else if (big_hundreds == 1) begin
            bignumberdata = bignumber1_ramdata;
        end else if (big_hundreds == 2) begin
            bignumberdata = bignumber2_ramdata;
        end else if (big_hundreds == 3) begin
            bignumberdata = bignumber3_ramdata;
        end else if (big_hundreds == 4) begin
            bignumberdata = bignumber4_ramdata;
        end else if (big_hundreds == 5) begin
            bignumberdata = bignumber5_ramdata;
        end else if (big_hundreds == 6) begin
            bignumberdata = bignumber6_ramdata;
        end else if (big_hundreds == 7) begin
            bignumberdata = bignumber7_ramdata;
        end else if (big_hundreds == 8) begin
            bignumberdata = bignumber8_ramdata;
        end else begin
            bignumberdata = bignumber9_ramdata;
        end
    end
    else if (hdata >= 560 && hdata <= 600) begin
        if (big_ones == 0) begin
            bignumberdata = bignumber0_ramdata;
        end else if (big_ones == 1) begin
            bignumberdata = bignumber1_ramdata;
        end else if (big_ones == 2) begin
            bignumberdata = bignumber2_ramdata;
        end else if (big_ones == 3) begin
            bignumberdata = bignumber3_ramdata;
        end else if (big_ones == 4) begin
            bignumberdata = bignumber4_ramdata;
        end else if (big_ones == 5) begin
            bignumberdata = bignumber5_ramdata;
        end else if (big_ones == 6) begin
            bignumberdata = bignumber6_ramdata;
        end else if (big_ones == 7) begin
            bignumberdata = bignumber7_ramdata;
        end else if (big_ones == 8) begin
            bignumberdata = bignumber8_ramdata;
        end else begin
            bignumberdata = bignumber9_ramdata;
        end            
    end
    else begin
        if (big_tens == 0) begin
            bignumberdata = bignumber0_ramdata;
        end else if (big_tens == 1) begin
            bignumberdata = bignumber1_ramdata;
        end else if (big_tens == 2) begin
            bignumberdata = bignumber2_ramdata;
        end else if (big_tens == 3) begin
            bignumberdata = bignumber3_ramdata;
        end else if (big_tens == 4) begin
            bignumberdata = bignumber4_ramdata;
        end else if (big_tens == 5) begin
            bignumberdata = bignumber5_ramdata;
        end else if (big_tens == 6) begin
            bignumberdata = bignumber6_ramdata;
        end else if (big_tens == 7) begin
            bignumberdata = bignumber7_ramdata;
        end else if (big_tens == 8) begin
            bignumberdata = bignumber8_ramdata;
        end else begin
            bignumberdata = bignumber9_ramdata;
        end
    end
end
always_comb begin
    if ((((vdata <= 80 && vdata > 40) ||(vdata <= 160 && vdata > 120)) && hdata >= 480 && hdata <= 600 && bignumberdata[31:24]!=0)
    || ((vdata <= 120 && vdata > 80)&& hdata >= 520 && hdata <= 560 )) begin
        is_gen = 1;
        ramdata = 0;
    end else
    if (cur_troop!=0 && numberdata[31:24] == 255) begin
        is_gen = 1;
        ramdata = numberdata;
    end else 
    if (cur_owner == NPC) begin
        if (cur_piecetype == CITY) begin
            is_gen = 1;
            ramdata = neutralcity_ramdata;
        end else if (cur_piecetype == MOUNTAIN) begin 
            is_gen = 1;
            ramdata = mountain_ramdata;
        end else begin
            is_gen = 0;
            ramdata = 0;
        end
    end else if (cur_owner == RED) begin
        if (cur_piecetype == CROWN) begin
            is_gen = 1;
            ramdata = redcrown_ramdata;
        end else if (cur_piecetype == CITY) begin
            is_gen = 1;
            ramdata = redcity_ramdata;
        end else begin
            is_gen = 1;
            ramdata = red_ramdata;
        end
    end else if (cur_owner == BLUE) begin
        if (cur_piecetype == CROWN) begin
            is_gen = 1;
            ramdata = bluecrown_ramdata;
        end else if (cur_piecetype == CITY) begin
            is_gen = 1;
            ramdata = bluecity_ramdata;
        end else begin
            is_gen = 1;
            ramdata = blue_ramdata;
        end
    end else begin
        is_gen = 0;
        ramdata = 0;
    end
    // is_gen = 1;
    // ramdata = bignumberdata;
    // is_gen = 1;
    // ramdata = 0;
end

// ram_white ram_white (
//     .address(address),
//     .clock(clock),
//     .data(indata),
//     .wren(0),
//     .q(white_ramdata)
// ); 
Number_Transfer  #(
    .BIT(LOG2_MAX_TROOP)
) number_transfer(
    .number(cur_troop),
    .hundreds(cur_hundreds),
    .tens(cur_tens),
    .ones(cur_ones) 
);
Number_Transfer  #(
    .BIT(LOG2_MAX_TROOP)
) number_transfer_round(
    .number(bignumber),
    .hundreds(big_hundreds),
    .tens(big_tens),
    .ones(big_ones) 
);
ram_number0 ram_number0_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number0_ramdata)  
);
ram_number1 ram_number1_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number1_ramdata)  
);
ram_number2 ram_number2_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number2_ramdata)  
);   
ram_number3 ram_number3_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number3_ramdata)  
);  
ram_number4 ram_number4_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number4_ramdata)  
);  
ram_number5 ram_number5test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number5_ramdata)  
);  
ram_number6 ram_number6_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number6_ramdata)  
);  
ram_number7 ram_number7_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number7_ramdata)  
);  
ram_number8 ram_number8_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number8_ramdata)  
);  
ram_number9 ram_number9_test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number9_ramdata)  
);  
ram_bignumber0 ram_bignumber0_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber0_ramdata)
);
ram_bignumber1 ram_bignumber1_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber1_ramdata)
);
ram_bignumber2 ram_bignumber2_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber2_ramdata)
);
ram_bignumber3 ram_bignumber3_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber3_ramdata)
);
ram_bignumber4 ram_bignumber4_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber4_ramdata)
);
ram_bignumber5 ram_bignumber5_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber5_ramdata)
);
ram_bignumber6 ram_bignumber6_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber6_ramdata)
);
ram_bignumber7 ram_bignumber7_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber7_ramdata)
);
ram_bignumber8 ram_bignumber8_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber8_ramdata)
);
ram_bignumber9 ram_bignumber9_test(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber9_ramdata)
);
ram_blue ram_blue_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(blue_ramdata)  
);
ram_bluecity ram_bluecity_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bluecity_ramdata)  
);
ram_bluecrown ram_bluecrown_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bluecrown_ramdata)
);
ram_red ram_red_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(red_ramdata)  
);
ram_redcity ram_redcity_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(redcity_ramdata)
);
ram_redcrown ram_redcrown_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(redcrown_ramdata)
);
ram_neutralcity ram_neutralcity_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(neutralcity_ramdata)
);
ram_mountain ram_mountain_test (
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(mountain_ramdata)
);
always_comb begin
    if (hdata == 40 || hdata==80 || hdata==120 || hdata == 160|| hdata == 200 
       || hdata == 240 || hdata == 280 || hdata == 320 || hdata == 360 || hdata == 400 || hdata == 440 
       || vdata == 40 || vdata == 80 || vdata == 120 || vdata == 160 || vdata == 200 
       || vdata == 240 || vdata == 280 || vdata == 320 || vdata == 360 || vdata == 400 || vdata == 440) begin
        use_gen = 0;
    end 
    else if((hdata == cursor_array[cursor.h]+1 || hdata == cursor_array[cursor.h]+39 || vdata == cursor_array[cursor.v]+1 || vdata==cursor_array[cursor.v]+39)
    &&(vdata<=cursor_array[cursor.v]+39 && vdata>=cursor_array[cursor.v]+1 && hdata<=cursor_array[cursor.h]+39 && hdata>=cursor_array[cursor.h]+1)) begin
        use_gen = 1;
    end else if (is_gen) begin
        use_gen = 1;
    end else begin
        use_gen = 0;
    end
end
//// [游戏显示部分 END]

endmodule