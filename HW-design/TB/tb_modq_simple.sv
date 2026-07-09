`timescale 1ns / 1ps

module tb_modq_simple;

    // Parameters
    localparam int Q = 3329;
    localparam int NUM_TESTS = 30;

    // Signals
    logic               clk;
    logic               rst_n;
    logic               valid_in;
    logic signed [15:0] C;
    logic        [11:0] P;
    logic               valid_out;

    // DUT
    modq dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .C        (C),
        .P        (P),
        .valid_out(valid_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Expected logic
    function int expected_modq(int val);
        int res;
        res = val;
        if (res < 0) res = res + Q;
        if (res >= Q) res = res - Q;
        return res;
    endfunction

    // Test sequence
    initial begin
        int test_vals [] = '{0, 1, 3328, -1, -3328, 3329, 6656, 1500, -1500, 2000, -2000, 3000, -3000, 4000, 5000, 6000, -10, 10, -500, 500, 100, -100, 200, -200, 800, -800, 1200, -1200, 2500, -2500};
        int expected;
        int pass_count = 0;

        $display("==================================================");
        $display("   modq.sv - Simple Screen Test");
        $display("==================================================");

        rst_n = 0;
        valid_in = 0;
        C = 0;
        #20 rst_n = 1;

        for (int i = 0; i < test_vals.size(); i++) begin
            @(posedge clk);
            C = test_vals[i];
            valid_in = 1;
            expected = expected_modq(test_vals[i]);

            @(posedge clk);
            valid_in = 0;
            
            // modq has 1 cycle latency
            @(posedge clk);
            if (P == expected) begin
                $display("[PASS] Test %02d: modq(%5d) = %4d", i+1, test_vals[i], P);
                pass_count++;
            end else begin
                $display("[FAIL] Test %02d: modq(%5d) = %4d (Expected: %4d)", i+1, test_vals[i], P, expected);
            end
        end

        $display("==================================================");
        $display(" Total Passed: %0d / %0d", pass_count, test_vals.size());
        $display("==================================================");
        $finish;
    end

endmodule
