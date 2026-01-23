`timescale 1ns / 1ps

module game_ctrl(
    input      clk,
    input      rst_n,
    input      key_jump,      // 按键输入 (高电平有效)
    input      collision,     // 碰撞信号
    
    output reg game_active,   // 游戏激活 (控制物理和管道)
    output reg [1:0] state    // 游戏状态: 0=IDLE/START, 1=PLAY, 2=OVER
);

    // 状态定义
    localparam S_IDLE = 2'd0;
    localparam S_PLAY = 2'd1;
    localparam S_OVER = 2'd2;
    
    reg [1:0] next_state;
    reg [1:0] current_state;
    
    // 按键边沿检测
    reg key_d0, key_d1;
    wire key_rise;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_d0 <= 0;
            key_d1 <= 0;
        end else begin
            key_d0 <= key_jump;
            key_d1 <= key_d0;
        end
    end
    assign key_rise = key_d0 & (~key_d1);
    
    // 状态机 - 状态跳转
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end
    
    // 状态机 - 组合逻辑
    always @(*) begin
        next_state = current_state;
        case(current_state)
            S_IDLE: begin
                // 按下跳跃键开始游戏
                if(key_rise)
                    next_state = S_PLAY;
            end
            
            S_PLAY: begin
                if(collision)
                    next_state = S_OVER;
            end
            
            S_OVER: begin
                // 再次按下跳跃键回到开始 (或者直接重新开始)
                if(key_rise)
                    next_state = S_IDLE; // 先回IDLE复位一下，或者直接S_PLAY
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // 输出逻辑
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            game_active <= 0;
            state <= S_IDLE;
        end else begin
            state <= current_state;
            if(current_state == S_PLAY)
                game_active <= 1;
            else
                game_active <= 0;
        end
    end

endmodule
