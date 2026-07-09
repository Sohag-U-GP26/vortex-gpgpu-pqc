`timescale 1ns / 1ps

module tb_kyber_final_mult_simple;

    // Parameters
    localparam int Q = 3329;
    localparam int N_INV = 3303; // 128^-1 mod 3329

    // Signals
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [11:0] data_in;
    logic [11:0] data_out;
    logic        valid_out;

    // DUT
    kyber_final_mult dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .data_in  (data_in),
        .data_out (data_out),
        .valid_out(valid_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        int test_vals [] = '{0, 1, 2, 3328, 1664, 100, 200, 500, 1000, 2000, 3000, 128, 256, 512, 1024, 2048, 1234, 2345, 3111, 42, 777, 888, 999, 1111, 2222, 1337, 3133, 14, 15, 16};
        int expected;
        int pass_count = 0;

        $display("==================================================");
        $display("   kyber_final_mult.sv - Simple Screen Test");
        $display("==================================================");

        rst_n = 0;
        valid_in = 0;
        data_in = 0;
        #20 rst_n = 1;

        for (int i = 0; i < test_vals.size(); i++) begin
            @(posedge clk);
            data_in = test_vals[i];
            valid_in = 1;
            expected = (test_vals[i] * N_INV) % Q;

            @(posedge clk);
            valid_in = 0;
            
            // kyber_final_mult has 1 cycle latency
            @(posedge clk);
            if (data_out == expected) begin
                $display("[PASS] Test %02d: final_mult(%4d) = %4d", i+1, test_vals[i], data_out);
                pass_count++;
            end else begin
                $display("[FAIL] Test %02d: final_mult(%4d) = %4d (Expected: %4d)", i+1, test_vals[i], data_out, expected);
            end
        end

        $display("==================================================");
        $display(" Total Passed: %0d / %0d", pass_count, test_vals.size());
        $display("==================================================");
        $finish;
    end

endmodule
