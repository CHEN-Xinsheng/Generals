# 初始棋盘生成器

## 功能介绍

以运行时间为种子，生成随机初始棋盘。

生成的棋盘保证：
- 每个棋盘不超过 32 个“特殊元素”（其中恰有 2 个王城），NPC 特殊元素（山地、空地）不超过 30 个。
- NPC 特殊元素（山地、空地）的比例均在 35% 与 65% 之间。
- 双方王城的距离充分大（曼哈顿距离不小于 12）且不在边缘。
- 每个王城附近 3*3 内至少有 1 个 NPC 城市。
- 双方王城之间是连通的，即存在一条连接双方王城的、不经过任何山的路径。

输出格式为 SystemVerilog 代码。同时还生成日志文件，以较为易读的方式记录生成的初始棋盘，日志文件保存在 `log/` 目录下。

## 使用方法

在 `utils/` 目录下：

- 运行 `pip install -r requirements.txt` 安装依赖。
- 然后运行 `python random_boards.py` ，即可得到结果文件，保存在 `result/` 目录下。
