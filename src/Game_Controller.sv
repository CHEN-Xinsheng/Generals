module Game_Controller
#(parameter VGA_WIDTH            = 0, 
            BORAD_WIDTH          = 10, 
            LOG2_BORAD_WIDTH     = 4, 
            MAX_PLAYER_CNT       = 7, 
            LOG2_MAX_PLAYER_CNT  = 3, 
            LOG2_PIECE_TYPE_CNT  = 2, 
            LOG2_MAX_TROOP       = 9, 
            LOG2_MAX_ROUND       = 12,
            ROUND_LIMIT          = 999,
            LOG2_MAX_CURSOR_TYPE = 2,
            MAX_STEP_TIME        = 15,
            LOG2_MAX_STEP_TIME   = 5,
            MAX_RANDOM_BOARD     = 128) (
    //// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
    output wire [LOG2_BORAD_WIDTH - 1: 0]           cursor_h_o_test,                // 当前光标位置的横坐标（h 坐标）
    output wire [LOG2_BORAD_WIDTH - 1: 0]           cursor_v_o_test,                // 当前光标位置的纵坐标（v 坐标）
    output wire [LOG2_MAX_TROOP - 1: 0]             troop_o_test,                   // 当前格兵力
    output wire [LOG2_MAX_PLAYER_CNT - 1: 0]        owner_o_test,                   // 当前格归属方
    output wire [LOG2_PIECE_TYPE_CNT - 1: 0]        piece_type_o_test,              // 当前格棋子类型
    output wire [LOG2_MAX_PLAYER_CNT - 1: 0]        current_player_o_test,          // 当前回合玩家
    output wire [LOG2_MAX_PLAYER_CNT - 1: 0]        next_player_o_test,             // 下一回合玩家
    output wire [LOG2_MAX_CURSOR_TYPE -1: 0]        cursor_type_o_test,             // 当前光标类型
    output wire [2: 0]                              operation_o_test,               // 当前操作队列
    output wire [LOG2_MAX_STEP_TIME -1: 0]          step_timer_o_test,              // 当前回合剩余时间
    output wire [LOG2_MAX_ROUND - 1: 0]             round_o_test,                   // 当前回合数
    output wire [$clog2(MAX_RANDOM_BOARD) - 1: 0]   chosen_random_board_o_test,     // 随机产生的初始棋盘序号
    output wire [2: 0]                              state_o_test,                   // 游戏当前状态
    output wire [11:0]                              init_board_address_o_test,      // 当前读到初始棋盘 MIF 文件的地址，仅用于测试初始棋盘载入
    output wire [LOG2_MAX_PLAYER_CNT - 1:0]         winner_o_test,                  // 胜者
    //// [TEST END]

    //// input
    input wire                    clock,
    input wire                    clock_random_first_player,
    input wire                    start,              // 游戏开始
    input wire                    reset,
    input wire                    clk_vga,
    // 与 Keyboard_Decoder 交互：获取键盘操作信号 
    input wire                    keyboard_ready,
    input wire [2: 0]             keyboard_data,

    // 与 Screen_Controller（的 vga 模块）交互： 获取当前的横纵坐标
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
// 棋子类型
typedef enum logic [LOG2_PIECE_TYPE_CNT - 1:0]    {TERRITORY,           MOUNTAIN,    CROWN,   CITY      } Piece;
                                                // 普通领地（含空白格）， 山，         王城，    塔（城市）
// 单元格结构体
typedef struct packed {
    Player                        owner;        // 该格子归属方
    Piece                         piece_type;   // 该棋子类型
    reg [LOG2_MAX_TROOP - 1: 0]   troop;        // 该格子兵力值
} Cell;
// 平面坐标结构体
typedef struct packed {
    logic [LOG2_BORAD_WIDTH - 1: 0]  h;         // 位置的横坐标（h 坐标）
    logic [LOG2_BORAD_WIDTH - 1: 0]  v;         // 位置的纵坐标（v 坐标）
} Position;
// 光标类型
typedef enum logic [LOG2_MAX_CURSOR_TYPE - 1:0] {
    CHOOSE     = 2'b00,
    MOVE_TOTAL = 2'b10,
    MOVE_HALF  = 2'b11
} Cursor_Type;
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
    READY,              // 游戏准备开始
    LOAD_INIT_BOARD,    // 载入初始棋盘
    ABOUT_TO_START,     // 初始棋盘载入完毕，初始化游戏数据
    IN_ROUND,           // 回合内
    CHECK_WIN,          // 判断胜负
    ROUND_SWITCH,       // 回合切换中
    GAME_OVER           // 游戏结束
} State;


// 游戏数据
Cell     [BORAD_WIDTH - 1: 0][BORAD_WIDTH - 1: 0] cells;        // 棋盘结构体数组
Position [MAX_PLAYER_CNT - 1:0]                   crowns_pos ;  // 每个玩家王城的位置

Operation                               operation;              // 最新一次操作。 operation == NONE 表示最近一次操作已被结算，否则尚未结算
Player                                  current_player;         // 当前玩家
Position                                cursor;                 // 当前光标位置
Cursor_Type                             cursor_type;            // 光标所处模式：选择模式(0x)，行棋模式(1x)
logic [LOG2_MAX_ROUND:     0]           step_cnt;               // 已经进行的行棋操作次数（包括超时，视为空操作）
logic [LOG2_MAX_ROUND - 1: 0]           round;                  // 当前回合（从 1 开始）
Player                                  winner;                 // 胜者
State                                   state;                  // 当前游戏状态
logic [LOG2_MAX_STEP_TIME -1: 0]        step_timer;             // 当前回合剩余时间

assign round = (step_cnt >> 1) + 1;

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

// 初始游戏界面（按下 RESET 前）显示的数据
initial begin
    // 初始游戏状态为等待开始
    state = READY;
    // 初始化棋盘。之后在随机生成开局棋盘时，未被填充的位置均为空格
    for (int h = 0; h < BORAD_WIDTH; h++) begin
        for (int v = 0; v < BORAD_WIDTH; v++) begin
            cells[h][v] = '{NPC, TERRITORY, 'h0};
        end
    end
    // assert 以下值不会用到，因为在游戏开始时 (task ready() 中) 会被重写
    crowns_pos[RED]  = '{'d2, 'd3};
    crowns_pos[BLUE] = '{'d8, 'd7};
    operation      = NONE;          // 初始界面不显示
    current_player = Player'(1);
    cursor         = '{'d0, 'd0};
    cursor_type    = CHOOSE;
    winner         = NPC;           // 初始界面不显示
    step_cnt       = 'd0;
    step_timer     = MAX_STEP_TIME;
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
assign round_o_test          = round;                                   // 当前回合数
assign state_o_test          = state;                                   // 游戏当前状态
assign winner_o_test         = winner;                                  // 胜者
// assign init_board_address_o_test = init_board_address;                  // 在初始地图库中，当前读到的地址
// [TEST END]

//// [游戏内部数据 END]


//// [游戏逻辑部分 BEGIN]
// 与键盘输入模块交互+游戏逻辑部分 顶层 always 块
always_ff @ (posedge clock, posedge reset) begin
    if (reset) begin
        state <= READY;
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
                READY:              ready();
                LOAD_INIT_BOARD:    load_init_board();
                ABOUT_TO_START:     about_to_start();
                IN_ROUND:           in_round();
                CHECK_WIN:          check_win();
                ROUND_SWITCH:       round_switch();
                GAME_OVER:          ;
                default: ; // assert 这种情况不应出现
            endcase
        end
    end
end

// step_timer 倒计时秒表
logic [26: 0] step_timer_50M;
task step_timer_tick();
    if (step_timer_50M == 50_000_000 - 1) begin
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
    // 如果已超时，仍先要判断胜负（因为可能已经达到最大回合数）
    if (step_timer == 0) begin
        state <= CHECK_WIN;
    end else begin
        // 计时
        step_timer_tick();
        // 如果当前有尚未结算的操作，那么：结算一次操作、将操作队列清空
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
                // 接下来进行胜负判断
                state <= CHECK_WIN;
            end
            // 如果目标位置是山
            MOUNTAIN: ; // 不做响应
            default:  ; // assert 这种情况不应出现
        endcase
    // 如果目标位置属于玩家
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
    // 否则，如果已经达到回合上限，游戏结束，并根据王城兵力决定胜负
    end else if (step_cnt[0] == 1 && round == ROUND_LIMIT) begin
        if          (cells[crowns_pos[RED ].h][crowns_pos[RED ].v].troop > cells[crowns_pos[BLUE].h][crowns_pos[BLUE].v].troop) begin
            winner <= RED;
            state  <= GAME_OVER;
        end else if (cells[crowns_pos[BLUE].h][crowns_pos[BLUE].v].troop > cells[crowns_pos[RED ].h][crowns_pos[RED ].v].troop) begin
            winner <= BLUE;
            state  <= GAME_OVER;
        end else begin
            winner <= NPC;    // 判定为平局
            state  <= GAME_OVER;
        end
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
        // 每 16 回合结束时，所有玩家的格子增加 1 兵力
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


// 抽签器（循环计数器），用于生成随机初始局面
logic [$clog2(MAX_RANDOM_BOARD) - 1: 0] random_board;
Counter #(.BIT_WIDTH($clog2(MAX_RANDOM_BOARD))) counter_random_board (
    // input
    .clock      (clock),
    .reset      (reset),
    // output
    .number_o   (random_board)
);
// // [TEST BEGIN] 设置固定的初始棋盘序号，用于测试指定棋盘
// assign random_board = 'h3d;
// // [TEST END]
// [TEST BEGIN] 输出随机选中的初始棋盘序号
logic [$clog2(MAX_RANDOM_BOARD) - 1: 0] chosen_random_board;
assign chosen_random_board_o_test = chosen_random_board;
// [TEST END]


// 等待开始游戏
task automatic ready();
    // 如果此时开始按钮处于按下状态，那么生成随机数，并开始载入初始棋盘
    if (start) begin
        // 清空棋盘
        cells <= '{default: '{ default: '{NPC, TERRITORY, 9'd0}}};
        // 准备开始载入初始棋盘
        init_board_address <= random_board << 5;  // 每张地图占 32 word，所以第 random_timer 的起始地址是 32 * random_timer
        read_word_cnt      <= 0;
        state <= LOAD_INIT_BOARD;
        // [TEST BEGIN] 记录随机产生的初始棋盘序号
        chosen_random_board <= random_board;
        // [TEST END]
    end
endtask 


// 从初始棋盘库中读取初始棋盘
logic [$clog2(MAX_RANDOM_BOARD) + 5 - 1:0]  init_board_address;     // MAX_RANDOM_BOARD 张初始地图，每张 32 个word，所以 word 总数（即地址大小）是 32*MAX_RANDOM_BOARD
byte  read_word_cnt;        // 当前已经读的 word 个数
logic [LOG2_BORAD_WIDTH - 1: 0] init_board_h;
logic [LOG2_BORAD_WIDTH - 1: 0] init_board_v;
logic [1: 0]                    init_board_type;
typedef enum logic [1: 0] {
    NPC_MOUNTAIN = 2'b00,
    NPC_CITY     = 2'b01,
    RED_CROWN    = 2'b10,
    BLUE_CROWN   = 2'b11 
} Init_Board_Type;

Random_Boards_Library #(.WORDS_CNT(32*MAX_RANDOM_BOARD)) random_boards_library (
    .address    (init_board_address),  // 读的地址
    .h          (init_board_h),
    .v          (init_board_v),
    .piece_type (init_board_type)
);

// Random_Boards random_boards (
//     .address (init_board_address),  // 读写操作的地址
//     .clock   (clock),               // 读写时钟
//     .data    (0),                   // 写入的数据，选择不写入(0)，故此位无意义
//     .wren    (0),                   // 是否写入
//     .q       (init_board_data)      // 读出的数据
// );
// assign init_board_h    = init_board_data[9:6];
// assign init_board_v    = init_board_data[5:2];
// assign init_board_type = init_board_data[1:0];


// 载入初始棋盘
task automatic load_init_board();
    // 如果初始棋盘尚未读完
    if (read_word_cnt < 32) begin
        // 读出 1 word 的数据，对应棋盘中的一个“特殊元素”（王城/山/NPC城市）
        // 不处理占位符：(h, v) = (0xF, 0xF) 表示这个 word 是占位符，仅用于将该棋盘填充至 32 word，故此情况不处理
        if (!(init_board_h == 'hF && init_board_v == 'hF)) begin
            casez (init_board_type)
                NPC_MOUNTAIN:
                    cells[init_board_h][init_board_v] <= '{NPC,  MOUNTAIN, 0};
                NPC_CITY:
                    cells[init_board_h][init_board_v] <= '{NPC,  CITY,     0};
                RED_CROWN:  begin 
                    cells[init_board_h][init_board_v] <= '{RED,  CROWN,    9};
                    crowns_pos[RED ] <= '{init_board_h, init_board_v};
                end
                BLUE_CROWN: begin
                    cells[init_board_h][init_board_v] <= '{BLUE, CROWN,    9};
                    crowns_pos[BLUE] <= '{init_board_h, init_board_v};
                end
                default: ;  // assert 这种情况不应出现
            endcase
        end
        // 下一周期的读地址 + 1 word
        init_board_address <= init_board_address + 1;
        read_word_cnt      <= read_word_cnt + 1;
    // 如果初始棋盘已经加载完毕
    end else begin
        // 转到 ABOUT_TO_START 状态，初始化其他游戏数据（然后将开始游戏）
        state <= ABOUT_TO_START;
    end
endtask


// 抽签器（循环计数器），用于抽签产生初始玩家
logic random_first_player;
Counter #(.BIT_WIDTH(1)) counter_random_first_player(
    // input
    .clock      (clock_random_first_player),
    .reset      (reset),
    // output
    .number_o   (random_first_player)
);
// （初始棋盘已载入完毕）初始化游戏数据，然后开始游戏
task automatic about_to_start();
    // 操作队列初始化为空
    operation      <= NONE;
    // 随机产生先手玩家
    if (random_first_player == 0)
        current_player <= RED;
    else 
        current_player <= BLUE;
    // 初始坐标在先手玩家的王城
    if (random_first_player == 0) 
        cursor <= crowns_pos[RED];
    else 
        cursor <= crowns_pos[BLUE];

    cursor_type    <= CHOOSE;
    winner         <= NPC;     // 胜者，该值仅当 state == GAME_OVER 时有效
    step_cnt       <= 'd0;
    // 开始游戏
    state <= IN_ROUND;
    // 重启计时器
    step_timer_reset();
endtask

//// [游戏逻辑部分 END]



//// [游戏显示部分 BEGIN]
logic [15:0] address;//ram地址
logic [15:0] numaddress;//兵力数字地址
logic [15:0] winneraddress;//胜利文字地址
logic [31:0] bluecity_ramdata;
logic [31:0] bluecrown_ramdata;
logic [31:0] redcity_ramdata;
logic [31:0] redcrown_ramdata;
logic [31:0] mountain_ramdata;
logic [31:0] neutralcity_ramdata;
logic [31:0] blue_ramdata;
logic [31:0] red_ramdata;//棋子类型
logic [31:0] percent_ramdata;//分兵50%模式显示
logic [31:0] winner_ramdata;//胜利文字
logic [31:0] draw_ramdata;//平局文字
logic [31:0] numberdata;//兵力数字（选择后）
logic [31:0] bignumberdata;//回合与计时数字（选择后）
logic [31:0] ramdata;//选择后的用作输出的ram数据
logic [31:0] indata = 32'b0;//用于为ram输入赋值（没用）
logic [VGA_WIDTH - 1: 0] vdata_to_ram = 0;//取模后的v
logic [VGA_WIDTH - 1: 0] hdata_to_ram = 0;//取模后的h
logic [VGA_WIDTH - 1: 0] winner_hdata_to_ram = 0;//取模后的h
logic [LOG2_BORAD_WIDTH - 1:0] cur_v;//从像素坐标转换到数组v坐标
logic [LOG2_BORAD_WIDTH - 1:0] cur_h;//从像素坐标转换到数组h坐标
logic [7:0] cur_owner;//当前格归属
logic [7:0] cur_piecetype;//当前格种类
logic [8:0] cur_troop;//当前格兵力
logic [3:0] cur_hundreds;//兵力百位
logic [3:0] cur_tens;//兵力十位
logic [3:0] cur_ones;//兵力个位
logic [3:0] big_hundreds;//回合或计时百位
logic [3:0] big_tens;//回合或计时十位
logic [3:0] big_ones;//回合或计时个位
logic [8:0] bignumber;//回合或计时
assign cur_owner = cells[cur_h][cur_v].owner;
assign cur_piecetype = cells[cur_h][cur_v].piece_type;
assign cur_troop = cells[cur_h][cur_v].troop;
int cursor_array [0:9] = '{'d40, 'd80, 'd120, 'd160, 'd200, 'd240, 'd280, 'd320, 'd360, 'd400};//打表避免乘法
assign address = vdata_to_ram*40 + hdata_to_ram;
assign winneraddress = vdata_to_ram*120 + winner_hdata_to_ram;
assign bignumber = (vdata>100) ? step_timer:round;

// 主逻辑，用于生成gen_rgb（即游戏逻辑模块生成的图像）
always_comb begin
    //光标模式绿色边框
    if((hdata == cursor_array[cursor.h]+1 || hdata == cursor_array[cursor.h]+39 || vdata == cursor_array[cursor.v]+1 || vdata==cursor_array[cursor.v]+39)
        &&(vdata<=cursor_array[cursor.v]+39 && vdata>=cursor_array[cursor.v]+1 && hdata<=cursor_array[cursor.h]+39 && hdata>=cursor_array[cursor.h]+1)) begin
        gen_red = 0;
        gen_green = 255;
        gen_blue = 0;
    //选中模式厚绿色边框 
    end else if ((cursor_type == MOVE_TOTAL || cursor_type == MOVE_HALF)
        && (( (hdata == cursor_array[cursor.h]+2 || hdata == cursor_array[cursor.h]+38 || vdata == cursor_array[cursor.v]+2 || vdata==cursor_array[cursor.v]+38)
                &&(vdata<=cursor_array[cursor.v]+38 && vdata>=cursor_array[cursor.v]+2 && hdata<=cursor_array[cursor.h]+38 && hdata>=cursor_array[cursor.h]+2))
           || ((hdata == cursor_array[cursor.h]+3 || hdata == cursor_array[cursor.h]+37 || vdata == cursor_array[cursor.v]+3 || vdata==cursor_array[cursor.v]+37)
                &&(vdata<=cursor_array[cursor.v]+37 && vdata>=cursor_array[cursor.v]+3 && hdata<=cursor_array[cursor.h]+37 && hdata>=cursor_array[cursor.h]+3)))) begin
        gen_red = 0;
        gen_green = 255;
        gen_blue = 0;
    //棋子内容
    end else if (vdata <= 440 && vdata >= 40 && hdata <= 440 && hdata >= 40) begin
        gen_red = ramdata[7:0];
        gen_green = ramdata[15:8];
        gen_blue = ramdata[23:16];
    //回合与计时
    end else if (((vdata <= 80 && vdata > 40) || (vdata <= 160 && vdata > 120)) && hdata >= 480 && hdata <= 600 && bignumberdata[31:24]!=0) begin
        //时间<=5s，变成红色
        if (step_timer <= 5 && (vdata <= 160 && vdata > 120)) begin 
            gen_red = 255;
            gen_green = 0;
            gen_blue = 0;
        end else begin        
            gen_red = bignumberdata[7:0];
            gen_green = bignumberdata[15:8];
            gen_blue = bignumberdata[23:16];
        end
    //胜者图标 
    end else if ((vdata <= 240 && vdata > 200) && hdata >= 480 && hdata <= 600 && state == GAME_OVER) begin
        if (winner != NPC && winner_ramdata[31:24]>=128) begin
            gen_red = winner_ramdata[7:0];
            gen_green = winner_ramdata[15:8];
            gen_blue = winner_ramdata[23:16];
        end else if (winner == NPC && draw_ramdata[31:24]>=128) begin
            gen_red = draw_ramdata[7:0];
            gen_green = draw_ramdata[15:8];
            gen_blue = draw_ramdata[23:16];
        end else begin
            gen_red = 0;
            gen_green = 0;
            gen_blue = 0; 
        end
    //当前玩家图标
    end else if ((vdata <= 120 && vdata > 80)&& hdata >= 520 && hdata <= 560 ) begin
        if (current_player == RED) begin
            gen_red = red_ramdata[7:0];
            gen_green = red_ramdata[15:8];
            gen_blue = red_ramdata[23:16];
        end else begin
            gen_red = blue_ramdata[7:0];
            gen_green = blue_ramdata[15:8];
            gen_blue = blue_ramdata[23:16]; 
        end     
    //胜利或平局文字
    end else if ((vdata <= 280 && vdata > 240)&& hdata >= 520 && hdata <= 560 && state == GAME_OVER) begin
        if (winner == RED) begin
            gen_red = red_ramdata[7:0];
            gen_green = red_ramdata[15:8];
            gen_blue = red_ramdata[23:16];
        end else if (winner == BLUE) begin
            gen_red = blue_ramdata[7:0];
            gen_green = blue_ramdata[15:8];
            gen_blue = blue_ramdata[23:16]; 
        end else begin
            gen_red = 0;
            gen_green = 0;
            gen_blue = 0; 
        end 
    //默认情况，正常不出现  
    end else begin
        gen_red = 0;
        gen_green = 0;
        gen_blue = 0;
    end
end
// 数字选择
Number_Choose#(
    .VGA_WIDTH(VGA_WIDTH),
    .LOG2_BORAD_WIDTH(LOG2_BORAD_WIDTH)
) number_choose(
    .hdata(hdata),
    .vdata(vdata),
    .cur_ones(cur_ones),
    .cur_tens(cur_tens),
    .cur_hundreds(cur_hundreds),
    .big_ones(big_ones),
    .big_tens(big_tens),
    .big_hundreds(big_hundreds),
    .clock(clock),
    .vdata_to_ram(vdata_to_ram),
    .hdata_to_ram(hdata_to_ram),
    .bignumberdata(bignumberdata),
    .cur_h(cur_h),
    .cur_v(cur_v),
    .numberdata(numberdata)
);

// 胜者显示
always_comb begin
    if (hdata>=480 && hdata<=600) begin
        winner_hdata_to_ram = hdata - 480;
    end else begin
        winner_hdata_to_ram = 0;
    end
end


// 数字转换，将三位数字转换为百位十位个位
Number_Transfer  #(
    .BIT(LOG2_MAX_TROOP)
) number_transfer_troop(
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

// use_gen传递，用于给下游的 Screen_Controller 判断使用背景图像（空白格）还是gen_rgb（本游戏模块产生的图像）
always_comb begin
    //各自边框
    if (hdata == 40 || hdata==80 || hdata==120 || hdata == 160|| hdata == 200 
       || hdata == 240 || hdata == 280 || hdata == 320 || hdata == 360 || hdata == 400 || hdata == 440 
       || vdata == 40 || vdata == 80 || vdata == 120 || vdata == 160 || vdata == 200 
       || vdata == 240 || vdata == 280 || vdata == 320 || vdata == 360 || vdata == 400 || vdata == 440) begin
        use_gen = 0;
        ramdata = 0;
    //光标位置 
    end else if((hdata == cursor_array[cursor.h]+1 || hdata == cursor_array[cursor.h]+39 || vdata == cursor_array[cursor.v]+1 || vdata==cursor_array[cursor.v]+39)
            &&(vdata<=cursor_array[cursor.v]+39 && vdata>=cursor_array[cursor.v]+1 && hdata<=cursor_array[cursor.h]+39 && hdata>=cursor_array[cursor.h]+1)) begin
        use_gen = 1;
        ramdata = 0;
    //右侧信息栏
    end else if ((((vdata <= 80 && vdata > 40) || (vdata <= 160 && vdata > 120)) && hdata >= 480 && hdata <= 600 && bignumberdata[31:24]!=0)
        || ((vdata <= 120 && vdata > 80) && hdata >= 520 && hdata <= 560 ) 
        || ((vdata <= 280 && vdata > 240) && hdata >= 520 && hdata <= 560 )
        || ((vdata <= 240 && vdata > 200) && hdata >= 480 && hdata <= 600 )) begin
        use_gen = 1;
        ramdata = 0;
    //以下全部为棋子显示
    //50%模式
    end else if (cursor_type == MOVE_HALF && cur_h == cursor.h && cur_v == cursor.v && percent_ramdata[31:24] >= 128) begin
        use_gen = 1;
        ramdata = percent_ramdata;
    //兵力
    end else if (cur_troop!=0 && numberdata[31:24] >=128 && !(cursor_type == MOVE_HALF && cur_h == cursor.h && cur_v == cursor.v)) begin
        use_gen = 1;
        ramdata = numberdata;
    //归属方为NPC
    end else if (cur_owner == NPC) begin
        if (cur_piecetype == CITY) begin
            use_gen = 1;
            ramdata = neutralcity_ramdata;
        end else if (cur_piecetype == MOUNTAIN) begin 
            use_gen = 1;
            ramdata = mountain_ramdata;
        end else begin
            use_gen = 0;
            ramdata = 0;
        end
    //归属方为红方
    end else if (cur_owner == RED) begin
        if (cur_piecetype == CROWN) begin
            use_gen = 1;
            ramdata = redcrown_ramdata;
        end else if (cur_piecetype == CITY) begin
            use_gen = 1;
            ramdata = redcity_ramdata;
        end else begin
            use_gen = 1;
            ramdata = red_ramdata;
        end
    //归属方为蓝方
    end else if (cur_owner == BLUE) begin
        if (cur_piecetype == CROWN) begin
            use_gen = 1;
            ramdata = bluecrown_ramdata;
        end else if (cur_piecetype == CITY) begin
            use_gen = 1;
            ramdata = bluecity_ramdata;
        end else begin
            use_gen = 1;
            ramdata = blue_ramdata;
        end
    //默认情况
    end else begin
        use_gen = 0;
        ramdata = 0;
    end
end
//以下为ram读取
ram_blue ram_blue ( // 蓝色块（代表蓝方玩家），用于显示当前玩家和胜者
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(blue_ramdata)  
);
ram_bluecity ram_bluecity ( // 蓝方城市
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bluecity_ramdata)  
);
ram_bluecrown ram_bluecrown ( // 蓝方王城
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bluecrown_ramdata)
);
ram_red ram_red ( // 红色块（代表红方玩家），用于显示当前玩家和胜者
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(red_ramdata)  
);
ram_redcity ram_redcity ( // 红方城市
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(redcity_ramdata)
);
ram_redcrown ram_redcrown ( // 红方王城
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(redcrown_ramdata)
);
ram_neutralcity ram_neutralcity ( // NPC 城市
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(neutralcity_ramdata)
);
ram_mountain ram_mountain ( // NPC 山（即障碍物）
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(mountain_ramdata)
);
ram_50percent ram_50percent ( // 显示当前行棋模式为派出 50% 兵力的图片
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(percent_ramdata)
);
ram_winner ram_winner ( // 显示胜利的图片
    .address(winneraddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(winner_ramdata)
);
ram_draw ram_draw (  // 显示平局的图片
    .address(winneraddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(draw_ramdata)
);

//// [游戏显示部分 END]

endmodule