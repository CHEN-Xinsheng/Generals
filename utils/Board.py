"""
    棋盘信息的数据结构。
"""


from enum import Enum


# 玩家类型（枚举类型）
class Player(Enum):
    NPC  = 0
    RED  = 1
    BLUE = 2

# 棋子类型（枚举类型）
class Piece(Enum):
    TERRITORY = 0
    MOUNTAIN  = 1
    CROWN     = 2
    CITY      = 3


# 单元格类
class Cell:
    def __init__(self, owner: Player, piece_type: Piece, troop: int):
        self.owner = owner
        self.piece_type = piece_type
        self.troop = troop

# 棋盘类
class Board:
    def __init__(self, width):
        # 初始化为 width * width 的棋盘
        self.cells = []
        for _ in range(width):
            column = [Cell(Player.NPC, Piece.TERRITORY, 0) for _ in range(width)]
            self.cells.append(column)
