/* 
 -- ============================================================================
 -- FILE NAME	: chip.v
 -- DESCRIPTION : 芯片
 -- ----------------------------------------------------------------------------
 -- Revision  Date		  Coding_by	 Comment
 -- 1.0.0	  2011/06/27  suito		 新規作成
 -- ============================================================================
*/

/********** 通用头文件 **********/
`include "nettype.h"
`include "stddef.h"
`include "global_config.h"

/********** 单个头文件 **********/
`include "cpu.h"
`include "bus.h"
`include "rom.h"
`include "timer.h"
`include "uart.h"
`include "gpio.h"

/********** 模块 **********/
module chip (
	/********** 时钟 & 复位 **********/
	input  wire						 clk,			// 时钟
	input  wire						 clk_,			// 反相时钟
	input  wire						 reset			// 复位
	/********** UART  **********/
`ifdef IMPLEMENT_UART // UART实现
	, input	 wire					 uart_rx	  	// UART接收信号
	, output wire					 uart_tx	  	// UART发送信号
`endif
	/********** 通用输入/输出端口 **********/
`ifdef IMPLEMENT_GPIO	// GPIO实现
`ifdef GPIO_IN_CH			// 输入端口的实现
	, input wire [`GPIO_IN_CH-1:0]	 gpio_in		// 输入端口
`endif
`ifdef GPIO_OUT_CH		// 输出端口实现
	, output wire [`GPIO_OUT_CH-1:0] gpio_out		// 输出端口
`endif
`ifdef GPIO_IO_CH			// 输入/输出端口的实现
	, inout wire [`GPIO_IO_CH-1:0]	 gpio_io		// 输入输出端口
`endif
`endif
);

	/********** 总线主控信号 **********/
	// 所有总线主控信号〜
	wire [`WordDataBus] m_rd_data;			//读取数据
	wire				m_rdy_;				//准备就绪
	// 总线主控器0
	wire				m0_req_;			// 总线请求
	wire [`WordAddrBus] m0_addr;			// 地址
	wire				m0_as_;				// 地址选通
	wire				m0_rw;				// 读/写
	wire [`WordDataBus] m0_wr_data;			// 写数据
	wire				m0_grnt_;			// 总线许可
	// 总线主控器1
	wire				m1_req_;			// 总线请求
	wire [`WordAddrBus] m1_addr;			// 地址
	wire				m1_as_;				// 地址选通
	wire				m1_rw;				// 读/写
	wire [`WordDataBus] m1_wr_data;			// 写数据
	wire				m1_grnt_;			// 总线许可
	// 总线主控器2
	wire				m2_req_;			// 总线请求
	wire [`WordAddrBus] m2_addr;			// 地址
	wire				m2_as_;				// 地址选通
	wire				m2_rw;				// 读/写
	wire [`WordDataBus] m2_wr_data;			// 写数据
	wire				m2_grnt_;			// 总线许可
	// 总线主控器3
	wire				m3_req_;			// 总线请求
	wire [`WordAddrBus] m3_addr;			// 地址
	wire				m3_as_;				// 地址选通
	wire				m3_rw;				// 读/写
	wire [`WordDataBus] m3_wr_data;			// 写数据
	wire				m3_grnt_;			// 总线许可
	/********** 总线从信号 **********/
	// 所有从站的公共信号
	wire [`WordAddrBus] s_addr;				// 地址
	wire				s_as_;				// 地址选通
	wire				s_rw;				// 读/写
	wire [`WordDataBus] s_wr_data;			// 写数据	// 总线从0
	wire [`WordDataBus] s0_rd_data;			// 读取数据
	wire				s0_rdy_;			// 准备就绪
	wire				s0_cs_;				// 片选
	// 总线从1
	wire [`WordDataBus] s1_rd_data;			// 读取数据
	wire				s1_rdy_;			// 准备就绪
	wire				s1_cs_;				// 片选
	// 总线从2
	wire [`WordDataBus] s2_rd_data;			// 读取数据
	wire				s2_rdy_;			// 准备就绪
	wire				s2_cs_;				// 片选
	// 总线从3
	wire [`WordDataBus] s3_rd_data;			// 读取数据
	wire				s3_rdy_;			// 准备就绪
	wire				s3_cs_;				// 片选
	// 总线从4
	wire [`WordDataBus] s4_rd_data;			// 读取数据
	wire				s4_rdy_;			// 准备就绪
	wire				s4_cs_;				// 片选
	// 总线从5
	wire [`WordDataBus] s5_rd_data;			// 读取数据
	wire				s5_rdy_;			// 准备就绪
	wire				s5_cs_;				// 片选
	// 总线从6
	wire [`WordDataBus] s6_rd_data;			// 读取数据
	wire				s6_rdy_;			// 准备就绪
	wire				s6_cs_;				// 片选
	// 总线从7
	wire [`WordDataBus] s7_rd_data;			// 读取数据
	wire				s7_rdy_;			// 准备就绪
	wire				s7_cs_;				// 片选
	/********** 中断请求信号 **********/
	wire				   irq_timer;		// 计时器IRQ
	wire				   irq_uart_rx;		// UART IRQ（接收）
	wire				   irq_uart_tx;		// UART IRQ（发送）
	wire [`CPU_IRQ_CH-1:0] cpu_irq;			// CPU IRQ

	assign cpu_irq = {{`CPU_IRQ_CH-3{`LOW}}, 
					  irq_uart_rx, irq_uart_tx, irq_timer};

	/********** CPU **********/
	cpu cpu (
		/********** 时钟和重置 **********/
		.clk			 (clk),					// 时钟
		.clk_			 (clk_),				// 时钟反转
		.reset			 (reset),				// 异步复位
		/********** 总线接口 **********/
		// IF Stage
		.if_bus_rd_data	 (m_rd_data),			// 读取数据
		.if_bus_rdy_	 (m_rdy_),				// 准备就绪
		.if_bus_grnt_	 (m0_grnt_),			// 总线许可
		.if_bus_req_	 (m0_req_),				// 总线请求
		.if_bus_addr	 (m0_addr),				// 地址
		.if_bus_as_		 (m0_as_),				// 地址选通
		.if_bus_rw		 (m0_rw),				// 读/写
		.if_bus_wr_data	 (m0_wr_data),			// 写数据
		// MEM Stage
		.mem_bus_rd_data (m_rd_data),			// 读取数据
		.mem_bus_rdy_	 (m_rdy_),				// 准备就绪
		.mem_bus_grnt_	 (m1_grnt_),			// 总线许可
		.mem_bus_req_	 (m1_req_),				// 总线请求
		.mem_bus_addr	 (m1_addr),				// 地址
		.mem_bus_as_	 (m1_as_),				// 地址选通
		.mem_bus_rw		 (m1_rw),				// 读/写
		.mem_bus_wr_data (m1_wr_data),			// 写数据
		/********** 中断 **********/
		.cpu_irq		 (cpu_irq)				// 中断请求
	);

	/********** 总线主控器 2 : 未执行 **********/
	assign m2_addr	  = `WORD_ADDR_W'h0;
	assign m2_as_	  = `DISABLE_;
	assign m2_rw	  = `READ;
	assign m2_wr_data = `WORD_DATA_W'h0;
	assign m2_req_	  = `DISABLE_;

	/********** 总线主控器 3 : 未执行 **********/
	assign m3_addr	  = `WORD_ADDR_W'h0;
	assign m3_as_	  = `DISABLE_;
	assign m3_rw	  = `READ;
	assign m3_wr_data = `WORD_DATA_W'h0;
	assign m3_req_	  = `DISABLE_;
   
	/********** 总线从 0 : ROM **********/
	rom rom (
		/********** Clock & Reset **********/
		.clk			 (clk),					  // 时钟
		.reset			 (reset),				  // 异步复位
		/********** Bus Interface **********/
		.cs_			 (s0_cs_),				  // 片选
		.as_			 (s_as_),				  // 地址选通
		.addr			 (s_addr[`RomAddrLoc]),	  // 地址
		.rd_data		 (s0_rd_data),			  // 读取数据
		.rdy_			 (s0_rdy_)				  // 准备就绪
	);

	/********** 总线从 1 : Scratch Pad Memory **********/
	assign s1_rd_data = `WORD_DATA_W'h0;
	assign s1_rdy_	  = `DISABLE_;

	/********** 总线从 2 : 计时器 **********/
`ifdef IMPLEMENT_TIMER // 定时器实现
	timer timer (
		/********** 时钟和重置 **********/
		.clk			 (clk),					  // 时钟
		.reset			 (reset),				  // 重置
		/********** 总线接口 **********/
		.cs_			 (s2_cs_),				  // 片选
		.as_			 (s_as_),				  // 地址选通
		.addr			 (s_addr[`TimerAddrLoc]), // 地址
		.rw				 (s_rw),				  // Read / Write
		.wr_data		 (s_wr_data),			  // 写数据
		.rd_data		 (s2_rd_data),			  // 读取数据
		.rdy_			 (s2_rdy_),				  // 准备就绪
		/********** 中断 **********/
		.irq			 (irq_timer)			  // 中断请求
	 );
`else				   // 计时器不真实
	assign s2_rd_data = `WORD_DATA_W'h0;
	assign s2_rdy_	  = `DISABLE_;
	assign irq_timer  = `DISABLE;
`endif

	/********** 总线从 3 : UART **********/
`ifdef IMPLEMENT_UART // UART实现
	uart uart (
		/********** 时钟和重置 **********/
		.clk			 (clk),						// 时钟
		.reset			 (reset),					// 异步复位
		/********** 总线接口 **********/
		.cs_			 (s3_cs_),					// 片选
		.as_			 (s_as_),					// 地址选通
		.rw				 (s_rw),					// Read / Write
		.addr			 (s_addr[`UartAddrLoc]),// 地址
		.wr_data		 (s_wr_data),				// 写数据
		.rd_data		 (s3_rd_data),				// 读取数据
		.rdy_			 (s3_rdy_),					// 准备就绪
		/********** 中断 **********/
		.irq_rx			 (irq_uart_rx),			  	// 接收完成中断
		.irq_tx			 (irq_uart_tx),			 	// 传输完成中断
		/********** UART送受信信号	**********/
		.rx				 (uart_rx),				 	// UART受信信号
		.tx				 (uart_tx)					// UART送信信号
	);
`else				  // UART未执行
	assign s3_rd_data  = `WORD_DATA_W'h0;
	assign s3_rdy_	   = `DISABLE_;
	assign irq_uart_rx = `DISABLE;
	assign irq_uart_tx = `DISABLE;
`endif

	/********** 总线从 4 : GPIO **********/
`ifdef IMPLEMENT_GPIO // GPIO实现
	gpio gpio (
		/********** 时钟和重置 **********/
		.clk			 (clk),					// 时钟
		.reset		 (reset),				 	// 重置
		/********** 总线接口 **********/
		.cs_			 (s4_cs_),				// 片选
		.as_			 (s_as_),				// 地址选通
		.rw				 (s_rw),				// Read / Write
		.addr			 (s_addr[`GpioAddrLoc]),// 地址
		.wr_data		 (s_wr_data),			// 写数据
		.rd_data		 (s4_rd_data),			// 读取数据
		.rdy_			 (s4_rdy_)				// 准备就绪
		/********** 通用输入/输出端口 **********/
`ifdef GPIO_IN_CH		// 输入端口的实现
		, .gpio_in		 (gpio_in)				// 输入口
`endif
`ifdef GPIO_OUT_CH	// 输出端口实现
		, .gpio_out		 (gpio_out)				// 输出口
`endif
`ifdef GPIO_IO_CH		// 输入/输出端口的实现
		, .gpio_io		 (gpio_io)				// I / O端口
`endif
	);
`else				  // GPIO未执行
	assign s4_rd_data = `WORD_DATA_W'h0;
	assign s4_rdy_	  = `DISABLE_;
`endif

	/********** 总线从 5 : 未执行 **********/
	assign s5_rd_data = `WORD_DATA_W'h0;
	assign s5_rdy_	  = `DISABLE_;
  
	/********** 总线从 6 : 未执行 **********/
	assign s6_rd_data = `WORD_DATA_W'h0;
	assign s6_rdy_	  = `DISABLE_;
  
	/********** 总线从 7 : 未执行 **********/
	assign s7_rd_data = `WORD_DATA_W'h0;
	assign s7_rdy_	  = `DISABLE_;

	/********** 总线 **********/
	bus bus (
		/********** 时钟和重置 **********/
		.clk			 (clk),					// 时钟
		.reset			 (reset),				// 异步复位
		/********** 总线主控器信号 **********/
		// 所有主机的通用信号
		.m_rd_data		 (m_rd_data),			// 读取数据
		.m_rdy_			 (m_rdy_),				// 准备就绪
		// 总线主控器0
		.m0_req_		 (m0_req_),				// 总线请求
		.m0_addr		 (m0_addr),				// 地址
		.m0_as_			 (m0_as_),				// 地址选通
		.m0_rw			 (m0_rw),				// 读/写
		.m0_wr_data		 (m0_wr_data),			// 写数据
		.m0_grnt_		 (m0_grnt_),			// 总线许可
		// 总线主控器1
		.m1_req_		 (m1_req_),				// 总线请求
		.m1_addr		 (m1_addr),				// 地址
		.m1_as_			 (m1_as_),				// 地址选通
		.m1_rw			 (m1_rw),				// 读/写
		.m1_wr_data		 (m1_wr_data),			// 写数据
		.m1_grnt_		 (m1_grnt_),			// 总线许可
		// 总线主控器2
		.m2_req_		 (m2_req_),				// 总线请求
		.m2_addr		 (m2_addr),				// 地址
		.m2_as_			 (m2_as_),				// 地址选通
		.m2_rw			 (m2_rw),				// 读/写
		.m2_wr_data		 (m2_wr_data),			// 写数据
		.m2_grnt_		 (m2_grnt_),			// 总线许可
		// 总线主控器3
		.m3_req_		 (m3_req_),				// 总线请求
		.m3_addr		 (m3_addr),				// 地址
		.m3_as_			 (m3_as_),				// 地址选通
		.m3_rw			 (m3_rw),				// 读/写
		.m3_wr_data		 (m3_wr_data),			// 写数据
		.m3_grnt_		 (m3_grnt_),			// 总线许可
		/********** 总线从信号 **********/
		// 所有从站的公共信号
		.s_addr			 (s_addr),				// 地址
		.s_as_			 (s_as_),				// 地址选通
		.s_rw			 (s_rw),				// 读/写
		.s_wr_data		 (s_wr_data),			// 写数据
		// 总线从0
		.s0_rd_data		 (s0_rd_data),			// 读取数据
		.s0_rdy_		 (s0_rdy_),				// 准备就绪
		.s0_cs_			 (s0_cs_),				// 片选
		// 总线从1
		.s1_rd_data		 (s1_rd_data),			// 读取数据
		.s1_rdy_		 (s1_rdy_),				// 准备就绪
		.s1_cs_			 (s1_cs_),				// 片选
		// 总线从2
		.s2_rd_data		 (s2_rd_data),			// 读取数据
		.s2_rdy_		 (s2_rdy_),				// 准备就绪
		.s2_cs_			 (s2_cs_),				// 片选
		// 总线从3
		.s3_rd_data		 (s3_rd_data),			// 读取数据
		.s3_rdy_		 (s3_rdy_),				// 准备就绪
		.s3_cs_			 (s3_cs_),				// 片选
		// 总线从4
		.s4_rd_data		 (s4_rd_data),			// 读取数据
		.s4_rdy_		 (s4_rdy_),				// 准备就绪
		.s4_cs_			 (s4_cs_),				// 片选
		// 总线从5
		.s5_rd_data		 (s5_rd_data),			// 读取数据
		.s5_rdy_		 (s5_rdy_),				// 准备就绪
		.s5_cs_			 (s5_cs_),				// 片选
		// 总线从6
		.s6_rd_data		 (s6_rd_data),			// 读取数据
		.s6_rdy_		 (s6_rdy_),				// 准备就绪
		.s6_cs_			 (s6_cs_),				// 片选
		// 总线从7
		.s7_rd_data		 (s7_rd_data),			// 读取数据
		.s7_rdy_		 (s7_rdy_),				// 准备就绪
		.s7_cs_			 (s7_cs_)				// 片选
	);

endmodule