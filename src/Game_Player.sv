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
    output wire [LOG2_MAX_PLAYER_CNT - 1:0] current_player_o_test,   // 当前回合玩家，正常情况下应与当前格归属方一致
    output wire [LOG2_MAX_PLAYER_CNT - 1:0] next_player_o_test,      // 下一回合玩家
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
    current_player = Player'(1);        // 初始回合玩家
    cursor         = '{'d0, 'd7};
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
assign current_player_o_test = current_player;                             // 当前回合玩家，正常情况下应与当前格归属方一致
assign next_player_o_test    = next_player_table[current_player];          // 下一回合玩家
// [TEST END]

//// [游戏内部数据 END]


// 与键盘输入模块交互+游戏逻辑部分 顶层 always 块
always_ff @ (posedge clock) begin
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
// 游戏逻辑部分顶层函数
task automatic game_logic_top();
    // 如果当前有尚未结算的操作，那么：结算一次操作、将操作队列清空
    if (operation != NONE) begin
        casez (cursor_type)
            CHOOSE: 
                // 判断操作是否合法
                if (choose_is_valid()) begin
                    // 如果合法，执行一次操作
                    do_choose();
                end
            MOVE_HALF || MOVE_TOTAL: begin
                // 判断操作是否合法
                if (move_is_valid()) begin
                    // 如果合法，执行一次操作
                    do_move();
                end
                // 胜负判断
                if (check_win()) begin
                    // 如果已分出胜负，那么标记游戏结束
                    game_over();
                end else begin
                    // 如果未分出胜负，回合切换
                    round_switch();
                end

            end
            default: begin
                // assert 这种情况不应出现
            end
        endcase
        // 标记当前操作队列为空
        operation <= NONE;
    end
endtask

// 判断操作是否合法
// function automatic logic op_is_valid();
//     casez (cursor_type)
//         CHOOSE: 
//             return choose_is_valid();
//         MOVE_HALF: begin

//             return 'b1;
//         end
//         MOVE_TOTAL: begin

//             return 'b1;
//         end
//         default:
//             return 'b0;   // assert 这种情况不应出现
//     endcase
// endfunction

// 判断操作是否合法：当前光标为选择模式
function automatic logic choose_is_valid();
    casez (operation)
        W: begin
            
        end
        A: begin
            
        end
        S: begin
            
        end
        D: begin
        
        end
        Z: 
            return 'b0;  // 选择模式下无法切换“全移/半移”
        SPACE:
            return 'b1;  // 从选择模式切换到行棋模式是合法的
        default: 
            return 'b0;  // assert 这种情况不应出现
    endcase
endfunction

// 判断操作是否合法：当前光标为行棋模式
function automatic logic move_is_valid();
    casez (operation)
        W: begin
            
        end
        A: begin
            
        end
        S: begin
            
        end
        D: begin
        
        end
        Z: 
            return 'b1;  // 行棋模式下可以切换“全移/半移”
        SPACE:
            return 'b1;  // 从行棋模式切换到选择模式是合法的
        default: 
            return 'b0;  // assert 这种情况不应出现
    endcase
endfunction

// 执行一次操作：当前光标为选择模式
task automatic do_choose();
   
endtask

// 执行一次操作：当前光标为行棋模式
task automatic do_move();
   
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

    // TODO 如果 round 达到特定值，增加兵力

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
logic [31:0] neutralcity_ramdata;//该地址对应的ram中各类棋子的地址
logic [31:0] ramdata;//选择后的用作输出的ram数据
logic [31:0] indata = 32'b0;//用于为ram输入赋值（没用）
logic [VGA_WIDTH - 1: 0] vdata_to_ram = 0;//取模后的v
logic [VGA_WIDTH - 1: 0] hdata_to_ram = 0;//取模后的h
logic [7:0] cur_v;//从像素坐标转换到数组v坐标
logic [7:0] cur_h;//从像素坐标转换到数组h坐标
logic is_gen;
assign address = vdata_to_ram*50 + hdata_to_ram;
//assign ramdata = bluecrown_ramdata;
always_comb begin
    // if ((hdata==51 || hdata==99 || hdata==101 || hdata==149 || hdata==151 || hdata==199|| hdata==201 
    // || hdata==249 || hdata==251 || hdata==299 || hdata==301 || hdata==349 || hdata==351 || hdata==399 
    // || hdata== 401 || hdata==449 || hdata==451 || hdata==499 || hdata==501 || hdata == 549
    // || vdata==51 || vdata==99 || vdata==101 || vdata==149 || vdata==151 || vdata==199|| vdata==201 
    // || vdata==249 || vdata==251 || vdata==299 || vdata==301 || vdata==349 || vdata==351 || vdata==399 
    // || vdata== 401 || vdata==449 || vdata==451 || vdata==499 || vdata==501 || vdata == 549)
    if((hdata == 151 || hdata == 199 || vdata == 151 || vdata==199)
    &&(vdata<=199 && vdata>=151 && hdata<=199 && hdata>=151)) begin
    //(vdata<=550 && vdata>=50 && hdata<=550 && hdata>=50)) begin
        gen_red = 255;
        gen_green = 255;
        gen_blue = 255;
    end else if (vdata<=550&&vdata>=50&&hdata<=550&&hdata>=50) begin
        gen_red = ramdata[7:0];
        gen_green = ramdata[15:8];
        gen_blue = ramdata[23:16];
    end else begin
        gen_red = 0;
        gen_green = 0;
        gen_blue = 0;
    end
end
//通过打表避免使用除法取模，找到对应ram中的坐标
always_comb begin
    if (hdata>=0 && hdata<50) begin
        hdata_to_ram = hdata;
    end else if (hdata>=50 && hdata<100) begin
        hdata_to_ram = hdata - 50;
        cur_h = 0;
    end else if (hdata>=100 && hdata<150) begin
        hdata_to_ram = hdata - 100;
        cur_h = 1;
    end else if (hdata>=150 && hdata<200) begin
        hdata_to_ram = hdata - 150;
        cur_h = 2;
    end else if (hdata>=200 && hdata<250) begin
        hdata_to_ram = hdata - 200;
        cur_h = 3;
    end else if (hdata>=250 && hdata<300) begin
        hdata_to_ram = hdata - 250;
        cur_h = 4;
    end else if (hdata>=300 && hdata<350) begin
        hdata_to_ram = hdata - 300;
        cur_h = 5;
    end else if (hdata>=350 && hdata<400) begin
        hdata_to_ram = hdata - 350;
        cur_h = 6;
    end else if (hdata>=400 && hdata<450) begin
        hdata_to_ram = hdata - 400;
        cur_h = 7;
    end else if (hdata>=450 && hdata<500) begin
        hdata_to_ram = hdata - 450;
        cur_h = 8;
    end else if (hdata>=500 && hdata<550) begin
        hdata_to_ram = hdata - 500;
        cur_h = 9;
    end else begin
        hdata_to_ram = 0;
    end
end
always_comb begin
    if (vdata>=0 && vdata<50) begin
        vdata_to_ram = vdata;
    end else if (vdata>=50 && vdata<100) begin
        vdata_to_ram = vdata - 50;
        cur_v = 0;
    end else if (vdata>=100 && vdata<150) begin
        vdata_to_ram = vdata - 100;
        cur_v = 1;
    end else if (vdata>=150 && vdata<200) begin
        vdata_to_ram = vdata - 150;
        cur_v = 2;
    end else if (vdata>=200 && vdata<250) begin
        vdata_to_ram = vdata - 200;
        cur_v = 3;
    end else if (vdata>=250 && vdata<300) begin
        vdata_to_ram = vdata - 250;
        cur_v = 4;
    end else if (vdata>=300 && vdata<350) begin
        vdata_to_ram = vdata - 300;
        cur_v = 5;
    end else if (vdata>=350 && vdata<400) begin
        vdata_to_ram = vdata - 350;
        cur_v = 6;
    end else if (vdata>=400 && vdata<450) begin
        vdata_to_ram = vdata - 400;
        cur_v = 7;
    end else if (vdata>=450 && vdata<500) begin
        vdata_to_ram = vdata - 450;
        cur_v = 8;
    end else if (vdata>=500 && vdata<550) begin
        vdata_to_ram = vdata - 500;
        cur_v = 9;
    end else begin
        vdata_to_ram = 0;
    end
end
always_comb begin
    if (cells[cur_h][cur_v].owner == NPC && cells[cur_h][cur_v].piece_type == TERRITORY) begin
        is_gen = 0;
        ramdata = 0;
    end else if (cells[cur_h][cur_v].owner == NPC && cells[cur_h][cur_v].piece_type == MOUNTAIN) begin
        is_gen = 1;
        ramdata = ram_mountain;
    end else if (cells[cur_h][cur_v].owner == NPC && cells[cur_h][cur_v].piece_type == CITY) begin
        is_gen = 1;
        ramdata = ram_neutralcity;
    end else if (cells[cur_h][cur_v].owner == RED && cells[cur_h][cur_v].piece_type == CITY) begin
        is_gen = 1;
        ramdata = ram_redcity;
    end else if (cells[cur_h][cur_v].owner == RED && cells[cur_h][cur_v].piece_type == CROWN) begin
        is_gen = 1;
        ramdata = ram_redcrown;
    end else if (cells[cur_h][cur_v].owner == BLUE && cells[cur_h][cur_v].piece_type == CITY) begin
        is_gen = 1;
        ramdata = ram_bluecity;
    end else if (cells[cur_h][cur_v].owner == BLUE && cells[cur_h][cur_v].piece_type == CROWN) begin
        is_gen = 1;
        ramdata = ram_bluecrown;
    end else begin
        is_gen = 0;
        ramdata = 0;
    end
end
    
ram_bluecity ram_bluecity_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(bluecity_ramdata)
);
ram_bluecrown ram_bluecrown_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(bluecrown_ramdata)
);
ram_redcity ram_redcity_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(redcity_ramdata)
);
ram_redcrown ram_redcrown_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(redcrown_ramdata)
);
ram_neutralcity ram_neutralcity_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(neutralcity_ramdata)
);
ram_mountain ram_mountain_test (
    .address(address),
    .clock(clk_vga),
    .data(indata),
    .wren(0),
    .q(mountain_ramdata)
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