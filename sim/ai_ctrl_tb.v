`timescale 1ns / 1ps

module ai_ctrl_tb();

    // ---------------------------------------------------------
    // 信号定义
    // ---------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         game_active;
    reg         frame_en;
    
    reg  [11:0] bird_y;
    reg  [11:0] bird_x;
    reg  [11:0] pipe1_x;
    reg  [11:0] pipe1_gap_y;
    reg  [11:0] pipe2_x;
    reg  [11:0] pipe2_gap_y;
    
    reg         key_auto;
    
    wire        ai_jump_pulse;
    wire        auto_mode;

    // ---------------------------------------------------------
    // 例化待测设计 (DUT)
    // ---------------------------------------------------------
    ai_ctrl u_ai_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .game_active   (game_active),
        .frame_en      (frame_en),
        .bird_y        (bird_y),
        .bird_x        (bird_x),
        .pipe1_x       (pipe1_x),
        .pipe1_gap_y   (pipe1_gap_y),
        .pipe2_x       (pipe2_x),
        .pipe2_gap_y   (pipe2_gap_y),
        .key_auto      (key_auto),
        .ai_jump_pulse (ai_jump_pulse),
        .auto_mode     (auto_mode)
    );

    // ---------------------------------------------------------
    // 时钟与帧同步生成
    // ---------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk; // 20ns 周期

    initial begin
        frame_en = 0;
        forever begin
            #180;
            frame_en = 1;
            #20;
            frame_en = 0;
        end
    end

    // ---------------------------------------------------------
    // 激励产生
    // ---------------------------------------------------------
    initial begin
        // --- 初始化 ---
        rst_n       = 0;
        game_active = 0;
        key_auto    = 0;
        bird_x      = 300;
        bird_y      = 384;
        pipe1_x     = 500;  // 管道1在小鸟右侧 (目标应该是它)
        pipe1_gap_y = 300;
        pipe2_x     = 800;  // 管道2在更远的右侧
        pipe2_gap_y = 400;

        #50;
        rst_n = 1;
        game_active = 1;
        #100;

        // --- 场景 1：自动模式开关测试 ---
        // 默认 auto_mode 应该是 1
        key_auto = 1; #40; key_auto = 0; // 模拟按键按下，关闭 AI
        #100;
        key_auto = 1; #40; key_auto = 0; // 再次按下，开启 AI
        #100;

        // --- 场景 2：正常追踪跳跃测试 ---
        // 目标是 pipe1_gap_y (300)。理想Y=310，阈值=325
        bird_y = 310; // 安全高度，不跳
        #200;
        bird_y = 330; // 跌破阈值 325，触发跳跃
        #200;
        bird_y = 310; // 跳高了，恢复安全，不跳
        #200;

        // --- 场景 3：目标水管切换测试 ---
        // 模拟管道1被小鸟越过 (左移到 200，宽度80，右边缘=280 < 小鸟X 300)
        // 此时 AI 的目标应该瞬间切换为 pipe2_gap_y (400)。理想Y=410，阈值=425
        pipe1_x = 200; 
        bird_y = 330; // 对于新目标 425 来说，330 太高了，非常安全，所以绝对不跳
        #200;
        bird_y = 430; // 跌破新阈值 425，触发跳跃
        #200;

        // --- 场景 4：极限防卫测试 (天花板与地板) ---
        bird_y = 650; // 极度贴近地面 (668-50=618)，触发紧急跳跃
        #200;
        bird_y = 10;  // 极度贴近天花板 (<20)，即使跌破了当前目标阈值，也强制不跳
        #200;

        $display("Simulation Finished!");
        $stop;
    end
endmodule