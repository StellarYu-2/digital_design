`timescale 1ns / 1ps

module pipe_gen(
    input              clk,
    input              rst_n,
    input              game_active,
    input              frame_en,      // 帧同步信号
    input      [15:0]  random_seed,   // 随机数种子(可用行扫描计数器)
    
    output reg [11:0]  pipe1_x,       // 第一根管道的左边缘X坐标
    output reg [11:0]  pipe1_gap_y,   // 第一根管道的缝隙中心Y坐标
    output reg [11:0]  pipe2_x,       
    output reg [11:0]  pipe2_gap_y,
    output reg         score_pulse    // 得分脉冲
);

    parameter PIPE_START_X = 150;        // 调试：初始位置靠近左侧，便于观察重置
    parameter PIPE_DIST    = 350;        // 增大管道间距 (适当放宽)
    parameter PIPE_SPEED   = 3;          // 初始移动速度
    parameter PIPE_GAP_H   = 220;        // 增大缝隙高度 (原来是200)
    parameter BIRD_X_pos   = 300;        // 小鸟位置
    parameter PIPE_W       = 80;         // 管道宽度
    
    // 速度递增参数
    parameter SPEED_UP_INTERVAL = 180;  // 3秒 = 180帧 (60fps)
    parameter SPEED_FACTOR_NUM  = 11;    // 1.1倍 = 11/10
    parameter SPEED_FACTOR_DEN  = 10;    // 分母
    parameter MAX_SPEED         = 30;    // 最大速度限制

    // 简单的伪随机数生成
    reg [15:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            lfsr <= 16'hACE1;
        else if(frame_en)
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]}; // 伽罗瓦LFSR
    end
    
    // 速度递增逻辑
    reg [11:0] speed_timer;        // 30秒计时器
    reg [7:0]  current_speed_num;  // 当前速度分子（初始为 PIPE_SPEED * 10）
    reg [3:0]  speed_level;        // 速度等级（用于调试）
    
    wire [7:0] current_speed = current_speed_num / SPEED_FACTOR_DEN;  // 实际速度值
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            speed_timer <= 0;
            current_speed_num <= PIPE_SPEED * SPEED_FACTOR_DEN;  // 初始速度 = 3 * 10 = 30
            speed_level <= 0;
        end
        else if(game_active && frame_en) begin
            // 计时器递增
            if(speed_timer < SPEED_UP_INTERVAL)
                speed_timer <= speed_timer + 1'b1;
            else begin
                // 30秒到达，速度增加0.1倍
                speed_timer <= 0;
                speed_level <= speed_level + 1'b1;
                // 速度乘以1.1（如果未达到最大值）
                if(current_speed_num < MAX_SPEED * SPEED_FACTOR_DEN)
                    current_speed_num <= (current_speed_num * SPEED_FACTOR_NUM) / SPEED_FACTOR_DEN;
            end
        end
        else if(!game_active) begin
            // 游戏复位时重置速度
            speed_timer <= 0;
            current_speed_num <= PIPE_SPEED * SPEED_FACTOR_DEN;
            speed_level <= 0;
        end
    end

    // 管道移动逻辑
    reg [11:0] pipe1_x_d1, pipe2_x_d1; // 上一帧的位置
    wire       pass_pipe1, pass_pipe2;
    wire [11:0] pass_threshold = BIRD_X_pos - PIPE_W; // 220

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pipe1_x <= PIPE_START_X;
            pipe2_x <= PIPE_START_X + PIPE_DIST;
            pipe1_gap_y <= 384; // 屏幕中间
            pipe2_gap_y <= 300;
            pipe1_x_d1 <= PIPE_START_X;
            pipe2_x_d1 <= PIPE_START_X + PIPE_DIST;
            score_pulse <= 0;
        end
        else if(game_active && frame_en) begin
            pipe1_x_d1 <= pipe1_x;
            pipe2_x_d1 <= pipe2_x;
            
            // 产生得分脉冲
            // 当管道X坐标跨过阈值时 (从 >= 220 变为 < 220)
            if((pipe1_x_d1 >= pass_threshold && pipe1_x < pass_threshold) || 
               (pipe2_x_d1 >= pass_threshold && pipe2_x < pass_threshold))
                score_pulse <= 1;
            else
                score_pulse <= 0;

            // 管道1移动（使用动态速度）
            if(pipe1_x + 80 > 0 && pipe1_x < 2000) // 防止溢出
                pipe1_x <= pipe1_x - current_speed;
            else begin
                // 超出左边界，回到最右边
                pipe1_x <= 1024;
                // 随机生成新高度 (范围 200 ~ 568)
                pipe1_gap_y <= 200 + (lfsr % 300); 
            end
            
            // 管道2移动（使用动态速度）
            if(pipe2_x + 80 > 0 && pipe2_x < 2000)
                pipe2_x <= pipe2_x - current_speed;
            else begin
                pipe2_x <= 1024;
                pipe2_gap_y <= 200 + ((lfsr + 100) % 300);
            end
        end
        else if(!game_active) begin
            // 游戏复位
            pipe1_x <= PIPE_START_X;
            pipe2_x <= PIPE_START_X + PIPE_DIST;
            score_pulse <= 0;
        end
        else begin
             score_pulse <= 0;
        end
    end

endmodule
