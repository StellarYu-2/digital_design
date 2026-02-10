module sd_multi_pic(
    input                clk           ,  // 时钟信号 (50MHz)
    input                rst_n         ,  // 复位信号
    input                rd_busy       ,  // SD卡读忙信号
    input                sd_rd_val_en  ,  // SD卡读数据有效信号
    input        [15:0]  sd_rd_val_data,  // SD卡读出的数据
    
    output  reg          rd_start_en   ,  // 开始读SD卡信号
    output  reg  [31:0]  rd_sec_addr   ,  // 读数据扇区地址
    output  reg          sdram_wr_en   ,  // SDRAM写使能
    output       [15:0]  sdram_wr_data ,  // SDRAM写数据
    
    // 新增控制信号
    output  reg  [23:0]  sdram_base_addr, // 输出给SDRAM控制器的写基地址
    output  reg          pic_switch     , // 图片切换脉冲，用于触发SDRAM地址复位
    output  reg          pic_load_done    // 所有图片加载完成信号
);

//===========================================================================
// 1. 扇区地址定义 (根据WinHex查看结果)
//===========================================================================
parameter SEC_ADDR_BG        = 32'd26628;
parameter SEC_ADDR_BASE      = 32'd31237;
parameter SEC_ADDR_BIRD0     = 32'd32138;
parameter SEC_ADDR_BIRD1     = 32'd32149;
parameter SEC_ADDR_BIRD2     = 32'd32161;
parameter SEC_ADDR_GAMEOVER  = 32'd32172;
parameter SEC_ADDR_PIPE      = 32'd36781;
parameter SEC_ADDR_START     = 32'd37016;

//===========================================================================
// 2. SDRAM 地址映射 (规划图片在内存中的位置)
//===========================================================================
// 1024x768 = 786432 words (0xC0000)
parameter MEM_ADDR_BG        = 24'd0;           // 0x000000
parameter MEM_ADDR_START     = 24'd786432;      // 0x0C0000
parameter MEM_ADDR_GAMEOVER  = 24'd1572864;     // 0x180000
parameter MEM_ADDR_BASE      = 24'd2359296;     // 0x240000
parameter MEM_ADDR_PIPE      = 24'd2512896;     // 0x265800
parameter MEM_ADDR_BIRD0     = 24'd2552896;     // 0x26F400
parameter MEM_ADDR_BIRD1     = 24'd2554646;     // 0x26FB16
parameter MEM_ADDR_BIRD2     = 24'd2556396;     // 0x27022C

//===========================================================================
// 3. 内部信号定义
//===========================================================================
reg    [3:0]          pic_cnt;          // 当前处理第几张图片 (0-7)
reg    [15:0]         rd_sec_cnt;       // 当前图片已读扇区数
reg    [15:0]         cur_pic_sec_num;  // 当前图片总扇区数
reg    [23:0]         next_base_addr;   // 下一张图片的基地址(组合逻辑计算)
reg    [31:0]         next_sec_addr;    // 下一张图片的扇区首地址(组合逻辑计算)

reg    [2:0]          state;            // 状态机
reg                   rd_busy_d0, rd_busy_d1; // 抓取下降沿

// BMP解析相关
reg    [5:0]          bmp_head_cnt;     // 跳过54字节头部的计数器
reg    [1:0]          val_en_cnt;       // 2个16位数据转1个24位RGB计数器
reg    [15:0]         val_data_t;       // 临时数据
reg    [23:0]         rgb888_data;      // 拼好的RGB888

// --- Padding 处理 ---
reg    [6:0]          col_word_cnt;     // 每行字计数器 (0-75)

// 恢复标准头跳过 (27字=54字节)
wire   [5:0]          target_head_size;
assign target_head_size = 6'd27;

wire                  neg_rd_busy;

assign neg_rd_busy = rd_busy_d1 & (~rd_busy_d0);
// RGB888 转 RGB565
assign sdram_wr_data = {rgb888_data[23:19], rgb888_data[15:10], rgb888_data[7:3]};

//===========================================================================
// 4. 逻辑实现
//===========================================================================

// 抓取 rd_busy 下降沿
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_busy_d0 <= 1'b0;
        rd_busy_d1 <= 1'b0;
    end else begin
        rd_busy_d0 <= rd_busy;
        rd_busy_d1 <= rd_busy_d0;
    end
end

// 图片参数查找表
always @(*) begin
    case(pic_cnt)
        // 背景 1024x768
        4'd0: begin cur_pic_sec_num = 16'd4609; next_base_addr = MEM_ADDR_BG;       next_sec_addr = SEC_ADDR_BG;       end
        // 开始界面
        4'd1: begin cur_pic_sec_num = 16'd4609; next_base_addr = MEM_ADDR_START;    next_sec_addr = SEC_ADDR_START;    end
        // 游戏结束
        4'd2: begin cur_pic_sec_num = 16'd4609; next_base_addr = MEM_ADDR_GAMEOVER; next_sec_addr = SEC_ADDR_GAMEOVER; end
        // 地面 1024x150
        4'd3: begin cur_pic_sec_num = 16'd901;  next_base_addr = MEM_ADDR_BASE;     next_sec_addr = SEC_ADDR_BASE;     end
        // 管道 80x500 (注意：之前文档是400，但扇区算出来235对应约12万字节，80*500*3=120000，比较吻合，暂定80x500)
        4'd4: begin cur_pic_sec_num = 16'd235;  next_base_addr = MEM_ADDR_PIPE;     next_sec_addr = SEC_ADDR_PIPE;     end
        // 小鸟
        4'd5: begin cur_pic_sec_num = 16'd11;   next_base_addr = MEM_ADDR_BIRD0;    next_sec_addr = SEC_ADDR_BIRD0;    end
        4'd6: begin cur_pic_sec_num = 16'd11;   next_base_addr = MEM_ADDR_BIRD1;    next_sec_addr = SEC_ADDR_BIRD1;    end
        4'd7: begin cur_pic_sec_num = 16'd11;   next_base_addr = MEM_ADDR_BIRD2;    next_sec_addr = SEC_ADDR_BIRD2;    end
        default: begin cur_pic_sec_num = 16'd0; next_base_addr = 24'd0;             next_sec_addr = 32'd0;             end
    endcase
end

// 主状态机
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= 0;
        rd_start_en <= 0;
        rd_sec_cnt <= 0;
        pic_cnt <= 0;
        pic_load_done <= 0;
        pic_switch <= 0;
        rd_sec_addr <= 0;
        sdram_base_addr <= 0;
    end else begin
        pic_switch <= 1'b0; // 默认拉低
        
        case(state)
            0: begin // PREPARE / SWITCH PICTURE
                if(pic_cnt <= 7) begin
                    // 1. 设置当前图片的基地址
                    sdram_base_addr <= next_base_addr;
                    // 2. 设置当前图片的起始扇区
                    rd_sec_addr <= next_sec_addr;
                    // 3. 产生复位脉冲，重置SDRAM写地址到 base_addr
                    pic_switch <= 1'b1; 
                    
                    state <= 1;
                end else begin
                    pic_load_done <= 1'b1; // 全部加载完成
                    rd_start_en <= 1'b0;
                end
            end
            
            1: begin // WAIT RESET STABLE & START READ
                rd_start_en <= 1'b1; 
                state <= 2;
            end
            
            2: begin // WAIT BUSY (SD卡响应)
                if(rd_busy) begin 
                    rd_start_en <= 1'b0; 
                    state <= 3;
                end
            end
            
            3: begin // READING SECTOR
                if(neg_rd_busy) begin // 扇区读取完成
                    rd_sec_cnt <= rd_sec_cnt + 1'b1;
                    if(rd_sec_cnt >= cur_pic_sec_num - 1) begin
                        // 当前图片所有扇区读完
                        rd_sec_cnt <= 0;
                        pic_cnt <= pic_cnt + 1'b1; // 准备下一张
                        state <= 0;
                    end else begin
                        // 读下一个扇区
                        rd_sec_addr <= rd_sec_addr + 1'b1;
                        state <= 1; // 回到状态1继续读下一扇区
                    end
                end
            end
        endcase
    end
end

// 数据解析与写入 SDRAM (带 Padding 处理 & 混合字节序)
// 新增：base图片列过滤器
reg [11:0] base_col_cnt;  // 列计数器 (0-1535，每行1536个16位字)

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        bmp_head_cnt <= 0;
        val_en_cnt <= 0;
        val_data_t <= 0;
        rgb888_data <= 0;
        sdram_wr_en <= 0;
        col_word_cnt <= 0;
        base_col_cnt <= 0;
    end else begin
        sdram_wr_en <= 0;
        
        // 换图时复位解析计数器
        if(state == 0) begin
            bmp_head_cnt <= 0;
            val_en_cnt <= 0;
            col_word_cnt <= 0;
            base_col_cnt <= 0;
        end

        if(sd_rd_val_en) begin
            // 1. BMP 头部过滤 
            if(rd_sec_cnt == 0 && bmp_head_cnt < target_head_size) begin
                bmp_head_cnt <= bmp_head_cnt + 1'b1;
                col_word_cnt <= 0;
                base_col_cnt <= 0;
            end
            // 2. 有效数据处理
            else begin
                // --- Base图片列过滤逻辑 (pic_cnt == 3) ---
                // base.bmp是1024x150，但我们只需要前32列
                // 每行1024像素 = 3072字节 = 1536个16位字
                // 前32像素 = 96字节 = 48个16位字
                if(pic_cnt == 3) begin
                    if(base_col_cnt < 12'd1535) begin
                        base_col_cnt <= base_col_cnt + 1'b1;
                    end else begin
                        base_col_cnt <= 0;  // 行结束，重置
                    end
                    
                    // 只处理前96个字（对应64像素）
                    if(base_col_cnt >= 12'd96) begin
                        // 超过64列，直接丢弃，不做任何处理
                    end
                    else begin
                        // 在前64列内，正常处理
                        val_en_cnt <= val_en_cnt + 1'b1;
                        val_data_t <= sd_rd_val_data;
                        
                        if(val_en_cnt == 1) begin
                            sdram_wr_en <= 1'b1;
                            rgb888_data <= {sd_rd_val_data[15:8], val_data_t[7:0], val_data_t[15:8]};
                        end
                        else if(val_en_cnt == 2) begin
                            sdram_wr_en <= 1'b1;
                            rgb888_data <= {sd_rd_val_data[7:0], sd_rd_val_data[15:8], val_data_t[7:0]};
                            val_en_cnt <= 0;
                        end
                    end
                end
                // --- 小鸟图片 Padding 检测 (pic_cnt >= 5) ---
                else if(pic_cnt >= 5) begin
                    if(col_word_cnt == 75) begin
                        // 这是一个 Padding 字，直接丢弃！
                        col_word_cnt <= 0; 
                        val_en_cnt <= 0;
                    end
                    else begin
                        col_word_cnt <= col_word_cnt + 1'b1;
                        
                        val_en_cnt <= val_en_cnt + 1'b1;
                        val_data_t <= sd_rd_val_data;
                        
                        if(val_en_cnt == 1) begin
                            sdram_wr_en <= 1'b1;
                            rgb888_data <= {sd_rd_val_data[15:8], val_data_t[7:0], val_data_t[15:8]};
                        end
                        else if(val_en_cnt == 2) begin
                            sdram_wr_en <= 1'b1;
                            rgb888_data <= {sd_rd_val_data[7:0], sd_rd_val_data[15:8], val_data_t[7:0]};
                            val_en_cnt <= 0;
                        end
                    end
                end
                // --- 其他图片（背景、开始、结束）正常处理 ---
                else begin
                    val_en_cnt <= val_en_cnt + 1'b1;
                    val_data_t <= sd_rd_val_data;
                    
                    if(val_en_cnt == 1) begin
                        sdram_wr_en <= 1'b1;
                        rgb888_data <= {sd_rd_val_data[15:8], val_data_t[7:0], val_data_t[15:8]};
                    end
                    else if(val_en_cnt == 2) begin
                        sdram_wr_en <= 1'b1;
                        rgb888_data <= {sd_rd_val_data[7:0], sd_rd_val_data[15:8], val_data_t[7:0]};
                        val_en_cnt <= 0;
                    end
                end
            end
        end
    end
end

endmodule
