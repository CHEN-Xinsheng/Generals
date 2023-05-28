module Game_Player
#(parameter VGA_WIDTH           = 0, 
            BORAD_WIDTH         = 10, 
            LOG2_BORAD_WIDTH    = 4, 
            MAX_PLAYER_CNT      = 7, 
            LOG2_MAX_PLAYER_CNT = 3, 
            LOG2_PIECE_TYPE_CNT = 2, 
            LOG2_MAX_TROOP      = 9, 
            LOG2_MAX_ROUND      = 12) (
    //// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
    output wire [LOG2_BORAD_WIDTH - 1: 0]   cursor_h_o_test,         // 当前光标位置的横坐标（h 坐标）
    output wire [LOG2_BORAD_WIDTH - 1: 0]   cursor_v_o_test,         // 当前光标位置的纵坐标（v 坐标）
    output wire [LOG2_MAX_TROOP - 1: 0]     troop_o_test,            // 当前格兵力
    output wire [LOG2_MAX_PLAYER_CNT - 1:0] owner_o_test,            // 当前格归属方
    output wire [LOG2_PIECE_TYPE_CNT - 1:0] piece_type_o_test,       // 当前格棋子类型
    output wire [LOG2_MAX_PLAYER_CNT - 1:0] current_player_o_test,   // 当前回合玩家
    output wire [LOG2_MAX_PLAYER_CNT - 1:0] next_player_o_test,      // 下一回合玩家
    output wire [1: 0]                      cursor_type_o_test,      // 当前光标类型
    //// [TEST END]

    //// input
    input wire                    clk_100M,
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
typedef enum logic [1:0] {
    CHOOSE     = 2'b00,
    MOVE_TOTAL = 2'b10,
    MOVE_HALF  = 2'b11
} Cursor_type;
// 键盘操作类型
typedef enum logic[2:0]  {
    W     = 3'b000, 
    A     = 3'b001, 
    S     = 3'b010, 
    D     = 3'b011, 
    SPACE = 3'b100, 
    Z     = 3'b101, 
    NONE  = 3'b110   // 表示没有操作
} Operation;


// 游戏数据
Cell      cells      [BORAD_WIDTH - 1: 0][BORAD_WIDTH - 1: 0];  // 棋盘结构体数组
Position  crowns_pos [MAX_PLAYER_CNT - 1:0];        // 每个玩家王城的位置

Operation                     operation;            // 最新一次操作。 operation == NONE 表示最近一次操作已被结算，否则尚未结算
Player                        current_player;       // 当前玩家
Position                      cursor;               // 当前光标位置
Cursor_type                   cursor_type;          // 光标所处模式：选择模式(0x)，行棋模式(1x)
logic    [LOG2_MAX_ROUND: 0]  round;                // 当前回合（从 1 开始）
Player                        winner;               // 胜者


// 游戏常数：玩家顺序表
Player  next_player_table [MAX_PLAYER_CNT - 1:0];   // 每个玩家的下一玩家
initial begin
    next_player_table[RED]  = BLUE;
    next_player_table[BLUE] = RED;
    // default case
    for (int i = 0; i < MAX_PLAYER_CNT; ++i) begin
        if (i != RED && i != BLUE) begin
            next_player_table[i] = NPC;   // assert 这种情况在游戏中不会出现
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
    round          = 'd1;               // 初始回合（从 1 开始）
    winner         = NPC;               // 胜者，winner == NPC 表示尚未分出胜负
end

// [TEST BEGIN] 将游戏内部数据输出用于测试，以 '_o_test' 作为后缀
assign cursor_h_o_test       = cursor.h;                                   // 当前光标位置的横坐标（h 坐标）
assign cursor_v_o_test       = cursor.v;                                   // 当前光标位置的纵坐标（v 坐标）
assign troop_o_test          = cells[cursor.h][cursor.v].troop;            // 当前格兵力
assign owner_o_test          = cells[cursor.h][cursor.v].owner;            // 当前格归属方
assign piece_type_o_test     = cells[cursor.h][cursor.v].piece_type;       // 当前格棋子类型
assign current_player_o_test = current_player;                             // 当前回合玩家
assign next_player_o_test    = next_player_table[current_player];          // 下一回合玩家
assign cursor_type_o_test    = cursor_type;                                // 当前光标类型
// [TEST END]

//// [游戏内部数据 END]


//// 与键盘输入模块交互+游戏逻辑部分 顶层 always 块
always_ff @ (posedge clk_100M) begin
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
        game_logic_top();
    end
end


//// [游戏逻辑部分 BEGIN]
// 游戏逻辑部分顶层 task
task automatic game_logic_top();
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
            MOVE_HALF || MOVE_TOTAL: begin
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
                        // // 如果操作合法，胜负判断
                        // if (check_win()) begin
                        //     // 如果已分出胜负，那么标记游戏结束
                        //     game_over();
                        // end else begin
                        //     // 如果未分出胜负，回合切换
                        //     round_switch();
                        // end
                    default: ; // assert 这种情况不应出现
                endcase
            end
            default: ; // assert 这种情况不应出现
        endcase
        // 标记当前操作队列为空
        operation <= NONE;
    end
endtask


// 判断是否合法并执行一次行棋操作，然后进行胜负判断
task automatic move_piece_to(Position target_pos);
    // 保证目标位置仍在棋盘内
    casez (cells[target_pos.h][target_pos.v].owner)
        // 如果目标位置属于 NPC
        NPC:
            casez (cells[target_pos.h][target_pos.v].piece_type)
                // 如果目标位置是 NPC 空地或 NPC 城市
                TERRITORY, CITY: begin
                    // 目标位置归属方、兵力更改，源位置兵力更改
                    cells[target_pos.h][target_pos.v].owner <= current_player;
                    if (cursor_type == MOVE_TOTAL) begin
                        cells[target_pos.h][target_pos.v].troop <= cells[cursor.h][cursor.v].troop - 1;
                        cells[cursor.    h][cursor    .v].troop <= 1;
                    end else begin
                        cells[target_pos.h][target_pos.v].troop <= cells[cursor.h][cursor.v].troop >> 1;
                        cells[cursor.    h][cursor    .v].troop <= cells[cursor.h][cursor.v].troop - (cells[cursor.h][cursor.v].troop >> 1);
                    end
                    // 不需要移动光标（光标将自动切换到下一回合玩家的王城）
                end
                // 如果目标位置是山
                MOUNTAIN:
                    ;  // 不做响应
                default:
                    ; // assert 这种情况不应出现
            endcase
        
        // TODO
        // 如果目标位置属于己方
        RED:
            ;
        BLUE:
            ;
        default:
            ; // assert 这种情况不应出现
    endcase
endtask

// 回合切换
task automatic round_switch();
    // 操作执行完成后
    // 将光标移动到下一回合玩家的王城
    current_player <=            next_player_table[current_player] ;
    cursor         <= crowns_pos[next_player_table[current_player]];
    // 光标模式设置为选择模式
    cursor_type    <= CHOOSE;
    // TODO 维护 round

    // TODO 如果 round 达到特定值，增加兵力（这个可能需要写一个状态，因为一个 always_ff 里不能重复赋值）

    // TODO 重启计时器
endtask

// 胜负判断
function automatic logic check_win();
    // 进行胜负判断，如果已分出胜负，记录胜者

endfunction

// 游戏结束
task automatic game_over();
    // （此时已经分出胜负）切换游戏状态到结束状态
   
endtask 


//// [游戏逻辑部分 END]



//// [游戏显示部分 BEGIN]
logic [15:0] address;//ram地址
logic [31:0] bluecity_ramdata;
logic [31:0] bluecrown_ramdata;
logic [31:0] redcity_ramdata;
logic [31:0] redcrown_ramdata;
logic [31:0] mountain_ramdata;
logic [31:0] neutralcity_ramdata;
logic [31:0] number1_ramdata;
logic [31:0] white_ramdata;//该地址对应的ram中各类棋子的地址
logic [31:0] ramdata;//选择后的用作输出的ram数据
logic [31:0] indata = 32'b0;//用于为ram输入赋值（没用）
logic [VGA_WIDTH - 1: 0] vdata_to_ram = 0;//取模后的v
logic [VGA_WIDTH - 1: 0] hdata_to_ram = 0;//取模后的h
logic [7:0] cur_v;//从像素坐标转换到数组v坐标
logic [7:0] cur_h;//从像素坐标转换到数组h坐标
logic is_gen;
logic [7:0] cur_owner;
logic [7:0] cur_piecetype;
assign cur_owner = cells[cur_h][cur_v].owner;
assign cur_piecetype = cells[cur_h][cur_v].piece_type;
int cursor_array [0:9] = '{'d40, 'd80, 'd120, 'd160, 'd200, 'd240, 'd280, 'd320, 'd360, 'd400};
assign address = vdata_to_ram*40 + hdata_to_ram;
always_comb begin
    if((hdata == cursor_array[cursor.h]+1 || hdata == cursor_array[cursor.h]+39 || vdata == cursor_array[cursor.v]+1 || vdata==cursor_array[cursor.v]+39)
    &&(vdata<=cursor_array[cursor.v]+39 && vdata>=cursor_array[cursor.v]+1 && hdata<=cursor_array[cursor.h]+39 && hdata>=cursor_array[cursor.h]+1)) begin
    // // if((hdata ==50*(cursor.h+1)+1 || hdata == 50*(cursor.h+1)+49 || vdata == 50*(cursor.v+1)+1 || vdata==50*(cursor.v+1)+49)
    // // &&(vdata<=50*(cursor.v+1)+49 && vdata>=50*(cursor.v+1)+1 && hdata<=50*(cursor.h+1)+49 && hdata>=50*(cursor.h+1)+1)) begin  
    // // if((hdata == 51 || hdata == 99 || vdata == 51 || vdata==99)
    // // &&(vdata<=99 && vdata>=51 && hdata<=99 && hdata>=51)) begin 
        gen_red = 255;
        gen_green = 255;
        gen_blue = 255;
    end else 
    if (vdata<=440&&vdata>=40&&hdata<=440&&hdata>=40) begin
        gen_red = ramdata[7:0];
        gen_green = ramdata[15:8];
        gen_blue = ramdata[23:16];
    end else begin
        gen_red = 0;
        gen_green = 0;
        gen_blue = 0;
    end
end
// //通过打表避免使用除法取模，找到对应ram中的坐标和棋盘坐标
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
    // if (cur_owner == NPC && cur_piecetype == TERRITORY) begin
    //     is_gen = 1;
    //     ramdata = 0;
    // end else if (cur_owner== NPC && cur_piecetype == MOUNTAIN) begin
    //     is_gen = 1;
    //     ramdata = mountain_ramdata;
    // end else if (cur_owner == NPC && cells[cur_h][cur_v].piece_type == CITY) begin
    //     is_gen = 1;
    //     ramdata = neutralcity_ramdata;
    // end else if (cells[cur_h][cur_v].owner == RED && cells[cur_h][cur_v].piece_type == CITY) begin
    //     is_gen = 1;
    //     ramdata = redcity_ramdata;
    // end else if (cells[cur_h][cur_v].owner == RED && cells[cur_h][cur_v].piece_type == CROWN) begin
    //     is_gen = 1;
    //     ramdata = redcrown_ramdata;
    // end else if (cells[cur_h][cur_v].owner == BLUE && cells[cur_h][cur_v].piece_type == CITY) begin
    //     is_gen = 1;
    //     ramdata = bluecity_ramdata;
    // end else if (cells[cur_h][cur_v].owner == BLUE && cells[cur_h][cur_v].piece_type == CROWN) begin
    //     is_gen = 1;
    //     ramdata = bluecrown_ramdata;
    // end else begin
    //     is_gen = 1;
    //     ramdata = 0;
    // // end
    if (number1_ramdata[31:24]!=0) begin//恒定显示为1，不要数字删了即可
        is_gen = 1;
        ramdata = number1_ramdata;
    end else if (cur_owner == NPC) begin
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
            is_gen = 0;
            ramdata = 0;
        end
    end else if (cur_owner == BLUE) begin
        if (cur_piecetype == CROWN) begin
            is_gen = 1;
            ramdata = bluecrown_ramdata;
        end else if (cur_piecetype == CITY) begin
            is_gen = 1;
            ramdata = bluecity_ramdata;
        end else begin
            is_gen = 0;
            ramdata = 0;
        end
    end else begin
        is_gen = 0;
        ramdata = 0;
    end
    // is_gen = 1;
    // ramdata = redcity_ramdata;
    // is_gen = 0;
    // ramdata = 0;
end

// ram_white ram_white (
//     .address(address),
//     .clock(clk_100M),
//     .data(indata),
//     .wren(0),
//     .q(white_ramdata)
// );    
ram_bluecity ram_bluecity_test (
    .address(address),
    .clock(clk_100M),
    .data(indata),
    .wren(0),
    .q(bluecity_ramdata)  
);
ram_number1 ram_number1_test (
    .address(address),
    .clock(clk_100M),
    .data(indata),
    .wren(0),
    .q(number1_ramdata)  
);
ram_bluecrown ram_bluecrown_test (
    .address(address),
    .clock(clk_100M),
    .data(indata),
    .wren(0),
    .q(bluecrown_ramdata)
);
ram_redcity ram_redcity_test (
    .address(address),
    .clock(clk_100M),
    .data(indata),
    .wren(0),
    .q(redcity_ramdata)
);
ram_redcrown ram_redcrown_test (
    .address(address),
    .clock(clk_100M),
    .data(indata),
    .wren(0),
    .q(redcrown_ramdata)
);
ram_neutralcity ram_neutralcity_test (
    .address(address),
    .clock(clk_100M),
    .data(indata),
    .wren(0),
    .q(neutralcity_ramdata)
);
ram_mountain ram_mountain_test (
    .address(address),
    .clock(clk_100M),
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
    end else if (is_gen) begin
        use_gen = 1;
    end else begin
        use_gen = 0;
    end
end
//// [游戏显示部分 END]

endmodule