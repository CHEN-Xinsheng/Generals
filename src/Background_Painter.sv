module Background_Painter(
	input wire clk,
	input wire[11:0] hdata,
	input wire[11:0] vdata,
	output wire[7:0] video_red,
	output wire[7:0] video_green,
	output wire[7:0] video_blue
);

always_comb begin
	if (!(hdata == 50 || hdata==100 || hdata==150 || hdata == 200 || hdata == 250 || hdata==300 || hdata==350 || hdata == 400 || hdata==450 || hdata==500 || hdata==550 || vdata == 50 || vdata==100 || vdata==150 || vdata == 200 || vdata == 250 || vdata==300 || vdata==350 || vdata == 400 || vdata==450 || vdata==500 || vdata==550) &&hdata>=50&&hdata<=550 &&vdata>=50&&vdata<=550) begin
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