module Number_Choose
#(parameter VGA_WIDTH            = 0,
			LOG2_BORAD_WIDTH     = 4)
(
	input wire[VGA_WIDTH-1:0] 				hdata,
	input wire[VGA_WIDTH-1:0]				vdata,
	input wire[3:0]							cur_ones,
	input wire[3:0]							cur_tens,
	input wire[3:0]							cur_hundreds,
	input wire[3:0]							big_ones,
	input wire[3:0]							big_tens,
	input wire[3:0]							big_hundreds,
	input									clock,
    output wire [VGA_WIDTH - 1: 0]          vdata_to_ram,//取模后的v
    output wire [VGA_WIDTH - 1: 0]          hdata_to_ram,//取模后的h
	output wire[31:0]						bignumberdata,
	output wire[LOG2_BORAD_WIDTH - 1:0]		cur_h,
	output wire[LOG2_BORAD_WIDTH - 1:0]		cur_v,
	output wire[31:0]						numberdata
);
logic [31:0] number1_ramdata;
logic [31:0] number0_ramdata;
logic [31:0] number2_ramdata;
logic [31:0] number3_ramdata;
logic [31:0] number4_ramdata;
logic [31:0] number5_ramdata;
logic [31:0] number6_ramdata;
logic [31:0] number7_ramdata;
logic [31:0] number8_ramdata;
logic [31:0] number9_ramdata;//兵力数字
logic [31:0] bignumber0_ramdata;
logic [31:0] bignumber1_ramdata;
logic [31:0] bignumber2_ramdata;
logic [31:0] bignumber3_ramdata;
logic [31:0] bignumber4_ramdata;
logic [31:0] bignumber5_ramdata;
logic [31:0] bignumber6_ramdata;
logic [31:0] bignumber7_ramdata;
logic [31:0] bignumber8_ramdata;
logic [31:0] bignumber9_ramdata;//回合与计时大数字
logic [15:0] numaddress;//兵力数字地址
logic [15:0] address;//大数字地址
logic [31:0] indata = 32'b0;
assign address = vdata_to_ram*40 + hdata_to_ram;
always_comb begin
    //百位数字
    if (hdata_to_ram <= 17) begin
        numaddress = vdata_to_ram*40 + hdata_to_ram + 6;
    //十位数字
    end else if (hdata_to_ram >= 23) begin
        numaddress = vdata_to_ram*40 + + hdata_to_ram - 6;
    //个位数字
    end else begin 
        numaddress = vdata_to_ram*40 + hdata_to_ram;
    end
end
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
    end else if (hdata>=480 && hdata<520) begin
        hdata_to_ram = hdata - 480;
        cur_h = 0;
    end else if (hdata>=520 && hdata<560) begin
        hdata_to_ram = hdata - 520;
        cur_h = 0;
    end else if (hdata>=560 && hdata<600) begin
        hdata_to_ram = hdata - 560;
        cur_h = 0;
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
//兵力数字选择
always_comb begin
    //百位
    if (hdata_to_ram <= 17) begin
        if (cur_hundreds == 0) begin
            numberdata = number0_ramdata;
        end else if (cur_hundreds == 1) begin
            numberdata = number1_ramdata;
        end else if (cur_hundreds == 2) begin
            numberdata = number2_ramdata;
        end else if (cur_hundreds == 3) begin
            numberdata = number3_ramdata;
        end else if (cur_hundreds == 4) begin
            numberdata = number4_ramdata;
        end else if (cur_hundreds == 5) begin
            numberdata = number5_ramdata;
        end else if (cur_hundreds == 6) begin
            numberdata = number6_ramdata;
        end else if (cur_hundreds == 7) begin
            numberdata = number7_ramdata;
        end else if (cur_hundreds == 8) begin
            numberdata = number8_ramdata;
        end else begin
            numberdata = number9_ramdata;
        end
    end
    //个位
    else if (hdata_to_ram >= 23) begin
        if (cur_ones == 0) begin
            numberdata = number0_ramdata;
        end else if (cur_ones == 1) begin
            numberdata = number1_ramdata;
        end else if (cur_ones == 2) begin
            numberdata = number2_ramdata;
        end else if (cur_ones == 3) begin
            numberdata = number3_ramdata;
        end else if (cur_ones == 4) begin
            numberdata = number4_ramdata;
        end else if (cur_ones == 5) begin
            numberdata = number5_ramdata;
        end else if (cur_ones == 6) begin
            numberdata = number6_ramdata;
        end else if (cur_ones == 7) begin
            numberdata = number7_ramdata;
        end else if (cur_ones == 8) begin
            numberdata = number8_ramdata;
        end else begin
            numberdata = number9_ramdata;
        end            
    end
    //十位
    else begin
        if (cur_tens == 0) begin
            numberdata = number0_ramdata;
        end else if (cur_tens == 1) begin
            numberdata = number1_ramdata;
        end else if (cur_tens == 2) begin
            numberdata = number2_ramdata;
        end else if (cur_tens == 3) begin
            numberdata = number3_ramdata;
        end else if (cur_tens == 4) begin
            numberdata = number4_ramdata;
        end else if (cur_tens == 5) begin
            numberdata = number5_ramdata;
        end else if (cur_tens == 6) begin
            numberdata = number6_ramdata;
        end else if (cur_tens == 7) begin
            numberdata = number7_ramdata;
        end else if (cur_tens == 8) begin
            numberdata = number8_ramdata;
        end else begin
            numberdata = number9_ramdata;
        end
    end
end
//回合或计时数字选择
always_comb begin
    //百位
    if (hdata<=520 && hdata>=480) begin
        if (big_hundreds == 0) begin
            bignumberdata = bignumber0_ramdata;
        end else if (big_hundreds == 1) begin
            bignumberdata = bignumber1_ramdata;
        end else if (big_hundreds == 2) begin
            bignumberdata = bignumber2_ramdata;
        end else if (big_hundreds == 3) begin
            bignumberdata = bignumber3_ramdata;
        end else if (big_hundreds == 4) begin
            bignumberdata = bignumber4_ramdata;
        end else if (big_hundreds == 5) begin
            bignumberdata = bignumber5_ramdata;
        end else if (big_hundreds == 6) begin
            bignumberdata = bignumber6_ramdata;
        end else if (big_hundreds == 7) begin
            bignumberdata = bignumber7_ramdata;
        end else if (big_hundreds == 8) begin
            bignumberdata = bignumber8_ramdata;
        end else begin
            bignumberdata = bignumber9_ramdata;
        end
    end
    //十位
    else if (hdata >= 560 && hdata <= 600) begin
        if (big_ones == 0) begin
            bignumberdata = bignumber0_ramdata;
        end else if (big_ones == 1) begin
            bignumberdata = bignumber1_ramdata;
        end else if (big_ones == 2) begin
            bignumberdata = bignumber2_ramdata;
        end else if (big_ones == 3) begin
            bignumberdata = bignumber3_ramdata;
        end else if (big_ones == 4) begin
            bignumberdata = bignumber4_ramdata;
        end else if (big_ones == 5) begin
            bignumberdata = bignumber5_ramdata;
        end else if (big_ones == 6) begin
            bignumberdata = bignumber6_ramdata;
        end else if (big_ones == 7) begin
            bignumberdata = bignumber7_ramdata;
        end else if (big_ones == 8) begin
            bignumberdata = bignumber8_ramdata;
        end else begin
            bignumberdata = bignumber9_ramdata;
        end            
    end
    //个位
    else begin
        if (big_tens == 0) begin
            bignumberdata = bignumber0_ramdata;
        end else if (big_tens == 1) begin
            bignumberdata = bignumber1_ramdata;
        end else if (big_tens == 2) begin
            bignumberdata = bignumber2_ramdata;
        end else if (big_tens == 3) begin
            bignumberdata = bignumber3_ramdata;
        end else if (big_tens == 4) begin
            bignumberdata = bignumber4_ramdata;
        end else if (big_tens == 5) begin
            bignumberdata = bignumber5_ramdata;
        end else if (big_tens == 6) begin
            bignumberdata = bignumber6_ramdata;
        end else if (big_tens == 7) begin
            bignumberdata = bignumber7_ramdata;
        end else if (big_tens == 8) begin
            bignumberdata = bignumber8_ramdata;
        end else begin
            bignumberdata = bignumber9_ramdata;
        end
    end
end
ram_number0 ram_number0 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number0_ramdata)  
);
ram_number1 ram_number1 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number1_ramdata)  
);
ram_number2 ram_number2 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number2_ramdata)  
);   
ram_number3 ram_number3 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number3_ramdata)  
);  
ram_number4 ram_number4 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number4_ramdata)  
);  
ram_number5 ram_number5test (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number5_ramdata)  
);  
ram_number6 ram_number6 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number6_ramdata)  
);  
ram_number7 ram_number7 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number7_ramdata)  
);  
ram_number8 ram_number8 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number8_ramdata)  
);  
ram_number9 ram_number9 (
    .address(numaddress),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(number9_ramdata)  
);  
ram_bignumber0 ram_bignumber0(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber0_ramdata)
);
ram_bignumber1 ram_bignumber1(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber1_ramdata)
);
ram_bignumber2 ram_bignumber2(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber2_ramdata)
);
ram_bignumber3 ram_bignumber3(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber3_ramdata)
);
ram_bignumber4 ram_bignumber4(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber4_ramdata)
);
ram_bignumber5 ram_bignumber5(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber5_ramdata)
);
ram_bignumber6 ram_bignumber6(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber6_ramdata)
);
ram_bignumber7 ram_bignumber7(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber7_ramdata)
);
ram_bignumber8 ram_bignumber8(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber8_ramdata)
);
ram_bignumber9 ram_bignumber9(
    .address(address),
    .clock(clock),
    .data(indata),
    .wren(0),
    .q(bignumber9_ramdata)
);
endmodule