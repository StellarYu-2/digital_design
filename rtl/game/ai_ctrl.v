`timescale 1ns / 1ps

module ai_ctrl(
    input             clk,
    input             rst_n,
    input             game_active,
    input             frame_en,
    
    input      [11:0] bird_y,
    input      [11:0] bird_x,
    input      [11:0] pipe1_x,
    input      [11:0] pipe1_gap_y, // 间隙中心Y坐标
    input      [11:0] pipe2_x,
    input      [11:0] pipe2_gap_y,
    
    input             key_auto,
    
    output reg        ai_jump_pulse,
    output reg        auto_mode
);

    // ================= 配置参数 =================
    parameter BIRD_X_POS     = 300;
    parameter BIRD_W         = 40;  // 小鸟判定宽度
    parameter PIPE_WIDTH     = 80;
    
    // 飞行策略参数
    parameter TARGET_OFFSET  = 10;  // 目标位置偏移：正数表示让小鸟在间隙中心偏下一点飞
                                    // 这样给跳跃后的上升弧度留出空间
    parameter JUMP_TOLERANCE = 15;  // 容差范围（迟滞区间），防止抽搐
    parameter JUMP_COOLDOWN_VAL = 8; // 跳跃冷却，防止连续触发飞出天花板

    // 边界安全参数
    parameter GROUND_Y       = 668;
    parameter CEILING_Y      = 20;
    
    // ================= 自动模式切换 (保持原样) =================
    reg key_auto_d0, key_auto_d1;
    wire key_auto_rise = key_auto_d0 & (~key_auto_d1);
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_auto_d0 <= 0;
            key_auto_d1 <= 0;
            auto_mode   <= 1'b1; // 默认开启
        end else begin
            key_auto_d0 <= key_auto;
            key_auto_d1 <= key_auto_d0;
            if(key_auto_rise) auto_mode <= ~auto_mode;
        end
    end
    
    // ================= 1. 核心改进：寻找当前目标管道 =================
    // 逻辑：找到位于小鸟右侧（或正在穿越）的最近管道
    // 判定标准：管道的右边缘 (pipe_x + width) 必须在小鸟左边缘 (bird_x) 之后
    
    reg [11:0] target_gap_y;
    
    // 为了比较方便，扩展位宽防止溢出
    wire [12:0] p1_right_edge = {1'b0, pipe1_x} + PIPE_WIDTH;
    wire [12:0] p2_right_edge = {1'b0, pipe2_x} + PIPE_WIDTH;
    wire [12:0] bird_left_edge = {1'b0, bird_x};

    // 判断管道是否有效（还没有完全通过小鸟）
    wire p1_active = (p1_right_edge > bird_left_edge);
    wire p2_active = (p2_right_edge > bird_left_edge);
    
    always @(*) begin
        // 如果管道1在有效范围内
        if (p1_active) begin
            // 如果管道2也在有效范围内，比较谁更近（X更小）
            if (p2_active && (pipe2_x < pipe1_x))
                target_gap_y = pipe2_gap_y;
            else
                target_gap_y = pipe1_gap_y;
        end
        // 如果管道1无效（已通过），那目标肯定是管道2
        else begin
            target_gap_y = pipe2_gap_y;
        end
    end
    
    // ================= 2. 核心改进：基于迟滞区间的飞行控制 =================
    
    reg [3:0] cooldown_cnt;
    
    // 计算理想飞行高度：间隙中心 + 偏移量
    // 因为Flappy Bird重力向下，跳跃瞬间向上，所以维持在中心偏下比较安全
    wire [11:0] ideal_y = target_gap_y + TARGET_OFFSET;
    
    // 触发跳跃的阈值线：当小鸟掉落到这个线以下时，起跳
    wire [11:0] jump_threshold = ideal_y + JUMP_TOLERANCE;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ai_jump_pulse <= 0;
            cooldown_cnt <= 0;
        end else begin
            ai_jump_pulse <= 0; // 默认拉低（脉冲信号）
            
            // 冷却计数器递减
            if(cooldown_cnt > 0)
                cooldown_cnt <= cooldown_cnt - 1'b1;
                
            if(auto_mode && game_active && frame_en) begin
                
                // 优先级1：绝对防撞地保护 (Emergency)
                if(bird_y > GROUND_Y - 50) begin 
                    if(cooldown_cnt == 0) begin
                        ai_jump_pulse <= 1'b1;
                        cooldown_cnt  <= JUMP_COOLDOWN_VAL;
                    end
                end
                
                // 优先级2：绝对防撞天花板保护
                else if(bird_y < CEILING_Y) begin
                    // 强制不跳，即使触发了下面的逻辑
                    ai_jump_pulse <= 1'b0;
                end
                
                // 优先级3：正常追踪管道
                else begin
                    // 只有冷却结束才能跳
                    if(cooldown_cnt == 0) begin
                        // 简单粗暴且有效：
                        // 如果小鸟当前的Y坐标 大于（低于） 触发阈值，就跳一下
                        if(bird_y > jump_threshold) begin
                            ai_jump_pulse <= 1'b1;
                            cooldown_cnt  <= JUMP_COOLDOWN_VAL;
                        end
                    end
                end
            end
        end
    end

endmodule