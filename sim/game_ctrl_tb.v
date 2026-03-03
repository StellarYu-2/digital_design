`timescale 1ns / 1ps

module game_ctrl_tb();

    // ---------------------------------------------------------
    // 信号定义
    // ---------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         key_jump;
    reg         collision;
    reg         score_pulse;
    
    wire        game_active;
    wire [1:0]  state;
    wire [23:0] score_bcd;

    // ---------------------------------------------------------
    // 例化待测设计 (DUT)
    // ---------------------------------------------------------
    game_ctrl u_game_ctrl (
        .clk         (clk),
        .rst_n       (rst_n),
        .key_jump    (key_jump),
        .collision   (collision),
        .score_pulse (score_pulse),
        .game_active (game_active),
        .state       (state),
        .score_bcd   (score_bcd)
    );

    // ---------------------------------------------------------
    // 时钟生成 (20ns 周期，50MHz)
    // ---------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // ---------------------------------------------------------
    // 辅助任务：模拟按键按下
    // ---------------------------------------------------------
    task press_key;
        begin
            key_jump = 1;
            #40; // 按下维持两个时钟周期
            key_jump = 0;
            #100; // 松开后的缓冲时间
        end
    endtask

    // ---------------------------------------------------------
    // 激励产生：模拟完整的一局游戏
    // ---------------------------------------------------------
    initial begin
        // --- 1. 初始化 & 复位 ---
        rst_n       = 0;
        key_jump    = 0;
        collision   = 0;
        score_pulse = 0;

        #50;
        rst_n = 1;
        #50;

        // 当前应该处于 S_IDLE (状态 0)

        // --- 2. 玩家按下跳跃键，开始游戏 ---
        $display("-> Player starts the game...");
        press_key();
        
        // 当前应该进入 S_PLAY (状态 1)，game_active 变 1
        #100;

        // --- 3. 玩家连续得分 (测试 BCD 进位逻辑) ---
        // 我们连续给 12 个得分脉冲，观察分数怎么从 09 变成 10
        $display("-> Player is scoring...");
        repeat(12) begin
            #200;
            score_pulse = 1;
            #20; // 脉冲维持一个周期
            score_pulse = 0;
        end

        #200;

        // --- 4. 玩家失误，撞到水管 ---
        $display("-> Oops! Bird hits a pipe...");
        collision = 1;
        #20;
        collision = 0;

        // 当前应该进入 S_OVER (状态 2)，game_active 变 0
        #150;

        // --- 5. 玩家再次按键，返回主界面准备重开 ---
        $display("-> Player presses key to restart...");
        press_key();

        // 此时状态应该回到 S_IDLE (状态 0)，且分数瞬间清零
        #100;

        // 再次开局证明复位成功
        press_key();
        #200;

        $display("Simulation Finished!");
        $stop;
    end

endmodule