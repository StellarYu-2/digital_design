`timescale 1ns / 1ps

module bird_ctrl(
    input             clk,          // 必须连接 65MHz 的 HDMI 时钟
    input             rst_n,        // 复位
    input             key_jump,     // 跳跃按键（手动模式）
    input             ai_jump,      // AI跳跃信号（自动模式）
    input             auto_mode,    // 自动模式标志：1=自动，0=手动
    input             game_active,  // 游戏激活状态
    input             frame_en_unused, // (弃用外部帧信号)
    
    output reg [11:0] bird_y,       // 小鸟当前的Y坐标
    output reg [11:0] bird_x,       // 小鸟当前的X坐标 
    output reg [9:0]  bird_angle    // 小鸟角度 
);

    // ---------------------------------------------------------
    // 参数定义
    // ---------------------------------------------------------
    parameter BIRD_X_INIT = 300;
    parameter BIRD_Y_INIT = 384;
    parameter GRAVITY     = 1;
    parameter JUMP_SPEED  = 12;
    parameter MAX_VELOCITY= 15;
    parameter GROUND_Y    = 668; // 地面Y坐标
    parameter BIRD_HEIGHT = 35;  // 小鸟高度

    // 内部信号
    reg signed [9:0] velocity;   // 垂直速度 (负数向上，正数向下)
    
    // ---------------------------------------------------------
    // 1. 内部产生 60Hz 帧信号 (基于 65MHz 时钟)
    // 65,000,000 / 60 ≈ 1,083,333
    // ---------------------------------------------------------
    reg [20:0] clk_cnt;
    wire       frame_pulse;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clk_cnt <= 0;
        end else begin
            if(clk_cnt >= 1083333) 
                clk_cnt <= 0;
            else 
                clk_cnt <= clk_cnt + 1'b1;
        end
    end
    assign frame_pulse = (clk_cnt == 1083333); // 每16ms产生一个脉冲

    // ---------------------------------------------------------
    // 2. 按键检测 (简单的边沿检测 + 简易防抖)
    // ---------------------------------------------------------
    reg key_d0, key_d1;
    wire manual_jump_trigger;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_d0 <= 0;
            key_d1 <= 0;
        end else begin
            key_d0 <= key_jump;
            key_d1 <= key_d0;
        end
    end
    // 检测 0->1 上升沿 (假设顶层传入的是处理好极性的信号)
    assign manual_jump_trigger = key_d0 & (~key_d1);
    
    // 合并手动和AI跳跃信号
    wire jump_trigger = auto_mode ? ai_jump : manual_jump_trigger;

    // ---------------------------------------------------------
    // 3. 物理引擎核心
    // ---------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bird_y   <= BIRD_Y_INIT;
            bird_x   <= BIRD_X_INIT;
            velocity <= 0;
            bird_angle <= 0;
        end
        else begin
            if (game_active) begin
                // A. 跳跃处理 (优先级最高，随时响应)
                if (jump_trigger) begin
                    velocity <= -JUMP_SPEED; 
                end
                
                // B. 物理更新 (每帧一次)
                else if (frame_pulse) begin
                    // 速度限制
                    if (velocity < MAX_VELOCITY)
                        velocity <= velocity + GRAVITY;
                    
                    // 位置更新 (关键：必须全部转为 signed 进行比较和计算)
                    // 下一帧的预测位置
                    if ($signed(bird_y) + velocity >= $signed(GROUND_Y - BIRD_HEIGHT)) begin
                         // 碰到地面
                         bird_y <= GROUND_Y - BIRD_HEIGHT;
                         // velocity <= 0; // 可选：落地停住
                    end
                    else if ($signed(bird_y) + velocity <= 0) begin
                         // 碰到天花板
                         bird_y <= 0;
                         velocity <= 0;
                    end
                    else begin
                         // 正常运动
                         bird_y <= $signed(bird_y) + velocity;
                    end
                end
            end
            else begin
                // 复位状态
                bird_y   <= BIRD_Y_INIT;
                bird_x   <= BIRD_X_INIT;
                velocity <= 0;
            end
        end
    end

endmodule
