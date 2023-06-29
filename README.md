# Generals 将军棋

2022-2023 学年春季学期《数字逻辑设计》课程项目
> 第 13 组
> 陈鑫圣 周晋

本项目详细介绍见项目开发文档。

## 项目文件结构

本项目的主要工程文件如下：
- `src/` （以下按对应模块的层次关系排列）
  - `mod_top.sv` ：项目的顶层文件，它调用以下文件
    - `Keyboard_Decoder.sv` ：键盘解码器
    - `Game_Controller.sv` ：游戏控制器
      - `Counter.sv` ：循环计数器，（计数频率较高时）可用于产生小范围内的伪随机数
      - `Number_Choose.sv` ：用于显示数码
      - `Number_Transfer.sv` ：用于计算一个三位数的百位、十位、个位
      - `Random_Boards_Library.sv` ：初始棋盘库，由 `random_boards.py` 生成，用于随机选择初始棋盘
    - `Screen_Controller.sv` ：显示控制器
      - `Background_Painter.sv` ：用于绘制背景图像
      - `vga.v`： VGA 控制器，用于生成 VGA 行列扫描信号
- `output_files/`
  - `digital-design.sof` ：编译后的 bitstream 二进制文件。
