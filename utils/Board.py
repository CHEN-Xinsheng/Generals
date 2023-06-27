"""
    棋盘信息的数据结构。
"""

# import json
# from pprint import pprint
from enum import Enum


# 玩家类型（枚举类型）
class Player(Enum):
    NPC  = 0
    RED  = 1
    BLUE = 2

# # 棋子类型（枚举类型）
# class Piece(Enum):
#     TERRITORY = 0
#     MOUNTAIN  = 1
#     CROWN     = 2
#     CITY      = 3


# # 单元格类
# class Cell:
#     def __init__(self, owner: Player, piece_type: Piece, troop: int):
#         self.owner = owner
#         self.piece_type = piece_type
#         self.troop = troop

# 棋盘类
class Board:
    def __init__(self, width):
        # 每个玩家的王城坐标
        self.crowns = {}
        # 初始元素（山、NPC 塔）的坐标
        self.mountains = []
        self.NPC_cities = []

    def __str__(self):
        return f"crowns: {str(self.crowns)}\n"\
                + f"mountains(len = {len(self.mountains)}): {self.mountains}\n"\
                + f"NPC_cities(len = {len(self.NPC_cities)}): {self.NPC_cities}\n"
