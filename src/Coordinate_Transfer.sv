// //通过打表避免使用除法取模，找到对应ram中的坐标和棋盘坐标
module Coordinate_Transfer
#(parameter VGA_WIDTH = 10, LOG2_BORAD_WIDTH = 4) (
	input  wire [VGA_WIDTH - 1: 0] coordinate,

    output wire [VGA_WIDTH - 1: 0] coordinate_to_ram,
    output wire [LOG2_BORAD_WIDTH - 1: 0] coordinate_in_board
);
always_comb begin
    if (coordinate>=0 && coordinate<40) begin
        coordinate_to_ram = coordinate;
        coordinate_in_board = 0;
    end else if (coordinate>=40 && coordinate<80) begin
        coordinate_to_ram = coordinate - 40;
        coordinate_in_board = 0;
    end else if (coordinate>=80 && coordinate<120) begin
        coordinate_to_ram = coordinate - 80;
        coordinate_in_board = 1;
    end else if (coordinate>=120 && coordinate<160) begin
        coordinate_to_ram = coordinate - 120;
        coordinate_in_board = 2;
    end else if (coordinate>=160 && coordinate<200) begin
        coordinate_to_ram = coordinate - 160;
        coordinate_in_board = 3;
    end else if (coordinate>=200 && coordinate<240) begin
        coordinate_to_ram = coordinate - 200;
        coordinate_in_board = 4;
    end else if (coordinate>=240 && coordinate<280) begin
        coordinate_to_ram = coordinate - 240;
        coordinate_in_board = 5;
    end else if (coordinate>=280 && coordinate<320) begin
        coordinate_to_ram = coordinate - 280;
        coordinate_in_board = 6;
    end else if (coordinate>=320 && coordinate<360) begin
        coordinate_to_ram = coordinate - 320;
        coordinate_in_board = 7;
    end else if (coordinate>=360 && coordinate<400) begin
        coordinate_to_ram = coordinate - 360;
        coordinate_in_board = 8;
    end else if (coordinate>=400 && coordinate<440) begin
        coordinate_to_ram = coordinate - 400;
        coordinate_in_board = 9;
    end else begin
        coordinate_to_ram = 0;
        coordinate_in_board = 0;
    end
end
endmodule