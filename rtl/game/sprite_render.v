`timescale 1ns / 1ps

module sprite_render(
    input             clk,            // 像素时钟
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
    input      [12:0] bird_load_addr,// 小鸟地址
    input      [15:0] bird_load_data,// 写数据
    
    // 管道纹理加载接口
    input             pipe_load_en,
    input      [15:0] pipe_load_addr,
    
    // 地面纹理加载接口
    input             base_load_en,
    input      [13:0] base_load_addr,
    
    // 游戏状态
    input             game_active,
    input             frame_en, // 帧同步信号
    
    // 最终像素输出
    output reg [15:0] pixel_out
);

    // 参数
    parameter BIRD_W = 50;
    parameter BIRD_H = 35;
    parameter PIPE_W = 80;
    parameter PIPE_H = 500; 
    parameter PIPE_GAP_H = 220; 
    parameter COLOR_PIPE = 16'h07E0; 
    parameter TRANSPARENT_COLOR = 16'h07E0; 
    
    // 地面参数
    parameter BASE_TEX_W = 64;  
    parameter BASE_H     = 150; 
    parameter GROUND_Y   = 618; // 768 - 150
    
    // =========================================================
    // 1. 纹理存储 (RAM)
    // =========================================================
    reg [15:0] bird_ram [0:5249];
    reg [15:0] bird_pixel_raw;
    
    always @(posedge bird_load_clk) begin
        if(bird_load_en && bird_load_addr < 5250)
             bird_ram[bird_load_addr] <= bird_load_data;
    end
    
    // 管道纹理 (只存前50行)
    parameter PIPE_TEX_H = 50; 
    reg [15:0] pipe_ram [0:3999]; // 80 * 50 = 4000
    reg [15:0] pipe_pixel_raw;
    
    always @(posedge bird_load_clk) begin
        if(pipe_load_en && pipe_load_addr < 4000)
             pipe_ram[pipe_load_addr] <= bird_load_data;
    end
    
    // 地面纹理
    reg [15:0] base_ram [0:9599];
    reg [15:0] base_pixel_raw;
    
    always @(posedge bird_load_clk) begin
        if(base_load_en && base_load_addr < 9600)
             base_ram[base_load_addr] <= bird_load_data;
    end
    
    // =========================================================
    // 2. 动画与读取逻辑
    // =========================================================
    
    // --- 小鸟翅膀动画 ---
    reg [1:0]  bird_anim_idx;
    reg [2:0]  anim_frame_cnt;
    reg        anim_dir;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bird_anim_idx   <= 2'd1;
            anim_frame_cnt  <= 3'd0;
            anim_dir        <= 1'b0;
        end else if(frame_en && game_active) begin
            if(anim_frame_cnt >= 3'd7) begin
                anim_frame_cnt <= 3'd0;
                if(anim_dir == 1'b0) begin 
                    if(bird_anim_idx >= 2'd2) begin
                        bird_anim_idx <= 2'd1;
                        anim_dir <= 1'b1;
                    end else begin
                        bird_anim_idx <= bird_anim_idx + 1'b1;
                    end
                end else begin
                    if(bird_anim_idx <= 2'd0) begin
                        bird_anim_idx <= 2'd1;
                        anim_dir <= 1'b0;
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
                                 
    assign bird_read_offset = bird_dy * BIRD_W + bird_dx;
    
    // --- 地面读取逻辑 ---
    reg [5:0] base_scroll_x;
    
    always @(posedge clk) begin
        if(!rst_n) 
            base_scroll_x <= 0;
        else if(frame_en && game_active)
            base_scroll_x <= base_scroll_x + 3;
    end
    
    reg [13:0] base_read_addr;
    
    // [修复] 将变量声明移至 always 块顶部
    reg [5:0] base_tex_x;
    reg [7:0] base_tex_y;
    
    always @(*) begin
        base_read_addr = 0;
        base_tex_x = 0; // 赋初值
        base_tex_y = 0;
        
        if(pixel_y >= GROUND_Y) begin
            // Texture X = (Screen X + Scroll Offset) % 64
            base_tex_x = pixel_x[5:0] + base_scroll_x;
            base_tex_y = pixel_y - GROUND_Y;
            
            if(base_tex_y < BASE_H)
                base_read_addr = base_tex_y * BASE_TEX_W + base_tex_x;
        end
    end
    
    // --- 管道读取逻辑 ---
    wire [11:0] p1_gap_top = pipe1_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p1_gap_bot = pipe1_gap_y + (PIPE_GAP_H/2);
    wire [11:0] p2_gap_top = pipe2_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p2_gap_bot = pipe2_gap_y + (PIPE_GAP_H/2);
    
    reg [11:0] pipe_read_addr;
    localparam PIPE_SPLIT_Y = 10;

    // [修复] 将变量声明移至 always 块顶部，供两个管道逻辑复用
    reg [10:0] pipe_tex_x;
    reg [10:0] pipe_tex_y;
    reg [10:0] pipe_effective_y;

    always @(*) begin
        pipe_read_addr = 0;
        pipe_tex_x = 0;
        pipe_tex_y = 0;
        pipe_effective_y = 0;
        
        // --- 管道1 ---
        if(pixel_x >= pipe1_x[10:0] && pixel_x < pipe1_x[10:0] + PIPE_W) begin
            pipe_tex_x = pixel_x - pipe1_x[10:0];
            
            if(pixel_y < p1_gap_top) begin // 上管
                pipe_tex_y = (p1_gap_top - 1) - pixel_y;
                
                if(pipe_tex_y < PIPE_SPLIT_Y)
                    pipe_effective_y = (PIPE_SPLIT_Y - 1) - pipe_tex_y;
                else
                    pipe_effective_y = 0; 
                    
                pipe_read_addr = pipe_effective_y * PIPE_W + pipe_tex_x;
            end
            else if(pixel_y > p1_gap_bot) begin // 下管
                pipe_tex_y = pixel_y - p1_gap_bot;
                
                if(pipe_tex_y < PIPE_SPLIT_Y)
                    pipe_effective_y = pipe_tex_y;
                else
                    pipe_effective_y = PIPE_SPLIT_Y; 
                    
                pipe_read_addr = pipe_effective_y * PIPE_W + pipe_tex_x;
            end
        end
        
        // --- 管道2 ---
        else if(pixel_x >= pipe2_x[10:0] && pixel_x < pipe2_x[10:0] + PIPE_W) begin
            pipe_tex_x = pixel_x - pipe2_x[10:0];
            
            if(pixel_y < p2_gap_top) begin // 上管
                pipe_tex_y = (p2_gap_top - 1) - pixel_y;
                
                if(pipe_tex_y < PIPE_SPLIT_Y)
                    pipe_effective_y = (PIPE_SPLIT_Y - 1) - pipe_tex_y;
                else
                    pipe_effective_y = 0;
                    
                pipe_read_addr = pipe_effective_y * PIPE_W + pipe_tex_x;
            end
            else if(pixel_y > p2_gap_bot) begin // 下管
                pipe_tex_y = pixel_y - p2_gap_bot;
                
                if(pipe_tex_y < PIPE_SPLIT_Y)
                    pipe_effective_y = pipe_tex_y;
                else
                    pipe_effective_y = PIPE_SPLIT_Y; 
                    
                pipe_read_addr = pipe_effective_y * PIPE_W + pipe_tex_x;
            end
        end
    end
    
    // 内存读取 (同步)
    always @(posedge clk) begin
        bird_pixel_raw <= bird_ram[bird_read_addr_base + bird_read_offset];
        pipe_pixel_raw <= pipe_ram[pipe_read_addr];
        base_pixel_raw <= base_ram[base_read_addr];
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
        // 优先级：小鸟 > base > 管道 > 背景
        if(is_bird_d1) begin
             if(bird_pixel_raw == TRANSPARENT_COLOR || bird_pixel_raw == 16'h0000) 
                 if(is_base_d1) pixel_out = base_pixel_d1;
                 else if(is_pipe1_d1 || is_pipe2_d1) pixel_out = pipe_pixel_raw;
                 else pixel_out = bg_data_d1;
             else
                 pixel_out = bird_pixel_raw;
        end
        else if(is_base_d1) begin
             pixel_out = base_pixel_d1;
        end
        else if(is_pipe1_d1 || is_pipe2_d1) begin
             if(pipe_pixel_raw == TRANSPARENT_COLOR || pipe_pixel_raw == 16'h0000)
                 pixel_out = bg_data_d1;
             else
                 pixel_out = pipe_pixel_raw;
        end
        else begin
             pixel_out = bg_data_d1;
        end
    end

endmodule