module Number_Transfer
#(parameter BIT = 9)(
	input wire [BIT-1:0] number,
	output wire [3:0] ones,
	output wire [3:0] tens,
	output wire [3:0] hundreds
);

logic [BIT-1:0] removehundreds;
always_comb begin
	if (number < 100) begin
		hundreds = 0;
		removehundreds = number;
	end else if (number < 200 && number >= 100) begin
		hundreds = 1;
		removehundreds = number - 100;
	end else if (number < 300 && number >= 200) begin
		hundreds = 2;
		removehundreds = number - 200;
	end else if (number < 400 && number >= 300) begin
		hundreds = 3;
		removehundreds = number - 300;
	end else if (number < 500 && number >= 400) begin
		hundreds = 4;
		removehundreds = number - 400;
	end else if (number < 600 && number >= 500) begin
		hundreds = 5;
		removehundreds = number - 500;
	end else if (number < 700 && number >= 600) begin
		hundreds = 6;
		removehundreds = number - 600;
	end else if (number < 800 && number >= 700) begin
		hundreds = 7;
		removehundreds = number - 700;
	end else if (number < 900 && number >= 800) begin
		hundreds = 8;
		removehundreds = number - 800;
	end else begin
		hundreds = 9;
		removehundreds = number - 900;
	end
end
always_comb begin
	if (removehundreds < 10) begin
		tens = 0;
		ones = removehundreds;
	end else if (removehundreds < 20 && removehundreds >= 10) begin
		tens = 1;
		ones = removehundreds - 10;
	end else if (removehundreds < 30 && removehundreds >= 20) begin
		tens = 2;
		ones = removehundreds - 20;
	end else if (removehundreds < 40 && removehundreds >= 30) begin
		tens = 3;
		ones = removehundreds - 30;
	end else if (removehundreds < 50 && removehundreds >= 40) begin
		tens = 4;
		ones = removehundreds - 40;
	end else if (removehundreds < 60 && removehundreds >= 50) begin
		tens = 5;
		ones = removehundreds - 50;
	end else if (removehundreds < 70 && removehundreds >= 60) begin
		tens = 6;
		ones = removehundreds - 60;
	end else if (removehundreds < 80 && removehundreds >= 70) begin
		tens = 7;
		ones = removehundreds - 70;
	end else if (removehundreds < 90 && removehundreds >= 80) begin
		tens = 8;
		ones = removehundreds - 80;
	end else begin
		tens = 9;
		ones = removehundreds - 90;
	end
end
endmodule