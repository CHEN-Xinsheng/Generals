module Background_Painter(
	input wire clk,
	input wire[11:0] hdata,
	input wire[11:0] vdata,
	output wire[7:0] video_red,
	output wire[7:0] video_green,
	output wire[7:0] video_blue
);

always_comb begin
	if (!(hdata == 49 || hdata==100 || hdata==151 || hdata == 202 || hdata == 253 || hdata==304 || hdata==355 || hdata == 406 || hdata==457 || hdata==508 || hdata==559 || vdata == 49 || vdata==100 || vdata==151 || vdata == 202 || vdata == 253 || vdata==304 || vdata==355 || vdata == 406 || vdata==457 || vdata==508 || vdata==559) &&hdata>=49&&hdata<=559 &&vdata>=49&&vdata<=559) begin
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