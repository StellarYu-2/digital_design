//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_bmp_hdmi
// Last modified Date:  2020/12/01 10:39:20
// Last Version:        V1.0
// Descriptions:        SD卡读BMP图片HDMI显示
//                      
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2020/12/01 10:39:20
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_bmp_hdmi(    
    input                 sys_clk,      //系统时钟
    input                 sys_rst_n,    //系统复位，低电平有效                       
    //SD卡接口
    input                 sd_miso,      //SD卡SPI串行输入数据信号
    output                sd_clk ,      //SD卡SPI时钟信号
    output                sd_cs  ,      //SD卡SPI片选信号
    output                sd_mosi,      //SD卡SPI串行输出数据信号 
    //SDRAM接口
    output                sdram_clk  ,  //SDRAM 时钟
    output                sdram_cke  ,  //SDRAM 时钟有效
    output                sdram_cs_n ,  //SDRAM 片选
    output                sdram_ras_n,  //SDRAM 行有效
    output                sdram_cas_n,  //SDRAM 列有效
    output                sdram_we_n ,  //SDRAM 写有效
    output         [1:0]  sdram_ba   ,  //SDRAM Bank地址
    output         [1:0]  sdram_dqm  ,  //SDRAM 数据掩码
    output         [12:0] sdram_addr ,  //SDRAM 地址
    inout          [15:0] sdram_data ,  //SDRAM 数据  
    //HDMI接口
    output                tmds_clk_p,    // TMDS 时钟通道
    output                tmds_clk_n,
    output [2:0]          tmds_data_p,   // TMDS 数据通道
    output [2:0]          tmds_data_n
    );

//parameter define 
//SDRAM读写最大地址 1024 * 768 = 786432
parameter  SDRAM_MAX_ADDR = 786432;  
//SD卡读扇区个数 1024 * 768 * 3 / 512 + 1 = 4609
parameter  SD_SEC_NUM = 4609;        

//wire define  
wire         clk_100m       ;  //100Mhz时钟,SDRAM操作时钟
wire         clk_100m_shift ;  //100Mhz时钟,SDRAM相位偏移时钟
wire         clk_50m        ;  //50Mhz时钟
wire         clk_50m_180deg ;  //50Mhz相位偏移180度时钟
wire         hdmi_clk       ;  //65Mhz
wire         hdmi_clk_5     ;  //325Mhz
wire         locked         ;  //时钟锁定信号 
wire         locked_hdmi    ;
wire         rst_n          ;  //全局复位 
                               
wire         sd_rd_start_en ;  //开始写SD卡数据信号
wire  [31:0] sd_rd_sec_addr ;  //读数据扇区地址    
wire         sd_rd_busy     ;  //读忙信号
wire         sd_rd_val_en   ;  //数据读取有效使能信号
wire  [15:0] sd_rd_val_data ;  //读数据
wire         sd_init_done   ;  //SD卡初始化完成信号	
wire         sdram_wr_en    ;  //SDRAM控制器模块写使能
wire  [15:0] sdram_wr_data  ;  //SDRAM控制器模块写数据
													    
wire         wr_en          ;  //SDRAM控制器模块写使能
wire  [15:0] wr_data        ;  //SDRAM控制器模块写数据
wire         rd_en          ;  //SDRAM控制器模块读使能
wire  [15:0] rd_data        ;  //SDRAM控制器模块读数据
wire         sdram_init_done;  //SDRAM初始化完成
wire         sys_init_done  ;  //系统初始化完成

//*****************************************************
//**                    main code
//*****************************************************

//待时钟锁定后产生复位结束信号
assign  rst_n = sys_rst_n & locked &locked_hdmi;
//系统初始化完成：SDRAM初始化完成
assign  sys_init_done = sdram_init_done & sd_init_done;
//SDRAM控制器模块为写使能和写数据赋值
assign  wr_en = sdram_wr_en;
assign  wr_data = sdram_wr_data;

//时钟IP核
pll_clk	pll_clk_inst (
	.areset     (1'b0),
	.inclk0     (sys_clk),
	.c0         (clk_100m),
	.c1         (clk_100m_shift),
	.c2         (clk_50m),
	.c3         (clk_50m_180deg),   
	.locked     (locked)
	);

//时钟IP核,用于HDMI顶层模块的驱动时钟
pll_hdmi	pll_hdmi_inst (
	.areset 			( ~sys_rst_n  ),
	.inclk0 			( sys_clk     ),
	.c0 				( hdmi_clk    ),//hdmi pixel clock
	.c1 				( hdmi_clk_5  ),//hdmi pixel clock*5
	.locked 			( locked_hdmi )
	);    

//读取SD卡图片
sd_read_photo u_sd_read_photo(
    .clk             (clk_50m),
    //系统初始化完成之后,再开始从SD卡中读取图片
    .rst_n           (rst_n & sys_init_done), 
    .sdram_max_addr  (SDRAM_MAX_ADDR),       
    .sd_sec_num      (SD_SEC_NUM), 
    .rd_busy         (sd_rd_busy),
    .sd_rd_val_en    (sd_rd_val_en),
    .sd_rd_val_data  (sd_rd_val_data),
    .rd_start_en     (sd_rd_start_en),
    .rd_sec_addr     (sd_rd_sec_addr),
    .sdram_wr_en     (sdram_wr_en),
    .sdram_wr_data   (sdram_wr_data)
    );   

//SD卡顶层控制模块
sd_ctrl_top u_sd_ctrl_top(
    .clk_ref           (clk_50m),
    .clk_ref_180deg    (clk_50m_180deg),
    .rst_n             (rst_n),
    //SD卡接口
    .sd_miso           (sd_miso),
    .sd_clk            (sd_clk),
    .sd_cs             (sd_cs),
    .sd_mosi           (sd_mosi),
    //用户写SD卡接口
    .wr_start_en       (1'b0),        //不需要写入数据,写入接口赋值为0
    .wr_sec_addr       (32'b0),
    .wr_data           (16'b0),
    .wr_busy           (),
    .wr_req            (),
    //用户读SD卡接口
    .rd_start_en       (sd_rd_start_en),
    .rd_sec_addr       (sd_rd_sec_addr),
    .rd_busy           (sd_rd_busy),
    .rd_val_en         (sd_rd_val_en),
    .rd_val_data       (sd_rd_val_data),    
    
    .sd_init_done      (sd_init_done)
    );     

//SDRAM 控制器顶层模块,封装成FIFO接口
//SDRAM 控制器地址组成: {bank_addr[1:0],row_addr[12:0],col_addr[8:0]}
sdram_top u_sdram_top(
    .ref_clk            (clk_100m),           // sdram 控制器参考时钟
    .out_clk            (clk_100m_shift),     // 用于输出的相位偏移时钟
    .rst_n              (rst_n   ),           // 系统复位，低电平有效

    //用户写端口
    .wr_clk             (clk_50m ),           // 写端口FIFO: 写时钟
    .wr_en              (wr_en   ),           // 写端口FIFO: 写使能
    .wr_data            (wr_data ),           // 写端口FIFO: 写数据
    .wr_min_addr        (24'd0   ),           // 写SDRAM的起始地址
    .wr_max_addr        (SDRAM_MAX_ADDR),     // 写SDRAM的结束地址
    .wr_len             (10'd512 ),           // 写SDRAM时的数据突发长度
    .wr_load            (~rst_n ),            // 写端口复位: 复位写地址,清空写FIFO

    //用户读端口
    .rd_clk             (hdmi_clk),           // 读端口FIFO: 读时钟
    .rd_en              (rd_en   ),           // 读端口FIFO: 读使能
    .rd_data            (rd_data ),           // 读端口FIFO: 读数据
    .rd_min_addr        (24'd0   ),           // 读SDRAM的起始地址
    .rd_max_addr        (SDRAM_MAX_ADDR),     // 读SDRAM的结束地址
    .rd_len             (10'd512 ),           // 从SDRAM中读数据时的突发长度
    .rd_load            (~rst_n),             // 读端口复位: 复位读地址,清空读FIFO

     //用户控制端口
    .sdram_read_valid   (1'b1    ),           // SDRAM 读使能
    .sdram_init_done    (sdram_init_done),    // SDRAM 初始化完成标志

    //SDRAM 芯片接口
    .sdram_clk          (sdram_clk ),         // SDRAM 芯片时钟
    .sdram_cke          (sdram_cke ),         // SDRAM 时钟有效
    .sdram_cs_n         (sdram_cs_n),         // SDRAM 片选
    .sdram_ras_n        (sdram_ras_n),        // SDRAM 行有效
    .sdram_cas_n        (sdram_cas_n),        // SDRAM 列有效
    .sdram_we_n         (sdram_we_n),         // SDRAM 写有效
    .sdram_ba           (sdram_ba  ),         // SDRAM Bank地址
    .sdram_addr         (sdram_addr),         // SDRAM 行/列地址
    .sdram_data         (sdram_data),         // SDRAM 数据
    .sdram_dqm          (sdram_dqm )          // SDRAM 数据掩码
);      

//例化HDMI顶层模块
hdmi_top u_hdmi_top(
    .hdmi_clk       (hdmi_clk   ),
    .hdmi_clk_5     (hdmi_clk_5 ),
    .rst_n          (sys_init_done & rst_n),
                
    .rd_data        (rd_data    ),
    .rd_en          (rd_en      ), 
    .h_disp         (),	 
    .v_disp         (),
    .pixel_xpos     (),
    .pixel_ypos     (),
    .video_vs       (),	 
    .tmds_clk_p     (tmds_clk_p ),
    .tmds_clk_n     (tmds_clk_n ),
    .tmds_data_p    (tmds_data_p),
    .tmds_data_n    (tmds_data_n)
    );	
    
endmodule
