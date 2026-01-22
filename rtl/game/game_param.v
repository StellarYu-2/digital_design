`timescale 1ns / 1ps

module game_param(
    // 纯参数定义模块，无实际逻辑
);
    // 屏幕尺寸
    parameter H_DISP        = 1024;
    parameter V_DISP        = 768;
    
    // 小鸟物理参数
    parameter BIRD_WIDTH    = 50;   // 你的素材是50x35
    parameter BIRD_HEIGHT   = 35;
    parameter BIRD_X_INIT   = 300;  // 小鸟初始水平位置
    parameter BIRD_Y_INIT   = 384;  // 小鸟初始垂直位置 (屏幕垂直居中)
    
    parameter GRAVITY       = 1;    // 重力加速度 (每帧增加的速度)
    parameter JUMP_SPEED    = 12;   // 跳跃瞬间的向上速度
    parameter MAX_VELOCITY  = 15;   // 最大下落速度限制
    
    // 管道参数
    parameter PIPE_WIDTH    = 80;
    parameter PIPE_GAP      = 200;  // 上下管道的间隙
    parameter PIPE_DIST     = 350;  // 管道之间的水平距离
    parameter PIPE_SPEED    = 3;    // 管道移动速度 (像素/帧)
    
    // 地面参数
    parameter GROUND_Y      = 668;  // 地面Y坐标 (768 - 100)
    
endmodule
