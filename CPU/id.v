`include "defines.v"

module id(

	input wire										rst,
	input wire[`InstAddrBus]			pc_i,
	input wire[`InstBus]          inst_i,

	//处于执行阶段的指令要写入的目的寄存器信息
	input wire										ex_wreg_i,
	input wire[`RegBus]						ex_wdata_i,
	input wire[`RegAddrBus]       ex_wd_i,
	
	//处于访存阶段的指令要写入的目的寄存器信息
	input wire					  mem_wreg_i,
	input wire[`RegBus]			  mem_wdata_i,
	input wire[`RegAddrBus]       mem_wd_i,
	
	input wire[`RegBus]           reg1_data_i,
	input wire[`RegBus]           reg2_data_i,
	
	input wire                    is_in_delayslot_i,

	//送到regfile的信息
	output reg                    reg1_read_o,
	output reg                    reg2_read_o,     
	output reg[`RegAddrBus]       reg1_addr_o,
	output reg[`RegAddrBus]       reg2_addr_o, 	      
	
	//送到执行阶段的信息
	output reg[`AluOpBus]         aluop_o,
	output reg[`AluSelBus]        alusel_o,
	output reg[`RegBus]           reg1_o,
	output reg[`RegBus]           reg2_o,
	output reg[`RegAddrBus]       wd_o,
	output reg                    wreg_o,
	output wire[`RegBus]          inst_o,
	
	output reg                   stallreq,
	output reg                    next_inst_in_delayslot_o,
	
	output reg                    branch_flag_o,
	output reg[`RegBus]           branch_target_address_o,       
	output reg[`RegBus]           link_addr_o,
	output reg                    is_in_delayslot_o
	

);
  wire[31:0] tmp;
  //wire[31:0] checkup1={{12{inst_i[31]}},inst_i[19:12],inst_i[20],inst_i[30:21],1'b0};
 
  assign tmp = {inst_i[7:0],inst_i[15:8],inst_i[23:16],inst_i[31:24]};
  
  
  wire[6:0] op1 = tmp[6:0];
  wire[2:0] op2 = tmp[14:12];
  wire[6:0] op3 = tmp[31:25];
  //wire[31:0] address_JAL=pc_i+{{12{tmp[31]}},tmp[19:12],tmp[20],tmp[30:21],1'b0};
  wire[31:0] lookup={{12{tmp[31]}},tmp[19:12],tmp[20],tmp[30:21],1'b0};
  wire[3:0] lookup2=lookup[3:0];
  wire[11:0] address_JALR = reg1_data_i+{20'b0,inst_i[31:20],1'b0};
  wire[11:0] address_BNE= pc_i+{12'b0,inst_i[31],inst_i[7],inst_i[30:25],inst_i[11:8]};
  
  /*wire[6:0] op1 = inst_i[6:0];
  wire[2:0] op2 = inst_i[14:12];
  wire[6:0] op3 = inst_i[31:25];*/
  reg[`RegBus]	imm;
  reg instvalid;
  wire[`RegBus] pc_plus_8;
  wire[`RegBus] pc_plus_4;
  wire[`RegBus] imm_sll2_signedext;  
  
  assign pc_plus_8 = pc_i + 8;
  assign pc_plus_4 = pc_i +4;
  assign imm_sll2_signedext = {{14{tmp[15]}}, tmp[15:0], 2'b00 }; 
  assign inst_o = inst_i;
 
  reg[1:0] stallreq = `NoStop;
  //reg[1:0] branch_flag_o <= `NotBranch;
  reg[1:0] testself;
  always @ (*) begin	
		stallreq = `NoStop;
		branch_flag_o <= `NotBranch;
		testself=1'b0;
		if (rst == `RstEnable) begin
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			wd_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
			instvalid <= `InstValid;
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			reg1_addr_o <= `NOPRegAddr;
			reg2_addr_o <= `NOPRegAddr;
			imm <= 32'h0;		
			stallreq <= `NoStop;
			//branch_flag_o <= `NotBranch;
			testself<=1'b0;
		end else begin  //不复位
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			wd_o <= tmp[11:7];
			wreg_o <= `WriteDisable;
			instvalid <= `InstInvalid;	   
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			reg1_addr_o <= tmp[19:15];
			reg2_addr_o <= tmp[24:20];		
			imm <= `ZeroWord;
			stallreq <= `NoStop;
			//branch_flag_o <= `NotBranch;
			testself<=1'b0;
			
		  case (op1)
		    `OP_LUI: begin //构造32位常数，并把20位立即数放到RD的高20位，剩余12位补0
					wreg_o <= `WriteEnable;		
					aluop_o <= `EXE_OR_OP;
					alusel_o <= `EXE_RES_LOGIC; 
					reg1_read_o <= 1'b0;	
					reg2_read_o <= 1'b0;	  	
					imm <= {tmp[31:12], 12'h0};		
					wd_o <= tmp[11:7];		  	
					instvalid <= `InstValid;	
					end
			`OP_AUIPC: begin 
			
			        end
			`OP_JAL: begin 
					wreg_o <= `WriteEnable;		
					aluop_o <= `EXE_JAL_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH; 
					reg1_read_o <= 1'b0;	
					reg2_read_o <= 1'b0;
					//wd_o <= 5'b11111;	
					wd_o<=inst_i[11:7];
					link_addr_o <= pc_plus_4 ;
					//branch_target_address_o <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
					//branch_target_address_o <= address_JAL[31:0];
					branch_target_address_o <={{12{tmp[31]}},tmp[19:12],tmp[20],tmp[30:21],1'b0}+pc_i;
					branch_flag_o <= `Branch;
					next_inst_in_delayslot_o <= `InDelaySlot;		  	
					instvalid <= `InstValid;
					stallreq<=`Stop;
					testself<=1'b1;
			        end
			`OP_JALR: begin
					wreg_o <= `WriteEnable;		
					aluop_o <= `EXE_JALR_OP;
		  			alusel_o <= `EXE_RES_JUMP_BRANCH;   
					reg1_read_o <= 1'b1;	
					reg2_read_o <= 1'b0;
		  			wd_o <= inst_i[11:7];
		  			link_addr_o <= pc_plus_4;
		  			branch_target_address_o <= reg1_o + {20'b0,inst_i[31:20]};
			        branch_flag_o <= `Branch;
			        next_inst_in_delayslot_o <= `InDelaySlot;
			        instvalid <= `InstValid;
					stallreq<=`Stop;//
					testself<=1'b1;
			        end
			`OP_BRANCH: begin
			                case (op2)
					            `FUNCT3_BEQ: begin
											wreg_o <= `WriteDisable;		
											aluop_o <= `EXE_BEQ_OP;
											alusel_o <= `EXE_RES_JUMP_BRANCH; 
											reg1_read_o <= 1'b1;	
											reg2_read_o <= 1'b1;
											instvalid <= `InstValid;
											if(reg1_o == reg2_o) begin
											branch_target_address_o <= pc_i+{{20{tmp[31]}}, tmp[7],tmp[30:25], tmp[11:8], 1'b0};
											branch_flag_o <= `Branch;
											next_inst_in_delayslot_o <= `InDelaySlot;	
											stallreq<=`Stop;
											testself<=1'b1;
											end	
											end
								`FUNCT3_BNE: begin
											wreg_o <= `WriteDisable;		
											aluop_o <= `EXE_BEQ_OP;
											alusel_o <= `EXE_RES_JUMP_BRANCH; 
											reg1_read_o <= 1'b1;	
											reg2_read_o <= 1'b1;
											instvalid <= `InstValid;
											if(reg1_o != reg2_o) begin
											branch_target_address_o <= pc_i+{{20{tmp[31]}}, tmp[7],tmp[30:25], tmp[11:8], 1'b0};
											branch_flag_o <= `Branch;
											next_inst_in_delayslot_o <= `InDelaySlot;	
											stallreq<=`Stop;
											testself<=1'b1;
											end
											end
								`FUNCT3_BLT: begin
											wreg_o <= `WriteDisable;		
											aluop_o <= `EXE_BEQ_OP;
											alusel_o <= `EXE_RES_JUMP_BRANCH; 
											reg1_read_o <= 1'b1;	
											reg2_read_o <= 1'b1;
											instvalid <= `InstValid;
											if($signed(reg1_o) < $signed(reg2_o)) begin
											branch_target_address_o <= pc_i+{{20{tmp[31]}}, tmp[7],tmp[30:25], tmp[11:8], 1'b0};
											branch_flag_o <= `Branch;
											next_inst_in_delayslot_o <= `InDelaySlot;	
											stallreq<=`Stop;
											testself<=1'b1;
											end
											end
								`FUNCT3_BGE: begin
											wreg_o <= `WriteDisable;		
											aluop_o <= `EXE_BEQ_OP;
											alusel_o <= `EXE_RES_JUMP_BRANCH; 
											reg1_read_o <= 1'b1;	
											reg2_read_o <= 1'b1;
											instvalid <= `InstValid;
											if($signed(reg1_o) >= $signed(reg2_o)) begin
											branch_target_address_o <= pc_i+{{20{tmp[31]}}, tmp[7],tmp[30:25], tmp[11:8], 1'b0};
											branch_flag_o <= `Branch;
											next_inst_in_delayslot_o <= `InDelaySlot;
											stallreq<=`Stop;
											testself<=1'b1;
											end
											end
								`FUNCT3_BLTU:begin
											wreg_o <= `WriteDisable;		
											aluop_o <= `EXE_BEQ_OP;
											alusel_o <= `EXE_RES_JUMP_BRANCH; 
											reg1_read_o <= 1'b1;	
											reg2_read_o <= 1'b1;
											instvalid <= `InstValid;
											if(reg1_o < reg2_o) begin
											branch_target_address_o <= pc_i+{{20{tmp[31]}}, tmp[7],tmp[30:25], tmp[11:8], 1'b0};
											branch_flag_o <= `Branch;
											next_inst_in_delayslot_o <= `InDelaySlot;	
											stallreq<=`Stop;
											testself<=1'b1;
											end
											end
								`FUNCT3_BGEU: begin
											wreg_o <= `WriteDisable;		
											aluop_o <= `EXE_BEQ_OP;
											alusel_o <= `EXE_RES_JUMP_BRANCH; 
											reg1_read_o <= 1'b1;	
											reg2_read_o <= 1'b1;
											instvalid <= `InstValid;
											if(reg1_o >= reg2_o) begin
											branch_target_address_o <= pc_i+{{20{tmp[31]}}, tmp[7],tmp[30:25], tmp[11:8], 1'b0};
											branch_flag_o <= `Branch;
											next_inst_in_delayslot_o <= `InDelaySlot;	
											stallreq<=`Stop;
											testself<=1'b1;
											end
											end
								default: begin
										end
							endcase
			            end
			`OP_LOAD :begin
						case(op2)
							`FUNCT3_LB: begin //8位数值
							            wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_LB_OP;
										alusel_o <= `EXE_RES_LOAD_STORE; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;
										wd_o <= tmp[11:7]; 
										instvalid <= `InstValid;
										end
							`FUNCT3_LH: begin //LH指令从存储器中读取一个16位数值，然后将其进行符号扩展到32位，再保存到rd中
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_LH_OP;
										alusel_o <= `EXE_RES_LOAD_STORE; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;
										wd_o <= tmp[11:7]; 
										instvalid <= `InstValid;
										end
							`FUNCT3_LW: begin //LW指令将一个32位数值从存储器复制到rd中
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_LW_OP;
										alusel_o <= `EXE_RES_LOAD_STORE; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;
										wd_o <= tmp[11:7]; 
										instvalid <= `InstValid;
										end
							`FUNCT3_LBU: begin //8位数值
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_LBU_OP;
										alusel_o <= `EXE_RES_LOAD_STORE; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;
										wd_o <= tmp[11:7]; 
										instvalid <= `InstValid;
										end
							`FUNCT3_LHU: begin //LHU指令存储器中读取一个16位数值，然后将其进行零扩展到32位，再保存到rd中
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_LHU_OP;
										alusel_o <= `EXE_RES_LOAD_STORE; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;
										wd_o <= tmp[11:7]; 
										instvalid <= `InstValid;
										end
							default: begin
							end
						endcase
			        end
			`OP_STORE :begin
						//SW、SH、SB指令分别将从rs2低位开始的32位、16位、8位数值保存到存储器中
						case(op2)
							`FUNCT3_SB:begin
										wreg_o <= `WriteDisable;		
										aluop_o <= `EXE_SB_OP;
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b1; 
										instvalid <= `InstValid;
										alusel_o <= `EXE_RES_LOAD_STORE;
										end
							`FUNCT3_SH :begin
										wreg_o <= `WriteDisable;		
										aluop_o <= `EXE_SH_OP;
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b1; 
										instvalid <= `InstValid;
										alusel_o <= `EXE_RES_LOAD_STORE;
										end
							`FUNCT3_SW:begin
										wreg_o <= `WriteDisable;		
										aluop_o <= `EXE_SW_OP;
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b1; 
										instvalid <= `InstValid;
										alusel_o <= `EXE_RES_LOAD_STORE;
										end
							default: begin
							end
						endcase
					end
			`OP_OP_IMM:begin
						case(op2)
							`FUNCT3_ADDI:begin  //将符号扩展的12位立即数加到寄存器rs1上,算术溢出被忽略，而结果就是运算结果的低XLEN位
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_ADDI_OP;
										alusel_o <= `EXE_RES_ARITHMETIC; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm <= {{20{tmp[31]}}, tmp[31:20]};	
										wd_o <= tmp[11:7];		  	
										instvalid <= `InstValid;	
										end
							`FUNCT3_SLTI:begin  //如果寄存器rs1小于符号扩展的立即数（比较时，两者都作为有符号数）,将数值1放到寄存器rd中
												//否则将0写入rd
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_SLT_OP;
										alusel_o <= `EXE_RES_ARITHMETIC; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm <= {{20{tmp[31]}}, tmp[31:20]};		
										wd_o <= tmp[11:7];		  	
										instvalid <= `InstValid;	
										end
							`FUNCT3_SLTIU:begin //立即数被首先符号扩展为XLEN位，然后被作为一个无符号数比较
												//SLTIU rd,rs1,1将设置rd为1，如果rs1等于0，否则将rd设置为0
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_SLTU_OP;
										alusel_o <= `EXE_RES_ARITHMETIC;
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm <= {{20{tmp[31]}}, tmp[31:20]};		
										wd_o <= tmp[11:7];		  	
										instvalid <= `InstValid;	
										end
							`FUNCT3_XORI:begin  //在寄存器rs1和符号扩展的12位立即数上执行按位AND、OR、XOR操作，并把结果写入rd
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_XOR_OP;
										alusel_o <= `EXE_RES_LOGIC;	
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm <= {{20{tmp[31]}}, tmp[31:20]};	
										wd_o <= tmp[11:7];		  	
										instvalid <= `InstValid;
										end
							`FUNCT3_ORI:begin
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_OR_OP;
										alusel_o <= `EXE_RES_LOGIC; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm <= {{20{tmp[31]}}, tmp[31:20]};		
										wd_o <= tmp[11:7];
										instvalid <= `InstValid;	
										end
							`FUNCT3_ANDI:begin
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_AND_OP;
										alusel_o <= `EXE_RES_LOGIC;	
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm <= {{20{tmp[31]}}, tmp[31:20]};	
										wd_o <= tmp[11:7];		  	
										instvalid <= `InstValid;	
										end
							`FUNCT3_SLLI:begin
										wreg_o <= `WriteEnable;		
										aluop_o <= `EXE_SLL_OP;
										alusel_o <= `EXE_RES_SHIFT; 
										reg1_read_o <= 1'b1;	
										reg2_read_o <= 1'b0;	  	
										imm[4:0] <= tmp[24:20];		
										wd_o <= tmp[11:7];
										instvalid <= `InstValid;	
										end
							`FUNCT3_SRLI_SRAI:begin
											case(op3)
											`FUNCT7_SRLI:begin
														wreg_o <= `WriteEnable;		
														aluop_o <= `EXE_SRL_OP;
														alusel_o <= `EXE_RES_SHIFT; 
														reg1_read_o <= 1'b1;	
														reg2_read_o <= 1'b0;	  	
														imm[4:0] <= tmp[24:20];			
														wd_o <= tmp[11:7];
														instvalid <= `InstValid;
														end
											`FUNCT7_SRAI:begin
														wreg_o <= `WriteEnable;		
														aluop_o <= `EXE_SRA_OP;
														alusel_o <= `EXE_RES_SHIFT; 
														reg1_read_o <= 1'b1;	
														reg2_read_o <= 1'b0;	  	
														imm[4:0] <= tmp[24:20];		
														wd_o <= tmp[11:7];
														instvalid <= `InstValid;
														end
											default: begin
														end
											endcase
											end
							default: begin
									end
						endcase
					end
			`OP_OP:begin
			        case(op2)
						`FUNCT3_ADD_SUB:begin
										case (op3)
											`FUNCT7_ADD:begin
														wreg_o <= `WriteEnable;		
														aluop_o <= `EXE_ADD_OP;
														alusel_o <= `EXE_RES_ARITHMETIC;		
														reg1_read_o <= 1'b1;	
														reg2_read_o <= 1'b1;
														instvalid <= `InstValid;	
														end
											`FUNCT7_SUB:begin
														wreg_o <= `WriteEnable;		
														aluop_o <= `EXE_SUB_OP;
														alusel_o <= `EXE_RES_ARITHMETIC;		
														reg1_read_o <= 1'b1;	
														reg2_read_o <= 1'b1;
														instvalid <= `InstValid;
														end
											default: begin
														end
										endcase
										end
						`FUNCT3_SLL:begin //SLL、SRL、SRA分别执行逻辑左移、逻辑右移、算术右移
										//SLL逻辑左移，立即数控制
									wreg_o <= `WriteEnable;		
									aluop_o <= `EXE_SLL_OP;
									alusel_o <= `EXE_RES_SHIFT; 
									reg1_read_o <= 1'b1;	
									reg2_read_o <= 1'b1;	  	
									//imm[4:0] <= tmp[24:20];		
									wd_o <= tmp[11:7];
									instvalid <= `InstValid;	
									end
						`FUNCT3_SLT:begin  //执行符号数的比较，如果rs1<rs2，则将1写入rd，否则写入0
									wreg_o <= `WriteEnable;		
									aluop_o <= `EXE_SLT_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		
									reg1_read_o <= 1'b1;	
									reg2_read_o <= 1'b1;
									instvalid <= `InstValid;
									end
						`FUNCT3_SLTU:begin  //执行无符号数的比较，如果rs1<rs2，则将1写入rd，否则写入0
									wreg_o <= `WriteEnable;		
									aluop_o <= `EXE_SLTU_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		
									reg1_read_o <= 1'b1;	
									reg2_read_o <= 1'b1;
									instvalid <= `InstValid;
									end
						`FUNCT3_XOR:begin
									wreg_o <= `WriteEnable;		
									aluop_o <= `EXE_XOR_OP;
									alusel_o <= `EXE_RES_LOGIC;		
									reg1_read_o <= 1'b1;	
									reg2_read_o <= 1'b1;	
									instvalid <= `InstValid;	
									end 
						`FUNCT3_SRL_SRA:begin
										case (op3)
											`FUNCT7_SRL:begin  //逻辑右移，寄存器
														wreg_o <= `WriteEnable;		
														aluop_o <= `EXE_SRL_OP;
														alusel_o <= `EXE_RES_SHIFT; 
														reg1_read_o <= 1'b1;	
														reg2_read_o <= 1'b1;	  	
														//imm[4:0] <= tmp[24:20];			
														wd_o <= tmp[11:7];
														instvalid <= `InstValid;	
														end
											`FUNCT7_SRA:begin   //算数右移，立即数控制。空出来的位置用rt[31]填充
														wreg_o <= `WriteEnable;		
														aluop_o <= `EXE_SRA_OP;
														alusel_o <= `EXE_RES_SHIFT; 
														reg1_read_o <= 1'b1;	
														reg2_read_o <= 1'b1;	  	
														//imm[4:0] <= tmp[24:20];		
														wd_o <= tmp[11:7];
														instvalid <= `InstValid;
														end
											default: begin
													end
										endcase
										end
						`FUNCT3_OR:begin
									wreg_o <= `WriteEnable;		
									aluop_o <= `EXE_OR_OP;
									alusel_o <= `EXE_RES_LOGIC; 	
									reg1_read_o <= 1'b1;	
									reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
									end
						`FUNCT3_AND:begin
									wreg_o <= `WriteEnable;		
									aluop_o <= `EXE_AND_OP;
									alusel_o <= `EXE_RES_LOGIC;	  
									reg1_read_o <= 1'b1;	
									reg2_read_o <= 1'b1;	
									instvalid <= `InstValid;
									end
				    default: begin
							end
					endcase
				end
			`OP_MISC_MEM:begin
						case(op2)
							`FUNCT3_FENCE:begin
							
										end
							`FUNCT3_FENCEI:begin
							
										end
						default: begin
								end	
						endcase
					end
			default: begin
			stallreq <= `NoStop;
			testself<=1'b0;
			//branch_flag_o <= `NotBranch;
            end			
		  endcase		  //case op
		  
		  /*if (inst_i[31:21] == 11'b00000000000) begin
		  	if (op3 == `EXE_SLL) begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLL_OP;
		  		alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;	  	
					imm[4:0] <= inst_i[10:6];		wd_o <= inst_i[15:11];
					instvalid <= `InstValid;	
				end else if ( op3 == `EXE_SRL ) begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRL_OP;
		  		alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;	  	
					imm[4:0] <= inst_i[10:6];		wd_o <= inst_i[15:11];
					instvalid <= `InstValid;	
				end else if ( op3 == `EXE_SRA ) begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRA_OP;
		  		alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;	  	
					imm[4:0] <= inst_i[10:6];		wd_o <= inst_i[15:11];
					instvalid <= `InstValid;	
				end
			end		  
		  */
		end       //if
		
	end         //always
	

	always @ (*) begin
		if(rst == `RstEnable) begin
			reg1_o <= `ZeroWord;		
		end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) 
								&& (ex_wd_i == reg1_addr_o)) begin
			reg1_o <= ex_wdata_i; 
		end else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) 
								&& (mem_wd_i == reg1_addr_o)) begin
			reg1_o <= mem_wdata_i; 			
		end else if(reg1_read_o == 1'b1) begin
			reg1_o <= reg1_data_i;
		end else if(reg1_read_o == 1'b0) begin
			reg1_o <= imm;
		end else begin
			reg1_o <= `ZeroWord;
	  end
	end
	
	always @ (*) begin
		if(rst == `RstEnable) begin
			reg2_o <= `ZeroWord;
		end else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) 
								&& (ex_wd_i == reg2_addr_o)) begin
			reg2_o <= ex_wdata_i; 
		end else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) 
								&& (mem_wd_i == reg2_addr_o)) begin
			reg2_o <= mem_wdata_i;			
	  end else if(reg2_read_o == 1'b1) begin
	  	reg2_o <= reg2_data_i;
	  end else if(reg2_read_o == 1'b0) begin
	  	reg2_o <= imm;
	  end else begin
	    reg2_o <= `ZeroWord;
	  end
	end

endmodule