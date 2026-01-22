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
    
    // 小鸟纹理加载接口 (写入端口)
    input             bird_load_clk, // 写时钟 (50MHz)
    input             bird_load_en,  // 写使能
    input      [12:0] bird_load_addr,// 输入的连续地址
    input      [15:0] bird_load_data,// 写数据
    
    // 最终像素输出
    output reg [15:0] pixel_out
);

    // 参数
    parameter BIRD_W = 50;
    parameter BIRD_H = 35;
    parameter PIPE_W = 80;
    parameter PIPE_GAP_H = 140; // 管道开口大小
    parameter COLOR_PIPE = 16'h07E0; // 纯绿
    
    // =========================================================
    // 1. 小鸟纹理存储 (Dual Port RAM)
    // 大小: 50*35 * 3张 = 5250 words.
    // =========================================================
    reg [15:0] bird_ram [0:5249];
    reg [15:0] bird_pixel_raw;
    
    // --- 写入逻辑 (简单直接写入) ---
    // 由于 sd_multi_pic 已经剔除了 Padding，这里收到的就是纯像素流
    always @(posedge bird_load_clk) begin
        if(bird_load_en) begin
            // 简单保护，防止溢出
            if(bird_load_addr < 5250)
                bird_ram[bird_load_addr] <= bird_load_data;
        end
    end
    
    // --- 动画控制逻辑 (暂时禁用，固定显示 mid) ---
    reg [5:0]  anim_frame_cnt; 
    reg [1:0]  bird_anim_idx;
    
    always @(posedge clk) begin
        if(!rst_n) begin
             anim_frame_cnt <= 0;
             // 固定显示第2张图 (index 1)，即 bird_mid
             bird_anim_idx <= 2'd1; 
        end 
        // 暂时注释掉动画切换代码
        /*
        else if(pixel_y == 0 && pixel_x == 0) begin 
            anim_frame_cnt <= anim_frame_cnt + 1'b1;
            if(anim_frame_cnt == 10) begin 
                anim_frame_cnt <= 0;
                if(bird_anim_idx == 2) bird_anim_idx <= 0;
                else bird_anim_idx <= bird_anim_idx + 1'b1;
            end
        end
        */
    end

    // --- 读取逻辑 ---
    wire [12:0] bird_read_addr_base;
    wire [12:0] bird_read_offset;
    wire [10:0] bird_dx = pixel_x - bird_x[10:0];
    wire [10:0] bird_dy = pixel_y - bird_y[10:0];
    
    // 动画地址偏移: 0, 1750, 3500
    assign bird_read_addr_base = (bird_anim_idx == 0) ? 13'd0 : 
                                 (bird_anim_idx == 1) ? 13'd1750 : 13'd3500;
                                 
    // 增加校准偏移量：修复循环位移问题
    // 现象：屁股在头前 -> 说明图像左移了 -> 我们需要读取更前面的数据？
    // 尝试 offset + 25 像素
    // 简单做法：我们只修正行内偏移。
    // 行内 50 像素。 (dx + correction) % 50
    // 如果 dx + 25 >= 50, 则 dx - 25.
    
    wire [10:0] dx_corrected = (bird_dx >= 17) ? (bird_dx - 17) : (bird_dx + 33);
    
    assign bird_read_offset = bird_dy * BIRD_W + dx_corrected;
    
    always @(posedge clk) begin
        // 地址 = 基地址 + 偏移
        bird_pixel_raw <= bird_ram[bird_read_addr_base + bird_read_offset];
    end
    
    // =========================================================
    // 2. 区域判定 logic
    // =========================================================
    
    // 小鸟区域判定
    wire is_bird_region;
    assign is_bird_region = (pixel_x >= bird_x[10:0]) && 
                            (pixel_x < bird_x[10:0] + BIRD_W) &&
                            (pixel_y >= bird_y[10:0]) && 
                            (pixel_y < bird_y[10:0] + BIRD_H);
                            
    // 管道1区域判定
    wire is_pipe1;
    wire [11:0] p1_gap_top = pipe1_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p1_gap_bot = pipe1_gap_y + (PIPE_GAP_H/2);
    
    assign is_pipe1 = (pixel_x >= pipe1_x[10:0]) && (pixel_x < pipe1_x[10:0] + PIPE_W) &&
                      (pixel_y < p1_gap_top || pixel_y > p1_gap_bot);
                      
    // 管道2区域判定
    wire is_pipe2;
    wire [11:0] p2_gap_top = pipe2_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p2_gap_bot = pipe2_gap_y + (PIPE_GAP_H/2);
    
    assign is_pipe2 = (pixel_x >= pipe2_x[10:0]) && (pixel_x < pipe2_x[10:0] + PIPE_W) &&
                      (pixel_y < p2_gap_top || pixel_y > p2_gap_bot);

    // =========================================================
    // 3. 输出多路选择
    // =========================================================
    reg is_bird_d1;
    reg is_pipe1_d1, is_pipe2_d1;
    reg [15:0] bg_data_d1;
    
    always @(posedge clk) begin
        is_bird_d1 <= is_bird_region;
        is_pipe1_d1 <= is_pipe1;
        is_pipe2_d1 <= is_pipe2;
        bg_data_d1 <= bg_data;
    end

    always @(*) begin
        // 优先级：小鸟 > 管道 > 背景
        if(is_bird_d1) begin
             // 调试模式：
             // 1. 如果读到纯黑(0000)，显示深蓝色(001F)，帮助判断数据缺失区域
             // 2. 如果读到纯白(FFFF)，视为透明
             if(bird_pixel_raw == 16'h0000)
                 pixel_out = 16'h001F; // 调试蓝：表示此处RAM无数据
             else if(bird_pixel_raw == 16'hFFFF) 
                 if(is_pipe1_d1 || is_pipe2_d1) pixel_out = COLOR_PIPE;
                 else pixel_out = bg_data_d1;
             else
                 pixel_out = bird_pixel_raw;
        end
        else if(is_pipe1_d1 || is_pipe2_d1) begin
             pixel_out = COLOR_PIPE; 
        end
        else begin
             pixel_out = bg_data_d1;
        end
    end

endmodule
