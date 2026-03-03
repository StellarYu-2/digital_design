`timescale 1ns / 1ps

module pipe_gen_tb();

    // ---------------------------------------------------------
    // 信号定义
    // ---------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         game_active;
    reg         frame_en;
    reg  [15:0] random_seed;

    wire [11:0] pipe1_x;
    wire [11:0] pipe1_gap_y;
    wire [11:0] pipe2_x;
    wire [11:0] pipe2_gap_y;
    wire        score_pulse;

    // 例化待测设计 (DUT)
    pipe_gen u_pipe_gen (
        .clk         (clk),
        .rst_n       (rst_n),
        .game_active (game_active),
        .frame_en    (frame_en),
        .random_seed (random_seed),
        .pipe1_x     (pipe1_x),
        .pipe1_gap_y (pipe1_gap_y),
        .pipe2_x     (pipe2_x),
        .pipe2_gap_y (pipe2_gap_y),
        .score_pulse (score_pulse)
    );

    // 时钟生成：约 65MHz (周期 15.38ns)
    initial clk = 0;
    always #7.69 clk = ~clk;

    // ---------------------------------------------------------
    // 帧同步信号 (仿真极限加速版)
    // ---------------------------------------------------------
    initial begin
        frame_en = 0;
        forever begin
            #184.62;       // 等待约 200ns 生成一帧 (极度压缩时间轴)
            frame_en = 1;
            #15.38;        // 维持一个时钟周期
            frame_en = 0;
        end
    end

    // ---------------------------------------------------------
    // 激励产生
    // ---------------------------------------------------------
    initial begin
        rst_n       = 0;
        game_active = 0;
        random_seed = 16'hABCD; 

        #100;
        rst_n = 1;
        #100;
        game_active = 1;

        // 仅仅运行 25us (相当于跑了 125 帧)
        // 足够看到 pipe1 移出屏幕重置，以及 pipe2 跨过 220 得分线
        #25_000;

        game_active = 0;
        #1_000; 

        $display("Simulation Finished!");
        $stop;
    end
endmodule