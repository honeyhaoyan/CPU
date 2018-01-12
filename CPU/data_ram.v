`include "defines.v"

module data_ram(

	input	wire										clk,
	input wire										ce,
	input wire										we,
	input wire[`DataAddrBus]			addr,
	input wire[3:0]								sel,
	input wire[`DataBus]						data_i,
	output reg[`DataBus]					data_o

);
	reg[7 : 0] data_mem[0: `DataMemNum - 1];

	always @ (posedge clk) begin
		if (ce == `ChipDisable) begin
		end else if(we == `WriteEnable) begin
			  if (sel == 4'b0100) begin
		     {data_mem[addr + 3],data_mem[addr + 2],data_mem[addr + 1],data_mem[addr]} <= data_i[31:0];
			 end
			  else if (sel == 4'b0010) begin
		      {data_mem[addr + 1],data_mem[addr]} <= data_i[15:0];
			  end
		  	  else if (sel == 4'b0001) begin
		      {data_mem[addr]} <= data_i[7:0];
			end
		end
	end

	always @ (*) begin
		if (ce == `ChipDisable) begin
			data_o <= `ZeroWord;
	  end else if(we == `WriteDisable) begin
		    data_o <=  {data_mem[addr + 3],data_mem[addr + 2],data_mem[addr + 1],data_mem[addr]};
		end else begin
				data_o <= `ZeroWord;
		end
	end

endmodule