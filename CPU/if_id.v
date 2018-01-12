`include "defines.v"
//输入复位信号、时钟信号、取指阶段所取得的指令地址、取指阶段取得的指令
//输出译码阶段指令对应的地址和译码阶段的指令
module if_id(

	input	wire	clk,
	input wire	rst,
	//来自控制模块的信息
	input wire[5:0]               stall,

	input wire[`InstAddrBus]	if_pc,
	input wire[`InstBus]	if_inst,
	output reg[`InstAddrBus]	id_pc,
	output reg[`InstBus]	id_inst  
	
);

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			id_pc <= `ZeroWord;
			id_inst <= `ZeroWord;
		end else if(stall[0] == `Stop) begin
			id_pc <= `ZeroWord;
			id_inst <= `ZeroWord;
			
	    end else if(stall[0] == `NoStop) begin
		  id_pc <= if_pc;
		  id_inst <= if_inst;
		end
	end

endmodule