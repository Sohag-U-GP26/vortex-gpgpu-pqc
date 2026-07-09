`timescale 1ns / 1ps

module tb_gs_butterfly_simple;

    // Parameters
    localparam int Q = 3329;

    // Signals
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [11:0] A;
    logic [11:0] B;
    logic [11:0] W;
    logic [11:0] A_out;
    logic [11:0] B_out;
    logic        valid_out;

    // DUT
    gs_butterfly dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .A        (A),
        .B        (B),
        .W        (W),
        .A_out    (A_out),
        .B_out    (B_out),
        .valid_out(valid_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Inline expected logic instead of function to avoid simulator bugs

    // Test sequence
    initial begin
        int test_A [] = '{0, 100, 500, 1000, 2000, 3000, 3328, 1234, 432,  999,  111, 222, 333, 444, 555, 666, 777, 888, 999, 1000, 2000, 3000, 10, 20, 30, 40, 50, 60, 70, 80};
        int test_B [] = '{0, 200, 600, 1500, 2500, 3100, 3328, 432,  1234, 111,  999, 888, 777, 666, 555, 444, 333, 222, 111, 3000, 2000, 1000, 80, 70, 60, 50, 40, 30, 20, 10};
        int test_W [] = '{1, 17,  289, 4913%Q, 500, 1000, 3328, 1664, 2000, 1500, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000};
        
        int exp_A_out, exp_B_out, diff;
        int pass_count = 0;

        $display("==================================================");
        $display("   gs_butterfly.sv - Simple Screen Test");
        $display("==================================================");

        rst_n = 0;
        valid_in = 0;
        A = 0;
        B = 0;
        W = 0;
        #20 rst_n = 1;

        for (int i = 0; i < test_A.size(); i++) begin
            @(posedge clk);
            A = test_A[i];
            B = test_B[i];
            W = test_W[i];
            valid_in = 1;
            
            exp_A_out = (test_A[i] + test_B[i]) % Q;
            if (exp_A_out < 0) exp_A_out += Q;
            
            diff = (test_A[i] - test_B[i]) % Q;
            if (diff < 0) diff += Q;
            
            exp_B_out = (diff * test_W[i]) % Q;
            if (exp_B_out < 0) exp_B_out += Q;

            @(posedge clk);
            valid_in = 0;
            
            // gs_butterfly has 3 cycles latency now
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            
            if (A_out == exp_A_out && B_out == exp_B_out) begin
                $display("[PASS] Test %02d: GS(A=%4d, B=%4d, W=%4d) -> A'=%4d, B'=%4d", i+1, test_A[i], test_B[i], test_W[i], A_out, B_out);
                pass_count++;
            end else begin
                $display("[FAIL] Test %02d: GS(A=%4d, B=%4d, W=%4d) -> A'=%4d (Exp:%4d), B'=%4d (Exp:%4d)", i+1, test_A[i], test_B[i], test_W[i], A_out, exp_A_out, B_out, exp_B_out);
            end
        end

        $display("==================================================");
        $display(" Total Passed: %0d / %0d", pass_count, test_A.size());
        $display("==================================================");
        $finish;
    end

endmodule
