/*
 -- ============================================================================
 -- FILE NAME	: cpu.v
 -- DESCRIPTION : CPU顶层模块。各个阶段模块及通用寄存器、CPU控制模块和SPM相连接。
 -- ----------------------------------------------------------------------------
 -- Revision  Date		  Coding_by	 Comment
 -- 1.0.0	  2011/06/27  suito		 创建新的
 -- ============================================================================
*/

/********** 通用头文件 **********/
`include "nettype.h"
`include "global_config.h"
`include "stddef.h"

/********** 单独的头文件 **********/
`include "isa.h"
`include "cpu.h"
`include "bus.h"
`include "spm.h"

/********** 模组 **********/

module cpu (
	/********** 时钟 & 复位 **********/
	input  wire					  clk,			   // 时钟
	input  wire					  clk_,			   // 倒钟
	input  wire					  reset,		   // 异步复位
	/********** 总线接口 **********/
	// IF Stage
	input  wire [`WordDataBus]	  if_bus_rd_data,  // 读取数据
	input  wire					  if_bus_rdy_,	   // 就绪
	input  wire					  if_bus_grnt_,	   // 总线许可
	output wire					  if_bus_req_,	   // 总线请求
	output wire [`WordAddrBus]	  if_bus_addr,	   // 地址
	output wire					  if_bus_as_,	   // 地址选通
	output wire					  if_bus_rw,	   // 读/写
	output wire [`WordDataBus]	  if_bus_wr_data,  // 读/写
	// MEM Stage
	input  wire [`WordDataBus]	  mem_bus_rd_data, // 读取数据
	input  wire					  mem_bus_rdy_,	   // 就绪
	input  wire					  mem_bus_grnt_,   // 总线许可
	output wire					  mem_bus_req_,	   // 总线请求
	output wire [`WordAddrBus]	  mem_bus_addr,	   // 地址
	output wire					  mem_bus_as_,	   // 地址选通
	output wire					  mem_bus_rw,	   // 读/写
	output wire [`WordDataBus]	  mem_bus_wr_data, // 读/写
	/********** 中断 **********/
	input  wire [`CPU_IRQ_CH-1:0] cpu_irq		   // 中断请求
);

	/********** 流水线寄存器 **********/
	// IF/ID
	wire [`WordAddrBus]			 if_pc;			 // 程序计数器
	wire [`WordDataBus]			 if_insn;		 // 命令
	wire						 if_en;			 // 流水线数据的有效性
	// ID/EXパイプラインレジスタ
	wire [`WordAddrBus]			 id_pc;			 // 程序计数器
	wire						 id_en;			 // 流水线数据的有效性
	wire [`AluOpBus]			 id_alu_op;		 // ALU操作
	wire [`WordDataBus]			 id_alu_in_0;	 // ALU输入 0
	wire [`WordDataBus]			 id_alu_in_1;	 // ALU输入 1
	wire						 id_br_flag;	 // 分支标志
	wire [`MemOpBus]			 id_mem_op;		 // 内存操作
	wire [`WordDataBus]			 id_mem_wr_data; // 内存写入数据
	wire [`CtrlOpBus]			 id_ctrl_op;	 // 控制操作
	wire [`RegAddrBus]			 id_dst_addr;	 // GPR写地址
	wire						 id_gpr_we_;	 // GPR写入已启用
	wire [`IsaExpBus]			 id_exp_code;	 // 异常代码
	// EX/MEMパイプラインレジスタ
	wire [`WordAddrBus]			 ex_pc;			 // 程序计数器
	wire						 ex_en;			 // 流水线数据的有效性
	wire						 ex_br_flag;	 // 分支标志
	wire [`MemOpBus]			 ex_mem_op;		 // 内存操作
	wire [`WordDataBus]			 ex_mem_wr_data; // 内存写入数据
	wire [`CtrlOpBus]			 ex_ctrl_op;	 // 控制寄存器操作
	wire [`RegAddrBus]			 ex_dst_addr;	 // 通用寄存器写地址
	wire						 ex_gpr_we_;	 // 通用寄存器写使能
	wire [`IsaExpBus]			 ex_exp_code;	 // 异常代码
	wire [`WordDataBus]			 ex_out;		 // 処理結果
	// MEM/WBパイプラインレジスタ
	wire [`WordAddrBus]			 mem_pc;		 // Progrand计数器
	wire						 mem_en;		 // 流水线数据的有效性
	wire						 mem_br_flag;	 // 分支标志
	wire [`CtrlOpBus]			 mem_ctrl_op;	 // 控制寄存器操作
	wire [`RegAddrBus]			 mem_dst_addr;	 // 通用寄存器写地址
	wire						 mem_gpr_we_;	 // 通用寄存器写使能
	wire [`IsaExpBus]			 mem_exp_code;	 // 异常代码
	wire [`WordDataBus]			 mem_out;		 // 処理結果
	/********** 流水线控制信号 **********/
	// ストール信号
	wire						 if_stall;		 // IFステージ
	wire						 id_stall;		 // IDステー
	wire						 ex_stall;		 // EX阶段
	wire						 mem_stall;		 // MEM阶段
	// フラッシュ信号
	wire						 if_flush;		 // IF阶段
	wire						 id_flush;		 // ID阶段
	wire						 ex_flush;		 // EX阶段
	wire						 mem_flush;		 // MEM阶段
	// 忙碌信号
	wire						 if_busy;		 // IF阶段
	wire						 mem_busy;		 // MEM阶段
	// その他の制御信号
	wire [`WordAddrBus]			 new_pc;		 // 新PC
	wire [`WordAddrBus]			 br_addr;		 // 分行地址
	wire						 br_taken;		 // 设立分行
	wire						 ld_hazard;		 // 道路危险
	/********** 通用寄存器信号 **********/
	wire [`WordDataBus]			 gpr_rd_data_0;	 // 读取数据 0
	wire [`WordDataBus]			 gpr_rd_data_1;	 // 读取数据 1
	wire [`RegAddrBus]			 gpr_rd_addr_0;	 // 读取地址 0
	wire [`RegAddrBus]			 gpr_rd_addr_1;	 // 读取地址 1
	/********** 控制寄存器信号 **********/
	wire [`CpuExeModeBus]		 exe_mode;		 // 执行模式
	wire [`WordDataBus]			 creg_rd_data;	 // 读取数据
	wire [`RegAddrBus]			 creg_rd_addr;	 // 读取地址
	/********** Interrupt Request **********/
	wire						 int_detect;	  // 中断检测
	/********** 便笺式存储器信号 **********/
	// IF阶段
	wire [`WordDataBus]			 if_spm_rd_data;  // 读取数据
	wire [`WordAddrBus]			 if_spm_addr;	  // 地址
	wire						 if_spm_as_;	  // 地址选通
	wire						 if_spm_rw;		  // 读/写
	wire [`WordDataBus]			 if_spm_wr_data;  // 写数据
	// MEM阶段
	wire [`WordDataBus]			 mem_spm_rd_data; // 读取数据
	wire [`WordAddrBus]			 mem_spm_addr;	  // 地址
	wire						 mem_spm_as_;	  // 地址选通
	wire						 mem_spm_rw;	  // 读/写
	wire [`WordDataBus]			 mem_spm_wr_data; // 写数据
	/********** フォワーディング信号 **********/
	wire [`WordDataBus]			 ex_fwd_data;	  // EX阶段
	wire [`WordDataBus]			 mem_fwd_data;	  // MEM阶段

	/********** IF阶段 **********/
	if_stage if_stage (
		/********** 时钟和复位 **********/
		.clk			(clk),				// 时钟
		.reset			(reset),			// 异步复位
		/********** SPM接口 **********/
		.spm_rd_data	(if_spm_rd_data),	// 读取数据
		.spm_addr		(if_spm_addr),		// 地址
		.spm_as_		(if_spm_as_),		// 地址选通
		.spm_rw			(if_spm_rw),		// 读/写
		.spm_wr_data	(if_spm_wr_data),	// 读/写
		/********** 总线接口 **********/
		.bus_rd_data	(if_bus_rd_data),	// 读取数据
		.bus_rdy_		(if_bus_rdy_),		// 就绪
		.bus_grnt_		(if_bus_grnt_),		// 总线许可
		.bus_req_		(if_bus_req_),		// 总线请求
		.bus_addr		(if_bus_addr),		// 地址
		.bus_as_		(if_bus_as_),		// 地址选通
		.bus_rw			(if_bus_rw),		// 读/写
		.bus_wr_data	(if_bus_wr_data),	// 读/写
		/********** 流水线控制信号 **********/
		.stall			(if_stall),			// ストール
		.flush			(if_flush),			// フラッシュ
		.new_pc			(new_pc),			// 新PC
		.br_taken		(br_taken),			// 设立分行
		.br_addr		(br_addr),			// 分行目的地地址
		.busy			(if_busy),			// 忙碌信号
		/********** IF/IDパイプラインレジスタ **********/
		.if_pc			(if_pc),			// 程序计数器
		.if_insn		(if_insn),			// 命令
		.if_en			(if_en)				// 流水线数据的有效性
	);

	/********** ID阶段 **********/
	id_stage id_stage (
		/********** 时钟和复位 **********/
		.clk			(clk),				// 时钟
		.reset			(reset),			// 异步复位
		/********** GPR接口 **********/
		.gpr_rd_data_0	(gpr_rd_data_0),	// 读取数据 0
		.gpr_rd_data_1	(gpr_rd_data_1),	// 读取数据 1
		.gpr_rd_addr_0	(gpr_rd_addr_0),	// 读取地址 0
		.gpr_rd_addr_1	(gpr_rd_addr_1),	// 读取地址 1
		/********** 数据直通 **********/
		// EXステージからのフォワーディング
		.ex_en			(ex_en),			// 流水线数据的有效性
		.ex_fwd_data	(ex_fwd_data),		// 转发数据
		.ex_dst_addr	(ex_dst_addr),		// 写地址
		.ex_gpr_we_		(ex_gpr_we_),		// 启用写入
		// MEMステージからのフォワーディング
		.mem_fwd_data	(mem_fwd_data),		// 转发数据
		/********** 控制寄存器接口 **********/
		.exe_mode		(exe_mode),			// 执行模式
		.creg_rd_data	(creg_rd_data),		// 读取数据
		.creg_rd_addr	(creg_rd_addr),		// 读取地址
		/********** パイプライン制御信号 **********/
	   .stall		   (id_stall),		   // ストール
		.flush			(id_flush),			// フラッシュ
		.br_addr		(br_addr),			// 分行地址
		.br_taken		(br_taken),			// 设立分行
		.ld_hazard		(ld_hazard),		// 道路危险
		/********** IF/IDパイプラインレジスタ **********/
		.if_pc			(if_pc),			// 程序计数器
		.if_insn		(if_insn),			// 命令
		.if_en			(if_en),			// 流水线数据的有效性
		/********** ID/EXパイプラインレジスタ **********/
		.id_pc			(id_pc),			// 程序计数器
		.id_en			(id_en),			// 流水线数据的有效性
		.id_alu_op		(id_alu_op),		// ALU操作
		.id_alu_in_0	(id_alu_in_0),		// ALU输入 0
		.id_alu_in_1	(id_alu_in_1),		// ALU输入 1
		.id_br_flag		(id_br_flag),		// 分支标志
		.id_mem_op		(id_mem_op),		// 内存操作
		.id_mem_wr_data (id_mem_wr_data),	// 内存写入数据
		.id_ctrl_op		(id_ctrl_op),		// 控制操作
		.id_dst_addr	(id_dst_addr),		// GPR写地址
		.id_gpr_we_		(id_gpr_we_),		// GPR写入已启用
		.id_exp_code	(id_exp_code)		// 异常代码
	);

	/********** EX阶段 **********/
	ex_stage ex_stage (
		/********** 时钟和复位 **********/
		.clk			(clk),				// 时钟
		.reset			(reset),			// 异步复位
		/********** パイプライン制御信号 **********/
		.stall			(ex_stall),			// ストール
		.flush			(ex_flush),			// フラッシュ
		.int_detect		(int_detect),		// 中断检测
		/********** 数据直通 **********/
		.fwd_data		(ex_fwd_data),		// 转发数据
		/********** ID/EXパイプラインレジスタ **********/
		.id_pc			(id_pc),			// 程序计数器
		.id_en			(id_en),			// 流水线数据的有效性
		.id_alu_op		(id_alu_op),		// ALU操作
		.id_alu_in_0	(id_alu_in_0),		// ALU输入 0
		.id_alu_in_1	(id_alu_in_1),		// ALU输入 1
		.id_br_flag		(id_br_flag),		// 分支标志
		.id_mem_op		(id_mem_op),		// 内存操作
		.id_mem_wr_data (id_mem_wr_data),	// 内存写入数据
		.id_ctrl_op		(id_ctrl_op),		// 控制寄存器操作
		.id_dst_addr	(id_dst_addr),		// 通用寄存器写地址
		.id_gpr_we_		(id_gpr_we_),		// 通用寄存器写使能
		.id_exp_code	(id_exp_code),		// 异常代码
		/********** EX/MEMパイプラインレジスタ **********/
		.ex_pc			(ex_pc),			// 程序计数器
		.ex_en			(ex_en),			// 流水线数据的有效性
		.ex_br_flag		(ex_br_flag),		// 分支标志
		.ex_mem_op		(ex_mem_op),		// 内存操作
		.ex_mem_wr_data (ex_mem_wr_data),	// 内存写入数据
		.ex_ctrl_op		(ex_ctrl_op),		// 控制寄存器操作
		.ex_dst_addr	(ex_dst_addr),		// 通用寄存器写地址
		.ex_gpr_we_		(ex_gpr_we_),		// 通用寄存器写使能
		.ex_exp_code	(ex_exp_code),		// 异常代码
		.ex_out			(ex_out)			// 処理結果
	);

	/********** MEM阶段 **********/
	mem_stage mem_stage (
		/********** 时钟和复位 **********/
		.clk			(clk),				// 时钟
		.reset			(reset),			// 异步复位
		/********** パイプライン制御信号 **********/
		.stall			(mem_stall),		// ストール
		.flush			(mem_flush),		// フラッシュ
		.busy			(mem_busy),			// 忙碌信号
		/********** フォワーディング **********/
		.fwd_data		(mem_fwd_data),		// 转发数据
		/********** SPMインタフェース **********/
		.spm_rd_data	(mem_spm_rd_data),	// 读取数据
		.spm_addr		(mem_spm_addr),		// 地址
		.spm_as_		(mem_spm_as_),		// 地址选通
		.spm_rw			(mem_spm_rw),		// 读/写
		.spm_wr_data	(mem_spm_wr_data),	// 读/写
		/********** 总线接口 **********/
		.bus_rd_data	(mem_bus_rd_data),	// 读取数据
		.bus_rdy_		(mem_bus_rdy_),		// 就绪
		.bus_grnt_		(mem_bus_grnt_),	// 总线许可
		.bus_req_		(mem_bus_req_),		// 总线请求
		.bus_addr		(mem_bus_addr),		// 地址
		.bus_as_		(mem_bus_as_),		// 地址选通
		.bus_rw			(mem_bus_rw),		// 读/写
		.bus_wr_data	(mem_bus_wr_data),	// 读/写
		/********** EX/MEMパイプラインレジスタ **********/
		.ex_pc			(ex_pc),			// 程序计数器
		.ex_en			(ex_en),			// 流水线数据的有效性
		.ex_br_flag		(ex_br_flag),		// 分支标志
		.ex_mem_op		(ex_mem_op),		// 内存操作
		.ex_mem_wr_data (ex_mem_wr_data),	// 内存写入数据
		.ex_ctrl_op		(ex_ctrl_op),		// 控制寄存器操作
		.ex_dst_addr	(ex_dst_addr),		// 通用寄存器写地址
		.ex_gpr_we_		(ex_gpr_we_),		// 通用寄存器写使能
		.ex_exp_code	(ex_exp_code),		// 异常代码
		.ex_out			(ex_out),			// 処理結果
		/********** MEM/WBパイプラインレジスタ **********/
		.mem_pc			(mem_pc),			// Progrand计数器
		.mem_en			(mem_en),			// 流水线数据的有效性
		.mem_br_flag	(mem_br_flag),		// 分支标志
		.mem_ctrl_op	(mem_ctrl_op),		// 控制寄存器操作
		.mem_dst_addr	(mem_dst_addr),		// 通用寄存器写地址
		.mem_gpr_we_	(mem_gpr_we_),		// 通用寄存器写使能
		.mem_exp_code	(mem_exp_code),		// 异常代码
		.mem_out		(mem_out)			// 処理結果
	);

	/********** 控制单元 **********/
	ctrl ctrl (
		/********** 时钟和复位 **********/
		.clk			(clk),				// 时钟
		.reset			(reset),			// 异步复位
		/********** 制御レジスタインタフェース **********/
		.creg_rd_addr	(creg_rd_addr),		// 读取地址
		.creg_rd_data	(creg_rd_data),		// 读取数据
		.exe_mode		(exe_mode),			// 执行模式
		/********** 中断 **********/
		.irq			(cpu_irq),			// 中断请求
		.int_detect		(int_detect),		// 中断检测
		/********** ID/EXパイプラインレジスタ **********/
		.id_pc			(id_pc),			// 程序计数器
		/********** MEM/WBパイプラインレジスタ **********/
		.mem_pc			(mem_pc),			// Progrand计数器
		.mem_en			(mem_en),			// 流水线数据的有效性
		.mem_br_flag	(mem_br_flag),		// 分支标志
		.mem_ctrl_op	(mem_ctrl_op),		// 控制寄存器操作
		.mem_dst_addr	(mem_dst_addr),		// 通用寄存器写地址
		.mem_exp_code	(mem_exp_code),		// 异常代码
		.mem_out		(mem_out),			// 処理結果
		/********** パイプライン制御信号 **********/
		// パイプラインの状態
		.if_busy		(if_busy),			// IF阶段忙
		.ld_hazard		(ld_hazard),		// Loadハザード
		.mem_busy		(mem_busy),			// MEM阶段忙
		// ストール信号
		.if_stall		(if_stall),			// IF阶段标志
		.id_stall		(id_stall),			// ID阶段标志
		.ex_stall		(ex_stall),			// EX阶段标志
		.mem_stall		(mem_stall),		// MEM阶段标志
		// フラッシュ信号
		.if_flush		(if_flush),			// IF阶段标志闪光
		.id_flush		(id_flush),			// ID阶段标志闪光
		.ex_flush		(ex_flush),			// EX阶段标志闪光
		.mem_flush		(mem_flush),		// MEM阶段标志闪光
		// 新程序计数器
		.new_pc			(new_pc)			// 新程序计数器
	);

	/********** 通用寄存器 **********/
	gpr gpr (
		/********** 时钟和复位 **********/
		.clk	   (clk),					// 时钟
		.reset	   (reset),					// 异步复位
		/********** 読み出しポート 0 **********/
		.rd_addr_0 (gpr_rd_addr_0),			// 读取地址
		.rd_data_0 (gpr_rd_data_0),			// 读取数据
		/********** 読み出しポート 1 **********/
		.rd_addr_1 (gpr_rd_addr_1),			// 读取地址
		.rd_data_1 (gpr_rd_data_1),			// 读取数据
		/********** 書き込みポート **********/
		.we_	   (mem_gpr_we_),			// 启用写入
		.wr_addr   (mem_dst_addr),			// 写地址
		.wr_data   (mem_out)				// 读/写
	);

	/********** 便笺式存储器 **********/
	spm spm (
		/********** 时钟 **********/
		.clk			 (clk_),					  // 时钟
		/********** ポートA : IFステージ **********/
		.if_spm_addr	 (if_spm_addr[`SpmAddrLoc]),  // 地址
		.if_spm_as_		 (if_spm_as_),				  // 地址选通
		.if_spm_rw		 (if_spm_rw),				  // 读/写
		.if_spm_wr_data	 (if_spm_wr_data),			  // 读/写
		.if_spm_rd_data	 (if_spm_rd_data),			  // 读取数据
		/********** ポートB : MEMステージ **********/
		.mem_spm_addr	 (mem_spm_addr[`SpmAddrLoc]), // 地址
		.mem_spm_as_	 (mem_spm_as_),				  // 地址选通
		.mem_spm_rw		 (mem_spm_rw),				  // 读/写
		.mem_spm_wr_data (mem_spm_wr_data),			  // 读/写
		.mem_spm_rd_data (mem_spm_rd_data)			  // 读取数据
	);

endmodule
