`timescale 1ns / 1ps

module collision_det(
    input             clk,
    input             rst_n,
    
    // 小鸟位置
    input      [11:0] bird_y,
    input      [11:0] bird_x,
    
    // 管道位置
    input      [11:0] pipe1_x,
    input      [11:0] pipe1_gap_y,
    input      [11:0] pipe2_x,
    input      [11:0] pipe2_gap_y,
    
    output reg        collision
);

    // ---------------------------------------------------------
    // 参数定义 (必须与 bird_ctrl 和 pipe_gen 保持一致)
    // ---------------------------------------------------------
    parameter BIRD_W     = 50;
    parameter BIRD_H     = 35;
    parameter PIPE_W     = 80;
    parameter PIPE_GAP_H = 220; // 增大碰撞检测缝隙 (原来是140)
    // 检查 sprite_render.v: parameter PIPE_GAP_H = 140; 
    // 检查 pipe_gen.v: parameter PIPE_GAP_H = 200; 
    // 以 sprite_render (视觉) 为准，或者取更严格的判定。
    // 如果渲染是140空隙，物理也是140比较合理。这里暂时设为140以匹配视觉。
    
    parameter GROUND_Y   = 668;

    // ---------------------------------------------------------
    // 碰撞逻辑
    // ---------------------------------------------------------
    
    // 1. 地面/天花板碰撞
    // bird_ctrl 已经限制了 y 的范围，但我们这里作为游戏结束的判定
    wire hit_ground;
    assign hit_ground = (bird_y >= GROUND_Y - BIRD_H);
    
    wire hit_ceiling;
    assign hit_ceiling = (bird_y <= 0);

    // 2. 管道碰撞
    // 矩形 AABB 碰撞检测
    // Bird: [bird_x, bird_x+W], [bird_y, bird_y+H]
    // Pipe1 Top: [pipe1_x, pipe1_x+W], [0, pipe1_gap_y - GAP/2]
    // Pipe1 Bot: [pipe1_x, pipe1_x+W], [pipe1_gap_y + GAP/2, SCREEN_H]
    
    wire [11:0] bird_r = bird_x + BIRD_W;
    wire [11:0] bird_b = bird_y + BIRD_H;
    
    wire [11:0] p1_l = pipe1_x;
    wire [11:0] p1_r = pipe1_x + PIPE_W;
    wire [11:0] p1_gap_top = pipe1_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p1_gap_bot = pipe1_gap_y + (PIPE_GAP_H/2);
    
    wire hit_pipe1;
    // 水平方向重叠
    wire p1_x_overlap = (bird_r > p1_l) && (bird_x < p1_r);
    // 垂直方向不在缝隙内 (即碰到上管 OR 碰到下管)
    // 碰到上管: bird_y < p1_gap_top (这里应该比较 bird的top，其实只要有一部分在管子里就算)
    // 考虑到 bird_y 是左上角。
    // 如果 bird_y < p1_gap_top，说明鸟头撞上管。
    // 如果 bird_b > p1_gap_bot，说明鸟脚撞下管。
    // 稍微缩小一点碰撞箱(Hitbox)可以增加容错率 (如各减2像素)
    wire p1_y_hit = (bird_y + 5 < p1_gap_top) || (bird_b - 5 > p1_gap_bot);
    
    assign hit_pipe1 = p1_x_overlap && p1_y_hit;
    
    // Pipe 2
    wire [11:0] p2_l = pipe2_x;
    wire [11:0] p2_r = pipe2_x + PIPE_W;
    wire [11:0] p2_gap_top = pipe2_gap_y - (PIPE_GAP_H/2);
    wire [11:0] p2_gap_bot = pipe2_gap_y + (PIPE_GAP_H/2);
    
    wire hit_pipe2;
    wire p2_x_overlap = (bird_r > p2_l) && (bird_x < p2_r);
    wire p2_y_hit = (bird_y + 5 < p2_gap_top) || (bird_b - 5 > p2_gap_bot);
    
    assign hit_pipe2 = p2_x_overlap && p2_y_hit;
    
    // ---------------------------------------------------------
    // 输出
    // ---------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            collision <= 0;
        else begin
            if(hit_ground || hit_ceiling || hit_pipe1 || hit_pipe2)
                collision <= 1;
            else
                collision <= 0;
        end
    end

endmodule
