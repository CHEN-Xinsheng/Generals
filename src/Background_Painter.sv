module Background_Painter(
	input wire clk,
	input wire[9:0] hdata,
	input wire[9:0] vdata,
	output wire[7:0] video_red,
	output wire[7:0] video_green,
	output wire[7:0] video_blue
);

always_comb begin
	if (!(hdata == 40 || hdata==80 || hdata==120 || hdata == 160|| hdata == 200 
	   || hdata==240 || hdata==280 || hdata == 320 || hdata==360 || hdata==400 || hdata==440 
	   || vdata == 40 || vdata==80 || vdata==120 || vdata == 160 || vdata == 200 
	   || vdata==240 || vdata==280 || vdata == 320 || vdata==360 || vdata==400 || vdata==440) 
	   &&hdata>=40&&hdata<=440 &&vdata>=40&&vdata<=440) begin
		video_red = 255;
		video_green = 255;
		video_blue = 255;
	end else begin 
		video_red = 0;
		video_green = 0;
		video_blue = 0;
	end
end
	
endmodule	