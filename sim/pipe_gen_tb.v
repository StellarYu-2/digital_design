`timescale 1ns / 1ps

module pipe_gen_tb;

    // Inputs
    reg         clk;
    reg         rst_n;
    reg         game_active;
    reg         frame_en;
    reg  [15:0] random_seed;

    // Outputs
    wire [11:0] pipe1_x;
    wire [11:0] pipe1_gap_y;
    wire [11:0] pipe2_x;
    wire [11:0] pipe2_gap_y;
    wire        score_pulse;

    // Clock period (50MHz -> 20ns)
    parameter CLK_PERIOD = 20;
    
    // Frame counter
    reg [31:0] frame_cnt;

    // Instantiate the Unit Under Test (UUT)
    pipe_gen uut (
        .clk(clk),
        .rst_n(rst_n),
        .game_active(game_active),
        .frame_en(frame_en),
        .random_seed(random_seed),
        .pipe1_x(pipe1_x),
        .pipe1_gap_y(pipe1_gap_y),
        .pipe2_x(pipe2_x),
        .pipe2_gap_y(pipe2_gap_y),
        .score_pulse(score_pulse)
    );

    // Clock generation (50MHz)
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Frame Enable generation (every 1000 clocks for fast simulation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_cnt <= 0;
            frame_en <= 0;
        end else begin
            frame_cnt <= frame_cnt + 1;
            if (frame_cnt >= 1000) begin
                frame_en <= 1;
                frame_cnt <= 0;
            end else begin
                frame_en <= 0;
            end
        end
    end

    // Stimulus
    initial begin
        // Initialize
        rst_n = 0;
        game_active = 0;
        random_seed = 16'h1234;

        // Wait 100ns for reset
        #100;
        rst_n = 1;

        // Start game
        #1000;
        game_active = 1;

        // Run simulation for 3ms - enough to see pipes move, score, and speed changes
        #3000000;

        // End simulation
        $display("Simulation Finished at time %t", $time);
        $finish;
    end

    // Monitor score pulse
    always @(posedge clk) begin
        if (score_pulse)
            $display("Score pulse at time %t", $time);
    end

endmodule
