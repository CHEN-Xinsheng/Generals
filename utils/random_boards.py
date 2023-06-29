import random
import datetime
import argparse
import os
from pathlib import Path
from typing import List
from tqdm import tqdm
from Board import *


BOARD_WIDTH = 10   # 棋盘宽度

def rand_with_probability(p):
    """
    以概率 p 返回 True
    """ 
    return bool(random.random() < p)

def distance(A, B, k):
    """
    计算两个向量之间的距离（ k-范数）
    """
    dis = 0
    for a, b in zip(A, B):
        dis += abs(a - b)**k
    return dis**(1/k)

def random_path(begin, end):
    """
    生成两个平面整点之间的一条随机道路，包含头尾
    example: 
        input: 
            begin = (0, 0), 
            end   = (1, 2)
        return:
            [(0, 0), (0, 1), (0, 2), (1, 2)]
    """
    # begin, end 的第 1 坐标相同
    if begin[0] == end[0]:
        if begin[1] < end[1]:
            return [(begin[0], v) for v in range(begin[1], end[1] + 1, 1)]
        elif begin[1] == end[1]:
            return [begin]
        else:
            return [(begin[0], v) for v in range(begin[1], end[1] - 1, -1)]
    # begin, end 的第 1 坐标不相同
    if begin[0] > end[0]:
        begin, end = end, begin
    # 至此，begin 的第 1 坐标更小，即 begin 严格在左侧
    if begin[1] == end[1]:
        return [(h, begin[1]) for h in range(begin[0], end[0] + 1, 1)]
    # 至此，begin 和 end 的横纵坐标均不相等
    path = [begin]
    current = begin
    while current != end:
        dh = end[0] - current[0]
        dv = end[1] - current[1]
        v_step = 1 if dv > 0 else -1 if dv < 0 else 0
        if rand_with_probability(abs(dh) / (abs(dh) + abs(dv))):
            current = (current[0] + 1, current[1]) 
        else:
            current = (current[0], current[1] + v_step) 
        path.append(current)
    return path


def random_board(width, mountain_cnt, NPC_city_cnt):
    """
    生成随机地图
    """
    board = Board(width)

    # 1. 随机生成两个王城，保证距离充分大且不在边缘
    while True:
        board.crowns[Player.RED ] = (random.randrange(1, width-1), random.randrange(1, width-1))
        board.crowns[Player.BLUE] = (random.randrange(1, width-1), random.randrange(1, width-1))
        if distance(board.crowns[Player.RED ], board.crowns[Player.BLUE], 1) >= 1.2 * width:
            break

    # 2. 每个王城附近 3*3 内保证至少 1 个塔
    for player in [Player.RED, Player.BLUE]:
        while True:
            city = (board.crowns[player][0] + random.randrange(-1, 2), board.crowns[player][1] + random.randrange(-1, 2))
            if not city == board.crowns[player]:
                board.NPC_cities.append(city)
                break

    # 3. 王城之间生成一条道路，这条道路上将没有山，以保证王城之间的连通性
    protected_path = random_path(board.crowns[Player.RED], board.crowns[Player.BLUE])

    # 4. 生成指定数量的山
    while len(board.mountains) < mountain_cnt:
        mountain = (random.randrange(0, width), random.randrange(0, width))
        if (mountain not in protected_path) and (mountain not in board.mountains):
            board.mountains.append(mountain)

    # 5. 生成指定数量的 NPC 塔
    while len(board.NPC_cities) < NPC_city_cnt:
        city = (random.randrange(0, width), random.randrange(0, width))
        if (city not in list(board.crowns.values())) and (city not in board.mountains) and (city not in board.NPC_cities):
            board.NPC_cities.append(city)

    return board

def convert_to_mif(boards: List[Board], mif_file_path):
    """
    传入的参数为 Board 列表，生成 MIF 文件
    """

    assert 32 * len(boards) <= 0xffff + 1  # 因为在 MIF 的 ADDR 只写了 4 位，所以 word 的数量必须不能大于 0xffff + 1
    assert BOARD_WIDTH < 16  # 因为 (h, v) = (0xF, 0xF) 用于占位（即表示该格子为 NPC 普通领地），所以棋盘宽度不能达到 16 ，否则将产生冲突

    def print_a_word(addr, h, v, type):
        print('{0:04X}: {1:04b}{2:04b}{3:02b};'.format(addr, h, v, type), file=f)

    with open(mif_file_path, 'w') as f:
        print('WIDTH = 10;', file=f) # 每个 word 大小为 10 bit： h(4), v(4), type(2)
        """
        type:
            NPC  MOUNTAIN  - 00
            NPC  CITY      - 01
            RED  CROWN     - 10
            BLUE CROWN     - 11
        """
        print(f'DEPTH = {32 * len(boards)};', file=f)   # word 的个数。每张棋盘 32 个 word（32 个特殊元素），有 len(boards) 张棋盘
        print('ADDRESS_RADIX = HEX;', file=f)
        print('DATA_RADIX = BIN;', file=f)

        print('CONTENT BEGIN', file=f)
        addr = 0
        for board in boards:
            # 输出王城位置
            print_a_word(addr, board.crowns[Player.RED ][0], board.crowns[Player.RED ][1], 0b10); addr += 1 # RED CROWN
            print_a_word(addr, board.crowns[Player.BLUE][0], board.crowns[Player.BLUE][1], 0b11); addr += 1 # BLUE CROWN
            # 输出山位置
            for (h, v) in board.mountains:
                print_a_word(addr, h, v, 0b00); addr += 1
            # 输出 NPC 塔位置
            for (h, v) in board.NPC_cities:
                print_a_word(addr, h, v, 0b01); addr += 1
            # 输出占位符
            for _ in range(32 - 2 - len(board.mountains) - len(board.NPC_cities)):
                print_a_word(addr, 0xF, 0xF, 0b00); addr += 1  # (h, v) = (0xF, 0xF) 用于占位（即表示该格子为 NPC 普通领地），type 字段无意义
        print('END;', file=f)


def convert_to_sv_localparam(boards: List[Board], sv_file_path):
    """
    传入的参数为 Board 列表，生成 sv 代码
    """

    name = "init_boards"
    words_cnt = 32 * len(boards) # word 的个数。每张棋盘 32 个 word（32 个特殊元素），有 len(boards) 张棋盘

    def print_a_word(h, v, type):
         print("    10'b{0:04b}{1:04b}{2:02b},".format(h, v, type), file=f)

    with open(sv_file_path, 'w', encoding='utf-8') as f:
        print('localparam [0:%d][9:0] %s = {' % (words_cnt - 1, name), file=f)
        for board in boards:
            # 输出王城位置
            print_a_word(board.crowns[Player.RED ][0], board.crowns[Player.RED ][1], 0b10); # RED CROWN
            print_a_word(board.crowns[Player.BLUE][0], board.crowns[Player.BLUE][1], 0b11); # RED CROWN
            # 输出山位置
            for (h, v) in board.mountains:
                print_a_word(h, v, 0b00)
            # 输出 NPC 塔位置
            for (h, v) in board.NPC_cities:
                print_a_word(h, v, 0b01)
            # 输出占位符
            for _ in range(32 - 2 - len(board.mountains) - len(board.NPC_cities)):
                print_a_word(0xF, 0xF, 0b00); # (h, v) = (0xF, 0xF) 用于占位（即表示该格子为 NPC 普通领地），type 字段无意义
        print('};', file=f)


def cell_to_str(board: Board, h, v):
    """
        example: Cell'({NPC, MOUNTAIN, 9'd0})
    """
    if Player.RED in board.crowns and  (h, v) == board.crowns[Player.RED]:
        owner = "RED"
        type = "CROWN"
        troop = 9
    elif Player.BLUE in board.crowns and (h, v) == board.crowns[Player.BLUE]:
        owner = "BLUE"
        type = "CROWN"
        troop = 9
    elif (h, v) in board.mountains:
        owner = "NPC"
        type = "MOUNTAIN"
        troop = 0
    elif (h, v) in board.NPC_cities:
        owner = "NPC"
        type = "CITY"
        troop = 0
    else:
        owner = "NPC"
        type = "TERRITORY"
        troop = 0

    # return "'{.owner = %s, .piece_type = %s, .troop = 9'd%d}" % (owner, type, troop)
    return "'{%s, %s, 9'd%d}" % (owner, type, troop)

def whole_board_to_str(board: Board):
    result = []
    for h in range(BOARD_WIDTH - 1, -1, -1):  # BOARD_WIDTH-1, ..., 1, 0
        column = []
        for v in range(BOARD_WIDTH - 1, -1, -1):
            column.append(cell_to_str(board, h, v))
        column = "'{" + ", ".join(column) + "}"
        result.append(column)
    result = "'{" + ", ".join(result) + "}"
    return result

def convert_to_sv_const(boards: List[Board], sv_file_path):
    """
    传入的参数为 Board 列表，生成 sv 代码
    """

    name_init_boards = "init_boards"
    name_crowns_pos_RED = "crowns_pos_RED"
    name_crowns_pos_BLUE = "crowns_pos_BLUE"

    with open(sv_file_path, 'w', encoding='utf-8') as f:
        # 输出棋盘
        print('const Cell [0: MAX_RANDOM_BOARD - 1][BORAD_WIDTH - 1: 0][BORAD_WIDTH - 1: 0] %s = ' % (name_init_boards), file=f)
        result = "'{\n"
        for id, board in enumerate(boards):
            if not id == len(boards) - 1:
                result += "    " + whole_board_to_str(board) + ",\n"
            else: # last one
                result += "    " + whole_board_to_str(board) + "\n"
                
        result += "};"
        print(result, file=f)
        # 输出红方王城
        print('const Position [0: MAX_RANDOM_BOARD - 1] %s = ' % (name_crowns_pos_RED), file=f)
        result = []
        for board in boards:
            result.append("'{'d%d, 'd%d}" % (board.crowns[Player.RED][0], board.crowns[Player.RED][1]))
        result = "'{\n" + ", ".join(result) + "\n};"
        print(result, file=f)
        # 输出红方王城
        print('const Position [0: MAX_RANDOM_BOARD - 1] %s = ' % (name_crowns_pos_BLUE), file=f)
        result = []
        for board in boards:
            result.append("'{'d%d, 'd%d}" % (board.crowns[Player.BLUE][0], board.crowns[Player.BLUE][1]))
        result = "'{\n" + ", ".join(result) + "\n};"
        print(result, file=f)


def convert_to_sv_casez(boards: List[Board], sv_file_path):
    """
    传入的参数为 Board 列表，生成 sv 代码
    """
    
    with open(sv_file_path, 'w', encoding='utf-8') as f:
        # 输出棋盘
        print('casez (random_board)', file=f)
        for id, board in enumerate(boards):
            crowns_pos_RED  = "'{'d%d, 'd%d}" % (board.crowns[Player.RED ][0], board.crowns[Player.RED ][1])
            crowns_pos_BLUE = "'{'d%d, 'd%d}" % (board.crowns[Player.BLUE][0], board.crowns[Player.BLUE][1])
            print(f"    {id}: begin", file=f)
            print(f"        cells <= {whole_board_to_str(board)};", file=f)
            print(f"        crowns_pos[RED ] <= {crowns_pos_RED};", file=f)
            print(f"        crowns_pos[BLUE] <= {crowns_pos_BLUE};", file=f)
            print(f"    end", file=f)
        print('endcase', file=f)
            

def get_args():
    """
    解析命令行参数： 生成的初始局面数量、MIF 文件地址
    """
    parser = argparse.ArgumentParser(description='生成的初始局面数量、MIF 文件地址')

    # 添加命令行参数
    # parser.add_argument('-w', '--width', dest='board_width',   type=int,  default=10,  help='board width')
    parser.add_argument('-n', '--num', dest='board_num',     type=int,  default=128, help='board num')
    parser.add_argument('-m', '--mif', dest='mif_file_path', type=Path, default=Path.cwd() / 'result' / f'random_boards-{current_time}.mif', help='output MIF file path')
    parser.add_argument('-s', '--sv',  dest='sv_file_path',  type=Path, default=Path.cwd() / 'result' / f'random_boards-{current_time}.sv',  help='output sv file path')
    
    # 从命令行中解析参数
    args = parser.parse_args()

    return args



if __name__ == "__main__":

    current_time = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    # 从命令行获取参数（生成的初始局面数量、MIF 文件地址）
    args = get_args()

    boards = []
    # 生成指定数量的随机棋盘
    for id in tqdm(range(args.board_num)):
        # 随机生成 NPC 元素（塔、山）数量
        ## 对于 10*10 的棋盘，每个棋盘不超过 32 个特殊元素（其中恰有 2 个王城），NPC 特殊元素不超过 30 个
        NPC_elements_cnt = random.randrange(0.24 * BOARD_WIDTH**2, 0.31 * BOARD_WIDTH**2)
        ## 山和 NPC 塔的比例都在 给定区间 内
        mountain_cnt = int(NPC_elements_cnt * random.uniform(0.35, 0.65))
        NPC_city_cnt = NPC_elements_cnt - mountain_cnt

        # 随机生成一个棋盘
        board = random_board(BOARD_WIDTH, mountain_cnt, NPC_city_cnt)
        boards.append(board)

        # 保存日志
        if not os.path.exists(Path('log')):
            os.makedirs(Path('log'))
        with open(Path('log') / f'random_boards-{current_time}.txt', 'a') as f:
            f.write(f"[{id}]\n")
            f.write(str(board))
            f.write("\n")

    # 创建结果保存路径
    if not os.path.exists(Path.cwd() / 'result'):
        os.makedirs(Path.cwd() / 'result')
    
    # convert_to_mif(boards, args.mif_file_path)
    convert_to_sv_localparam(boards, args.sv_file_path)
    # convert_to_sv_const(boards, args.sv_file_path)
    # convert_to_sv_casez(boards, args.sv_file_path)
    # print(whole_board_to_str(Board(BOARD_WIDTH)) + ";")


    ## [TEST]
    # print("{")
    # for _ in range(10):
    #     print("{" + ", ".join(["Cell'({NPC, MOUNTAIN, 9'd0})"] * 10) + "},")
    # print("};")

    # print("{")
    # for _ in range(10):
    #     print("{" + ", ".join(["Cell'({3'b000, 2'b00, 9'd0})"] * 10) + "},")
    # print("};")

    # print("{" + ", ".join(["Cell'({NPC, MOUNTAIN, 9'd0})"] * 100) + "};")

    # print("{" + ", ".join(["14'b0"] * 100) + "};")

