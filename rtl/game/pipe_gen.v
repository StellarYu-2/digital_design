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
    output reg [11:0]  pipe2_gap_y
);

    parameter PIPE_START_X = 600;        // 调试：初始位置改在屏幕内
    parameter PIPE_DIST    = 300;        // 两根管道间隔变小以便观察
    parameter PIPE_SPEED   = 3;          // 移动速度
    parameter PIPE_GAP_H   = 200;        // 缝隙高度
    
    // 简单的伪随机数生成
    reg [15:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            lfsr <= 16'hACE1;
        else if(frame_en)
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]}; // 伽罗瓦LFSR
    end

    // 管道移动逻辑
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pipe1_x <= PIPE_START_X;
            pipe2_x <= PIPE_START_X + PIPE_DIST;
            pipe1_gap_y <= 384; // 屏幕中间
            pipe2_gap_y <= 300;
        end
        else if(game_active && frame_en) begin
            // 管道1移动
            if(pipe1_x + 80 > 0 && pipe1_x < 2000) // 防止溢出
                pipe1_x <= pipe1_x - PIPE_SPEED;
            else begin
                // 超出左边界，回到最右边
                pipe1_x <= 1024;
                // 随机生成新高度 (范围 200 ~ 568)
                pipe1_gap_y <= 200 + (lfsr % 300); 
            end
            
            // 管道2移动
            if(pipe2_x + 80 > 0 && pipe2_x < 2000)
                pipe2_x <= pipe2_x - PIPE_SPEED;
            else begin
                pipe2_x <= 1024;
                pipe2_gap_y <= 200 + ((lfsr + 100) % 300);
            end
        end
        else if(!game_active) begin
            // 游戏复位
            pipe1_x <= PIPE_START_X;
            pipe2_x <= PIPE_START_X + PIPE_DIST;
        end
    end

endmodule
