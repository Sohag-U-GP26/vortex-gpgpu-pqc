`timescale 1ns / 1ps

module tb_basemul_simple;

    // Parameters
    localparam int Q = 3329;

    // Signals
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [11:0] A0, A1;
    logic [11:0] B0, B1;
    logic [11:0] zeta;
    logic [11:0] C0, C1;
    logic        valid_out;

    // DUT
    basemul_kyber_v2 dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .A0       (A0),
        .A1       (A1),
        .B0       (B0),
        .B1       (B1),
        .zeta     (zeta),
        .C0       (C0),
        .C1       (C1),
        .valid_out(valid_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Inline expected logic instead of function to avoid simulator bugs

    // Test sequence
    initial begin
        int test_A0 [] = '{0, 100, 500, 1000, 2000, 3000, 3328, 1234, 432,  999,  111, 222, 333, 444, 555, 666, 777, 888, 999, 1000, 2000, 3000, 10, 20, 30, 40, 50, 60, 70, 80};
        int test_A1 [] = '{0, 200, 600, 1500, 2500, 3100, 3328, 432,  1234, 111,  999, 888, 777, 666, 555, 444, 333, 222, 111, 3000, 2000, 1000, 80, 70, 60, 50, 40, 30, 20, 10};
        int test_B0 [] = '{1, 10,  20,  30,   40,   50,   60,   70,   80,   90,   100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000};
        int test_B1 [] = '{2, 20,  40,  60,   80,   100,  120,  140,  160,  180,  200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800, 3000, 3200, 3300, 10, 20, 30};
        int test_zeta[] = '{17, 17, 17, 289, 289, 4913%Q, 4913%Q, 1000, 2000, 3000, 3328, 1664, 1234, 4321%Q, 999, 888, 777, 666, 555, 444, 333, 222, 111, 3000, 2000, 1000, 500, 250, 125, 62};
        
        int exp_C0, exp_C1, term1, term2;
        int pass_count = 0;

        $display("==================================================");
        $display("   basemul_kyber_v2.sv - Simple Screen Test");
        $display("==================================================");

        rst_n = 0;
        valid_in = 0;
        A0 = 0; A1 = 0; B0 = 0; B1 = 0; zeta = 0;
        #20 rst_n = 1;

        for (int i = 0; i < test_A0.size(); i++) begin
            @(posedge clk);
            A0 = test_A0[i]; A1 = test_A1[i];
            B0 = test_B0[i]; B1 = test_B1[i];
            zeta = test_zeta[i];
            valid_in = 1;
            
            term1 = (test_A1[i] * test_B1[i]) % Q;
            term2 = (term1 * test_zeta[i]) % Q;
            term1 = (test_A1[i] * test_B1[i]) % Q;
            term2 = (term1 * test_zeta[i]) % Q;
            
            exp_C0 = ((test_A0[i] * test_B0[i]) + term2) % Q;
            if (exp_C0 < 0) exp_C0 += Q;
            
            exp_C1 = ((test_A0[i] * test_B1[i]) + (test_A1[i] * test_B0[i])) % Q;
            if (exp_C1 < 0) exp_C1 += Q;

            @(posedge clk);
            valid_in = 0;
            
            // basemul_kyber_v2 has 3 cycles latency
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            
            if (C0 == exp_C0 && C1 == exp_C1) begin
                $display("[PASS] Test %02d: BaseMul(A0:%4d A1:%4d, B0:%4d B1:%4d, z:%4d) -> C0:%4d C1:%4d", i+1, test_A0[i], test_A1[i], test_B0[i], test_B1[i], test_zeta[i], C0, C1);
                pass_count++;
            end else begin
                $display("[FAIL] Test %02d: BaseMul -> C0:%4d (Exp:%4d), C1:%4d (Exp:%4d)", i+1, C0, exp_C0, C1, exp_C1);
            end
        end

        $display("==================================================");
        $display(" Total Passed: %0d / %0d", pass_count, test_A0.size());
        $display("==================================================");
        $finish;
    end

endmodule
