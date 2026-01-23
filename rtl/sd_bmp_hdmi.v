module sd_bmp_hdmi(    
    input                 sys_clk,      //系统时钟
    input                 sys_rst_n,    //系统复位，低电平有效
    input                 key_jump,     //用户按键: 跳跃                       
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
    output [2:0]          tmds_data_n,
    //数码管接口
    output [5:0]          seg_sel,       // 数码管位选
    output [7:0]          seg_led        // 数码管段选
    );


//parameter define 
//SDRAM读写最大地址 1024 * 768 = 786432 (用于HDMI显示循环读取)
parameter  SDRAM_DISP_ADDR = 786432;
//SDRAM总容量范围 (用于写入多张图片)
parameter  SDRAM_TOTAL_SIZE = 4000000;  
//SD卡读扇区个数 (不再使用固定值，由sd_multi_pic控制)
//parameter  SD_SEC_NUM = 4609;        

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

// 新增连接信号
wire [23:0]  sdram_base_addr; // 当前图片写入基地址
wire         pic_switch;      // 图片切换复位信号
wire         pic_load_done;   // 加载完成信号
wire         sdram_wr_load;   // 最终的SDRAM写复位信号

// 游戏相关信号
wire [10:0]  pixel_xpos;      // HDMI当前扫描X坐标
wire [10:0]  pixel_ypos;      // HDMI当前扫描Y坐标
wire         video_vs;        // 场同步信号
reg          vs_d0, vs_d1;    // 抓取VS边沿
wire         frame_en;        // 帧同步脉冲
wire [11:0]  bird_x;          // 小鸟X坐标
wire [11:0]  bird_y;          // 小鸟Y坐标
wire [15:0]  final_pixel_data;// 最终送往HDMI的颜色数据
reg  [15:0]  sdram_rd_data_r; // 注册SDRAM数据以改善时序(可选)

// 新增游戏控制信号
wire         collision;       // 碰撞检测信号
wire         game_active;     // 游戏激活状态
wire [1:0]   game_state;      // 游戏状态机 (0:IDLE, 1:PLAY, 2:OVER)
wire         score_pulse;     // 得分脉冲
wire [23:0]  score_bcd;       // BCD分数

// SDRAM 读取地址控制 (用于切换背景/开始/结束画面)
reg  [23:0]  current_rd_min_addr;
wire [23:0]  current_rd_max_addr;

localparam MEM_ADDR_BG        = 24'd0;           
localparam MEM_ADDR_START     = 24'd786432;      
localparam MEM_ADDR_GAMEOVER  = 24'd1572864;     

always @(*) begin
    case(game_state)
        2'd0: current_rd_min_addr = MEM_ADDR_START;    // IDLE
        2'd1: current_rd_min_addr = MEM_ADDR_BG;       // PLAY
        2'd2: current_rd_min_addr = MEM_ADDR_GAMEOVER; // OVER
        default: current_rd_min_addr = MEM_ADDR_START;
    endcase
end

assign current_rd_max_addr = current_rd_min_addr + SDRAM_DISP_ADDR;

// 隐藏精灵逻辑 (非游戏状态下，将精灵移出屏幕)
wire [11:0] bird_x_render = (game_state == 2'd1) ? bird_x : 12'd2000;
wire [11:0] bird_y_render = (game_state == 2'd1) ? bird_y : 12'd2000;
wire [11:0] pipe1_x_render = (game_state == 2'd1) ? pipe1_x : 12'd2000;
wire [11:0] pipe2_x_render = (game_state == 2'd1) ? pipe2_x : 12'd2000;

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

// 生成写复位信号：系统复位 或 图片切换
assign  sdram_wr_load = (~rst_n) | pic_switch;

wire [11:0]  pipe1_x, pipe1_gap_y;
wire [11:0]  pipe2_x, pipe2_gap_y;

// BRAM加载逻辑信号
reg          bird_load_en;
reg  [12:0]  bird_load_addr; // 扩大地址位宽：1750 * 3 = 5250，需要13位 (2^13=8192)

// Pipe加载逻辑信号
reg          pipe_load_en;
reg  [15:0]  pipe_load_addr; // 80 * 500 = 40000

// 检测是否在加载小鸟 (BIRD0, BIRD1, BIRD2)
// BIRD0: 2552896, BIRD1: 2554646, BIRD2: 2556396
wire is_loading_bird;
assign is_loading_bird = (sdram_base_addr >= 24'd2552896) && (sdram_base_addr <= 24'd2556396);

// 检测是否在加载管道
// PIPE: 2512896
wire is_loading_pipe;
assign is_loading_pipe = (sdram_base_addr == 24'd2512896);

// 产生写入地址
always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin
        bird_load_addr <= 0;
        bird_load_en <= 0;
        pipe_load_addr <= 0;
        pipe_load_en <= 0;
    end else begin
        // --- 小鸟加载逻辑 ---
        if(is_loading_bird && sdram_wr_en) begin
            bird_load_en <= 1'b1;
            bird_load_addr <= bird_load_addr + 1'b1;
        end else begin
            bird_load_en <= 1'b0;
        end
        
        // --- 管道加载逻辑 ---
        if(is_loading_pipe && sdram_wr_en) begin
            pipe_load_en <= 1'b1;
            pipe_load_addr <= pipe_load_addr + 1'b1;
        end else begin
            pipe_load_en <= 1'b0;
        end

        // 图片切换时复位地址
        if(pic_switch) begin
            if(sdram_base_addr == 24'd2552896) // BIRD0 Start
                 bird_load_addr <= 0;
            
            if(sdram_base_addr == 24'd2512896) // PIPE Start
                 pipe_load_addr <= 0;
        end
    end
end

// -------------------------------------------------------------------------
// 游戏逻辑集成
// -------------------------------------------------------------------------

// 1. 生成帧同步信号 (VS上升沿，即一帧结束/开始时)
// 为了确保稳定性，增加一个基于计数器的内部帧信号 (60Hz)
reg [20:0] frame_cnt;
reg        internal_frame_en;
always @(posedge hdmi_clk or negedge rst_n) begin
    if(!rst_n) begin
        frame_cnt <= 0;
        internal_frame_en <= 0;
    end else begin
        if(frame_cnt >= 1083333) begin // 65MHz / 60Hz
            frame_cnt <= 0;
            internal_frame_en <= 1'b1;
        end else begin
            frame_cnt <= frame_cnt + 1'b1;
            internal_frame_en <= 1'b0;
        end
    end
end

always @(posedge hdmi_clk or negedge rst_n) begin
    if(!rst_n) begin
        vs_d0 <= 1'b0;
        vs_d1 <= 1'b0;
    end else begin
        vs_d0 <= video_vs;
        vs_d1 <= vs_d0;
    end
end
assign frame_en = vs_d0 & (~vs_d1); // 上升沿脉冲

// 2. 例化小鸟控制模块
bird_ctrl u_bird_ctrl(
    .clk            (hdmi_clk),      // 使用HDMI时钟，避免跨时钟域问题
    .rst_n          (rst_n),
    .key_jump       (~key_jump),     // 按键低电平有效，取反后变为高有效
    .game_active    (game_active),   // 使用游戏激活信号
    .frame_en_unused(internal_frame_en), // 连接内部帧信号(仅做参考)
    .bird_y         (bird_y),
    .bird_x         (bird_x),
    .bird_angle     ()
);

// 3. 管道生成模块
pipe_gen u_pipe_gen(
    .clk            (hdmi_clk),
    .rst_n          (rst_n),
    .game_active    (game_active),   // 使用游戏激活信号
    .frame_en       (internal_frame_en), // 使用内部产生的稳定60Hz信号
    .random_seed    (16'd0), // 暂时用0，后续可用像素计数器
    .pipe1_x        (pipe1_x),
    .pipe1_gap_y    (pipe1_gap_y),
    .pipe2_x        (pipe2_x),
    .pipe2_gap_y    (pipe2_gap_y),
    .score_pulse    (score_pulse)
);

// 3.5 碰撞检测模块
collision_det u_collision_det(
    .clk            (hdmi_clk),
    .rst_n          (rst_n),
    .bird_x         (bird_x),
    .bird_y         (bird_y),
    .pipe1_x        (pipe1_x),
    .pipe1_gap_y    (pipe1_gap_y),
    .pipe2_x        (pipe2_x),
    .pipe2_gap_y    (pipe2_gap_y),
    .collision      (collision)
);

// 3.6 游戏状态控制模块
game_ctrl u_game_ctrl(
    .clk            (hdmi_clk),
    .rst_n          (rst_n),
    .key_jump       (~key_jump),     // 高有效
    .collision      (collision),
    .score_pulse    (score_pulse),
    .game_active    (game_active),
    .state          (game_state),
    .score_bcd      (score_bcd)
);

// 3.7 数码管驱动模块
seg_driver u_seg_driver(
    .clk            (clk_50m), // 使用50MHz时钟进行扫描
    .rst_n          (rst_n),
    .data_bcd       (score_bcd),
    .sel            (seg_sel),
    .seg            (seg_led)
);

// 4. 精灵渲染模块 (替代原来的叠加逻辑)
wire [15:0] sprite_pixel_out;

sprite_render u_sprite_render(
    .clk            (hdmi_clk),
    .rst_n          (rst_n),
    .pixel_x        (pixel_xpos),
    .pixel_y        (pixel_ypos),
    .bird_x         (bird_x_render), // 使用带隐藏逻辑的坐标
    .bird_y         (bird_y_render),
    .pipe1_x        (pipe1_x_render),
    .pipe1_gap_y    (pipe1_gap_y),
    .pipe2_x        (pipe2_x_render),
    .pipe2_gap_y    (pipe2_gap_y),
    .bg_data        (rd_data), // 来自SDRAM的背景流
    
    // 加载接口
    .bird_load_clk  (clk_50m),
    .bird_load_en   (bird_load_en),
    .bird_load_addr (bird_load_addr),
    .bird_load_data (sdram_wr_data), // 抓取写入SDRAM的数据
    
    .pipe_load_en   (pipe_load_en),
    .pipe_load_addr (pipe_load_addr),
    
    .pixel_out      (sprite_pixel_out)
);

// -------------------------------------------------------------------------

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

// 读取SD卡图片 (多图版本)
sd_multi_pic u_sd_multi_pic(
    .clk             (clk_50m),
    .rst_n           (rst_n & sys_init_done), 
    .rd_busy         (sd_rd_busy),
    .sd_rd_val_en    (sd_rd_val_en),
    .sd_rd_val_data  (sd_rd_val_data),
    .rd_start_en     (sd_rd_start_en),
    .rd_sec_addr     (sd_rd_sec_addr),
    .sdram_wr_en     (sdram_wr_en),
    .sdram_wr_data   (sdram_wr_data),
    
    // 新增控制接口
    .sdram_base_addr (sdram_base_addr),
    .pic_switch      (pic_switch),
    .pic_load_done   (pic_load_done)
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
    .wr_min_addr        (sdram_base_addr),    // 写SDRAM的起始地址 (动态改变)
    .wr_max_addr        (SDRAM_TOTAL_SIZE),   // 写SDRAM的结束地址 (足够大)
    .wr_len             (10'd512 ),           // 写SDRAM时的数据突发长度
    .wr_load            (sdram_wr_load),      // 写端口复位: 图片切换时复位

    //用户读端口
    .rd_clk             (hdmi_clk),           // 读端口FIFO: 读时钟
    .rd_en              (rd_en   ),           // 读端口FIFO: 读使能
    .rd_data            (rd_data ),           // 读端口FIFO: 读数据
    .rd_min_addr        (current_rd_min_addr),// 读SDRAM的起始地址 (动态切换)
    .rd_max_addr        (current_rd_max_addr),// 读SDRAM的结束地址
    .rd_len             (10'd512 ),           // 从SDRAM中读数据时的突发长度
    .rd_load            (~rst_n | frame_en),  // 读端口复位: 复位读地址,清空读FIFO

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
    .rst_n          (rst_n & sys_init_done),
                
    .rd_data        (sprite_pixel_out), // 修改这里：连接 sprite_render 的输出
    .rd_en          (rd_en      ), 
    .pixel_xpos     (pixel_xpos ),      // 接出坐标
    .pixel_ypos     (pixel_ypos ),      // 接出坐标
    .video_vs       (video_vs   ),      // 接出VS信号
	 .h_disp         (),
	 .v_disp         (),
    .tmds_clk_p     (tmds_clk_p ),
    .tmds_clk_n     (tmds_clk_n ),
    .tmds_data_p    (tmds_data_p),
    .tmds_data_n    (tmds_data_n)
    );	
    
endmodule
