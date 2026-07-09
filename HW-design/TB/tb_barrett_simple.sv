`timescale 1ns / 1ps

module tb_barrett_simple;

    // Parameters
    localparam int Q = 3329;

    // Signals
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [23:0] C;
    logic [11:0] P;
    logic        valid_out;

    // DUT
    barrett_reduction_kyber dut (
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

    // Test sequence
    initial begin
        int test_vals [] = '{0, 1, 3328, 3329, 6658, 10000, 50000, 100000, 500000, 1000000, 2000000, 3000000, 5000000, 8000000, 11082240, 12345, 67890, 13579, 24680, 98765, 54321, 111111, 222222, 333333, 444444, 555555, 666666, 777777, 888888, 999999};
        int expected;
        int pass_count = 0;

        $display("==================================================");
        $display("   barrett_reduction_kyber.sv - Simple Screen Test");
        $display("==================================================");

        rst_n = 0;
        valid_in = 0;
        C = 0;
        #20 rst_n = 1;

        for (int i = 0; i < test_vals.size(); i++) begin
            @(posedge clk);
            C = test_vals[i];
            valid_in = 1;
            expected = test_vals[i] % Q;

            @(posedge clk);
            valid_in = 0;
            
            // Barrett has 1 cycle latency
            @(posedge clk);
            if (P == expected) begin
                $display("[PASS] Test %02d: barrett(%8d) = %4d", i+1, test_vals[i], P);
                pass_count++;
            end else begin
                $display("[FAIL] Test %02d: barrett(%8d) = %4d (Expected: %4d)", i+1, test_vals[i], P, expected);
            end
        end

        $display("==================================================");
        $display(" Total Passed: %0d / %0d", pass_count, test_vals.size());
        $display("==================================================");
        $finish;
    end

endmodule
