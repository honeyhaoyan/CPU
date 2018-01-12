`include "defines.v"

//输入复位信号rst 1、时钟信号clk 1
//输入要写入的寄存器地址waddr 5, 要写入的数据wdata 32, 写使能信号we 1
//输入第一个读寄存器要读入的寄存器地址 raddr1 5, 第一个读寄存器端口读使能信号re1 1
//输出第一个读寄存器输出的寄存器值rdata1 32
//输入第二个读寄存器要读入的寄存器地址 raddr2 5, 第二个读寄存器端口读使能信号re2 1
//输出第二个读寄存器输出的寄存器值rdata2 32
module regfile(

	input	wire	clk,
	input wire	rst,
	
	//写端口
	input wire	we,
	input wire[`RegAddrBus]	waddr,
	input wire[`RegBus]	wdata,
	
	//读端口1
	input wire	re1,
	input wire[`RegAddrBus]	raddr1,
	output reg[`RegBus]	rdata1,
	
	//读端口2
	input wire	re2,
	input wire[`RegAddrBus]	raddr2,
	output reg[`RegBus]	rdata2
	
);
    //定义32个32位寄存器
	reg[`RegBus]  regs[0:`RegNum-1];
    initial regs[0] = 0;
	always @ (posedge clk) begin
		if (rst == `RstDisable) begin
			if((we == `WriteEnable) && (waddr != `RegNumLog2'h0)) begin
				regs[waddr] <= wdata;
			end
		end
	end
	
	always @ (*) begin
		if(rst == `RstEnable) begin
			  rdata1 <= `ZeroWord;
	  end else if(raddr1 == `RegNumLog2'h0) begin
	  		rdata1 <= `ZeroWord;
	  end else if((raddr1 == waddr) && (we == `WriteEnable) 
	  	            && (re1 == `ReadEnable)) begin
	  	  rdata1 <= wdata;
	  end else if(re1 == `ReadEnable) begin  //
	      rdata1 <= regs[raddr1];            //
	  end else begin
	      rdata1 <= `ZeroWord;
	  end
	end

	always @ (*) begin
		if(rst == `RstEnable) begin
			  rdata2 <= `ZeroWord;
	  end else if(raddr2 == `RegNumLog2'h0) begin
	  		rdata2 <= `ZeroWord;
	  end else if((raddr2 == waddr) && (we == `WriteEnable) 
	  	            && (re2 == `ReadEnable)) begin
	  	  rdata2 <= wdata;
	  end else if(re2 == `ReadEnable) begin    //
	      rdata2 <= regs[raddr2];              //
	  end else begin
	      rdata2 <= `ZeroWord;
	  end
	end

endmodule