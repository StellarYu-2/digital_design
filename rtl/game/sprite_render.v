`timescale 1ns / 1ps

module sprite_render(
    input             clk,           // 像素时钟
    input             rst_n,
    
    // 显示坐标
    input      [10:0] pixel_x,
    input      [10:0] pixel_y,
    
    // 游戏对象位置
    input      [11:0] bird_x,
    input      [11:0] bird_y,
    input      [11:0] pipe1_x,
    input      [11:0] pipe1_gap_y,
    input      [11:0] pipe2_x,
    input      [11:0] pipe2_gap_y,
    
    // 背景数据输入 (来自SDRAM)
    input      [15:0] bg_data,
    
    // 小鸟纹理加载接口
    input             bird_load_clk, // 写时钟 (50MHz)
    input             bird_load_en,  // 写使能
    input      [12:0] bird_load_addr,// 小鸟地址 5250
    input      [15:0] bird_load_data,// 写数据
    
    // 管道纹理加载接口 (新增)
    input             pipe_load_en,
    input      [15:0] pipe_load_addr,// 管道地址 80*500=40000
    // pipe_load_data 共享 bird_load_data，因为源头都是 sdram_wr_data
    
    // 地面纹理加载接口 (新增)
    input             base_load_en,
    input      [13:0] base_load_addr,// 64*150=9600
    
    // 游戏状态
    input             game_active,
    input             frame_en, // 帧同步信号，用于更新滚动
    
    // 最终像素输出
    output reg [15:0] pixel_out
);

    // 参数
    parameter BIRD_W = 50;
    parameter BIRD_H = 35;
    parameter PIPE_W = 80;
    parameter PIPE_H = 500; // 管道纹理高度
    parameter PIPE_GAP_H = 220; // 增大显示缝隙 (原来是140)
    parameter COLOR_PIPE = 16'h07E0; // 纯绿
    parameter TRANSPARENT_COLOR = 16'h07E0; // 小鸟的透明背景色 (纯绿)
    
    // 地面参数
    parameter BASE_TEX_W = 32;  // 存储的纹理宽度 (必须是2的幂，从64改为32节省资源)
    parameter BASE_H     = 150; 
    parameter GROUND_Y   = 618; // 768 - 150
    
    // =========================================================
    // 1. 小鸟纹理存储 (Dual Port RAM)
    // =========================================================
    reg [15:0] bird_ram [0:5249];
    reg [15:0] bird_pixel_raw;
    
    always @(posedge bird_load_clk) begin
        if(bird_load_en) begin
            if(bird_load_addr < 5250)
                bird_ram[bird_load_addr] <= bird_load_data;
        end
    end
    
    // =========================================================
    // 1.5 管道纹理存储 (优化版)
    // 原始需求: 80 * 500 = 40,000 words -> 爆内存 (需要70个M9K)
    // 优化方案: 只存储管口纹理 (80 * 50 = 4000 words) -> 只需要 1 个 M9K
    // =========================================================
    // 假设素材的前50行是管口细节，后面是重复的管身
    parameter PIPE_TEX_H = 50; 
    
    reg [15:0] pipe_ram [0:3999]; // 80 * 50 = 4000
    reg [15:0] pipe_pixel_raw;
    
    always @(posedge bird_load_clk) begin
        if(pipe_load_en) begin
            // 这是一个过滤器：虽然SD卡会发来40000个数据，我们只存前4000个
            // 也就是只存图片的前50行
            if(pipe_load_addr < 4000)
                pipe_ram[pipe_load_addr] <= bird_load_data;
        end
    end
    
    // =========================================================
    // 1.8 地面纹理存储 (新增)
    // 32 * 150 = 4800 words -> ~1 M9K (节省50%资源)
    // =========================================================
    reg [15:0] base_ram [0:4799];
    reg [15:0] base_pixel_raw;
    
    // 调试模式：生成测试条纹（取消注释以使用）
    // parameter BASE_DEBUG_MODE = 1;
    parameter BASE_DEBUG_MODE = 0;
    
    always @(posedge bird_load_clk) begin
        if(base_load_en) begin
            if(base_load_addr < 4800)
                base_ram[base_load_addr] <= bird_load_data;
        end
    end
    
    // 调试：生成简单的条纹纹理用于测试
    // 如果是调试模式且RAM为空，则生成条纹
    integer idx;
    initial begin
        if(BASE_DEBUG_MODE) begin
            for(idx = 0; idx < 4800; idx = idx + 1) begin
                // 生成红白相间的条纹
                if((idx / 32) % 2 == 0)
                    base_ram[idx] = 16'hF800; // 红色
                else
                    base_ram[idx] = 16'hFFFF; // 白色
            end
        end
    end
    
    // =========================================================
    // 2. 动画与读取逻辑
    // =========================================================
    
    // --- 小鸟翅膀动画 ---
    // 动画序列: 0(up) -> 1(mid) -> 2(down) -> 1(mid) -> 0(up)...
    // 每8帧切换一次 (约133ms @ 60fps)，参考开源项目实现
    reg [1:0]  bird_anim_idx;
    reg [2:0]  anim_frame_cnt;  // 帧计数器 (0-7)
    reg        anim_dir;        // 动画方向: 0=递增, 1=递减
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bird_anim_idx   <= 2'd1;     // 初始化为中间帧
            anim_frame_cnt  <= 3'd0;
            anim_dir        <= 1'b0;
        end else if(frame_en && game_active) begin
            // 每帧计数器+1
            if(anim_frame_cnt >= 3'd7) begin
                anim_frame_cnt <= 3'd0;
                // 切换动画帧 (0->1->2->1->0循环)
                if(anim_dir == 1'b0) begin  // 递增方向
                    if(bird_anim_idx >= 2'd2) begin
                        bird_anim_idx <= 2'd1;
                        anim_dir <= 1'b1;  // 改为递减
                    end else begin
                        bird_anim_idx <= bird_anim_idx + 1'b1;
                    end
                end else begin  // 递减方向
                    if(bird_anim_idx <= 2'd0) begin
                        bird_anim_idx <= 2'd1;
                        anim_dir <= 1'b0;  // 改为递增
                    end else begin
                        bird_anim_idx <= bird_anim_idx - 1'b1;
                    end
                end
            end else begin
                anim_frame_cnt <= anim_frame_cnt + 1'b1;
            end
        end
    end

    wire [12:0] bird_read_addr_base;
    wire [12:0] bird_read_offset;
    wire [10:0] bird_dx = pixel_x - bird_x[10:0];
    wire [10:0] bird_dy = pixel_y - bird_y[10:0];
    
    assign bird_read_addr_base = (bird_anim_idx == 0) ? 13'd0 : 
                                 (bird_anim_idx == 1) ? 13'd1750 : 13'd3500;
                                 
    // 修复镜像问题：直接按顺序读取，不做奇怪的校正
    assign bird_read_offset = bird_dy * BIRD_W + bird_dx;
    
    // --- 地面读取逻辑 (新增) ---
    reg [4:0] base_scroll_x; // 0~31 (改为5位，配合32像素宽度)
    
    always @(posedge clk) begin
        if(!rst_n) 
            base_scroll_x <= 0;
        else if(frame_en && game_active)
            base_scroll_x <= base_scroll_x + 2; // 滚动速度 2 (适当调整)
    end
    
    reg [12:0] base_read_addr; // 13位足够：4800 < 8192
    
    always @(*) begin
        base_read_addr = 0;
        if(pixel_y >= GROUND_Y) begin
            reg [4:0] tex_x;
            reg [7:0] tex_y;
            
            // Texture X = (Screen X + Scroll Offset) % 32
            // 只要取低5位即可自动实现 % 32
            tex_x = pixel_x[4:0] + base_scroll_x;
            
            tex_y = pixel_y - GROUND_Y;
            
            if(tex_y < BASE_H)
                base_read_addr = tex_y * BASE_TEX_W + tex_x;
        end
    end
    
    // --- 管道读取逻辑 (纹理循环版) ---
    // 技巧：我们只存储了前50行 (0-49)。
    // 其中前 ~30 行是管口 (不可重复)，后 20 行是管身 (可以循环)。
    // 这样可以用极小的内存渲染无限长的有纹理管道。
    
    // 辅助变量
    wire [11:0] p1_gap_top = pipe1_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p1_gap_bot = pipe1_gap_y + (PIPE_GAP_H/2);
    wire [11:0] p2_gap_top = pipe2_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p2_gap_bot = pipe2_gap_y + (PIPE_GAP_H/2);
    
    reg [11:0] pipe_read_addr;
    // 不再需要纯色标志位
    
    // 定义分割点：前40行是管口区域（含阴影过渡）
    // 40行以后全部重复使用第40行的数据
    localparam PIPE_SPLIT_Y = 10;
    // localparam PIPE_LOOP_H  = 20; // 不再需要循环

    always @(*) begin
        pipe_read_addr = 0;
        
        // --- 管道1 ---
        if(pixel_x >= pipe1_x[10:0] && pixel_x < pipe1_x[10:0] + PIPE_W) begin
            reg [10:0] tex_x;
            reg [10:0] tex_y;
            reg [10:0] effective_y;
            
            tex_x = pixel_x - pipe1_x[10:0];
            
            if(pixel_y < p1_gap_top) begin
                // 上管 (Top Pipe)
                // 计算距离管口底部的距离（从缝隙往上数）
                tex_y = (p1_gap_top - 1) - pixel_y;
                
                // 纹理坐标映射：管口底部对应纹理第0行（管口底部），往上对应纹理往上
                // 所以 effective_y = PIPE_SPLIT_Y - 1 - tex_y（反转方向）
                if(tex_y < PIPE_SPLIT_Y)
                    effective_y = (PIPE_SPLIT_Y - 1) - tex_y;
                else
                    effective_y = 0; // 超出管口范围，使用纹理第0行（管身）
                    
                pipe_read_addr = effective_y * PIPE_W + tex_x;
            end
            else if(pixel_y > p1_gap_bot) begin
                // 下管 (Bottom Pipe)
                tex_y = pixel_y - p1_gap_bot;
                
                if(tex_y < PIPE_SPLIT_Y)
                    effective_y = tex_y;
                else
                    effective_y = PIPE_SPLIT_Y; // 锁定在第40行
                    
                pipe_read_addr = effective_y * PIPE_W + tex_x;
            end
        end
        
        // --- 管道2 ---
        else if(pixel_x >= pipe2_x[10:0] && pixel_x < pipe2_x[10:0] + PIPE_W) begin
            reg [10:0] tex_x;
            reg [10:0] tex_y;
            reg [10:0] effective_y;
            
            tex_x = pixel_x - pipe2_x[10:0];
            
            if(pixel_y < p2_gap_top) begin
                // 上管 (Top Pipe)
                tex_y = (p2_gap_top - 1) - pixel_y;
                
                if(tex_y < PIPE_SPLIT_Y)
                    effective_y = (PIPE_SPLIT_Y - 1) - tex_y;
                else
                    effective_y = 0;
                    
                pipe_read_addr = effective_y * PIPE_W + tex_x;
            end
            else if(pixel_y > p2_gap_bot) begin
                tex_y = pixel_y - p2_gap_bot;
                
                if(tex_y < PIPE_SPLIT_Y)
                    effective_y = tex_y;
                else
                    effective_y = PIPE_SPLIT_Y; 
                    
                pipe_read_addr = effective_y * PIPE_W + tex_x;
            end
        end
    end
    
    // 内存读取 (同步)
    always @(posedge clk) begin
        bird_pixel_raw <= bird_ram[bird_read_addr_base + bird_read_offset];
        pipe_pixel_raw <= pipe_ram[pipe_read_addr];
        
        // 调试模式：使用算法生成base颜色
        if(BASE_DEBUG_MODE) begin
            // 生成黄绿相间的条纹用于测试
            if(base_read_addr[4:0] < 16)
                base_pixel_raw <= 16'hFFE0; // 黄色
            else
                base_pixel_raw <= 16'h07E0; // 绿色
        end else begin
            base_pixel_raw <= base_ram[base_read_addr];
        end
    end
    
    // =========================================================
    // 3. 区域判定 & 输出
    // =========================================================
    
    wire is_bird_region;
    assign is_bird_region = (pixel_x >= bird_x[10:0]) && 
                            (pixel_x < bird_x[10:0] + BIRD_W) &&
                            (pixel_y >= bird_y[10:0]) && 
                            (pixel_y < bird_y[10:0] + BIRD_H);
                            
    wire is_pipe1 = (pixel_x >= pipe1_x[10:0]) && (pixel_x < pipe1_x[10:0] + PIPE_W) &&
                    (pixel_y < p1_gap_top || pixel_y > p1_gap_bot);
                    
    wire is_pipe2 = (pixel_x >= pipe2_x[10:0]) && (pixel_x < pipe2_x[10:0] + PIPE_W) &&
                    (pixel_y < p2_gap_top || pixel_y > p2_gap_bot);
    
    // base区域判断：只在游戏激活时显示
    wire is_base_region = game_active && (pixel_y >= GROUND_Y) && (pixel_y < GROUND_Y + BASE_H);
    
    // 延迟对齐
    reg is_bird_d1;
    reg is_pipe1_d1, is_pipe2_d1;
    reg is_base_d1;
    reg [15:0] bg_data_d1;
    reg [15:0] base_pixel_d1;
    
    always @(posedge clk) begin
        is_bird_d1 <= is_bird_region;
        is_pipe1_d1 <= is_pipe1;
        is_pipe2_d1 <= is_pipe2;
        is_base_d1 <= is_base_region;
        bg_data_d1 <= bg_data;
        base_pixel_d1 <= base_pixel_raw;
    end

    always @(*) begin
        // 优先级：小鸟 > 管道 > base > 背景
        if(is_bird_d1) begin
             // Check if Green (Transparency) OR Black/Empty (0x0000)
             if(bird_pixel_raw == TRANSPARENT_COLOR || bird_pixel_raw == 16'h0000) 
                 if(is_pipe1_d1 || is_pipe2_d1) pixel_out = pipe_pixel_raw; // 透出管道
                 else if(is_base_d1) pixel_out = base_pixel_d1; // 透出base
                 else pixel_out = bg_data_d1;
             else
                 pixel_out = bird_pixel_raw;
        end
        else if(is_pipe1_d1 || is_pipe2_d1) begin
             if(pipe_pixel_raw == TRANSPARENT_COLOR || pipe_pixel_raw == 16'h0000)
                 if(is_base_d1) pixel_out = base_pixel_d1; // 透出base
                 else pixel_out = bg_data_d1;
             else
                 pixel_out = pipe_pixel_raw; // 全身都使用纹理
        end
        else if(is_base_d1) begin
             pixel_out = base_pixel_d1;
        end
        else begin
             pixel_out = bg_data_d1;
        end
    end

endmodule
