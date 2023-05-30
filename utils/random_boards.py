import random
import datetime
import argparse
from pathlib import Path
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

    # 1. 随机生成两个王城，保证距离充分大
    while True:
        board.crowns[Player.RED ] = (random.randrange(0, width), random.randrange(0, width))
        board.crowns[Player.BLUE] = (random.randrange(0, width), random.randrange(0, width))
        if distance(board.crowns[Player.RED ], board.crowns[Player.BLUE], 1) >= 1.2 * width:
            break
    
    # 2. 王城之间生成一条道路，这条道路上将没有山，以保证王城之间的连通性
    protected_path = random_path(board.crowns[Player.RED], board.crowns[Player.BLUE])

    # 3. 生成指定数量的山
    while len(board.mountains) < mountain_cnt:
        mountain = (random.randrange(0, width), random.randrange(0, width))
        if (mountain not in protected_path) and (mountain not in board.mountains):
            board.mountains.append(mountain)

    # 4. 生成指定数量的 NPC 塔
    while len(board.NPC_cities) < NPC_city_cnt:
        city = (random.randrange(0, width), random.randrange(0, width))
        if (city not in list(board.crowns.values())) and (city not in board.mountains) and (city not in board.NPC_cities):
            board.NPC_cities.append(city)

    return board

def convert_to_mif(boards, mif_file_path):
    """
    传入的参数为 Board 列表，生成 MIF 文件
    """


def get_args():
    """
    解析命令行参数： 生成的初始局面数量、MIF 文件地址
    """
    parser = argparse.ArgumentParser(description='生成的初始局面数量、MIF 文件地址')

    # 添加命令行参数
    # parser.add_argument('-w', '--width', dest='board_width',   type=int,  default=10,  help='board width')
    parser.add_argument('-n', '--num',   dest='board_num',     type=int,  default=128, help='board num')
    parser.add_argument('-f', '--file',  dest='mif_file_path', type=Path, default=Path.cwd() / 'random_boards,mif', help='output MIF file path')
    
    # 从命令行中解析参数
    args = parser.parse_args()

    return args



if __name__ == "__main__":

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
        with open(Path('log') / f'random_boards-{datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")}.txt', 'a') as f:
            f.write(f"[{id}]\n")
            f.write(str(board))
            f.write("\n")

    convert_to_mif(boards, args.mif_file_path)
