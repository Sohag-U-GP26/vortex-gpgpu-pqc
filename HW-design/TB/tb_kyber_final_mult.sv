// ============================================================
//  tb_kyber_final_mult.sv
//  Testbench for kyber_final_mult
//
//  Data used:
//    Inputs    -> intt_output.txt   (256 coefficients, INTT output)
//    Expected  -> final_output.txt  (256 coefficients, (in x 3303) mod 3329)
//
//  Verification Methodology:
//    - One element is fed per clock cycle
//    - Output is read after one cycle (pipeline latency)
//    - Each result is displayed with PASS/FAIL judgment
//    - An ALL PASS message is highlighted when all elements succeed
//
//  Pipeline Timing (1-stage):
//    posedge T   : data_in[i]  -> valid_in=1  -> Barrett FF computed
//    posedge T+1 : data_out[i] ready (valid_out=1) -> read and compared
//
//  Cycles:
//    Input cycles  : N = 256
//    Flush cycle   : 1  (last element needs an extra cycle)
//    Total         : 257 cycles
// ============================================================

`timescale 1ns/1ps

module tb_kyber_final_mult;

    // ----------------------------------------------------------
    // Constants
    // ----------------------------------------------------------
    localparam int CLK_HALF = 5;    // Half cycle = 5 ns  ->  10 ns period
    localparam int N        = 256;  // Number of polynomial coefficients in Kyber

    // ----------------------------------------------------------
    // DUT Signals
    // ----------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [11:0] data_in;
    logic [11:0] data_out;
    logic        valid_out;

    // ----------------------------------------------------------
    // Test data memory
    // ----------------------------------------------------------
    logic [11:0] intt_mem  [0:N-1];   // from intt_output.txt
    logic [11:0] expect_mem[0:N-1];   // from final_output.txt

    // ----------------------------------------------------------
    // Result counters (shared between initial blocks)
    // ----------------------------------------------------------
    int pass_cnt  = 0;
    int fail_cnt  = 0;
    int out_idx   = 0;   // Current output index in checker
    int cycle_cnt = 0;   // Total cycles

    // ----------------------------------------------------------
    // Clock generation
    // ----------------------------------------------------------
    initial clk = 1'b0;
    always  #CLK_HALF clk = ~clk;

    // ----------------------------------------------------------
    // DUT Instantiation
    // ----------------------------------------------------------
    kyber_final_mult dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .data_in  (data_in),
        .data_out (data_out),
        .valid_out(valid_out)
    );

    // ----------------------------------------------------------
    // Load test data from files
    // ----------------------------------------------------------
    initial begin : load_files
        int fd, stat;
        integer val;

        // --- intt_output.txt ---------------------------------------
        fd = $fopen("intt_output.txt", "r");
        if (fd == 0) begin
            $display("[TB-ERROR] Cannot open intt_output.txt");
            $fatal(1);
        end
        for (int k = 0; k < N; k++) begin
            stat = $fscanf(fd, "%d", val);
            intt_mem[k] = val[11:0];
        end
        $fclose(fd);

        // --- final_output.txt --------------------------------------
        fd = $fopen("final_output.txt", "r");
        if (fd == 0) begin
            $display("[TB-ERROR] Cannot open final_output.txt");
            $fatal(1);
        end
        for (int k = 0; k < N; k++) begin
            stat = $fscanf(fd, "%d", val);
            expect_mem[k] = val[11:0];
        end
        $fclose(fd);
    end : load_files

    // ----------------------------------------------------------
    // Output checker — runs independently at each clock posedge
    //
    //  Correct Timing:
    //    At posedge T, the always block reads the output registered by FF at posedge T-1
    //    (i.e., NBA from the previous cycle is visible here)
    //    So at posedge T+1 we see the output of data_in[T-1] <- correct
    // ----------------------------------------------------------
    always @(posedge clk) begin : output_checker
        if (valid_out && (out_idx < N)) begin
            if (data_out === expect_mem[out_idx]) begin
                $display("  [PASS] idx=%3d | in=%4d | got=%4d | exp=%4d | ✔ | cycle=%0d",
                            out_idx,
                            intt_mem[out_idx],
                            data_out,
                            expect_mem[out_idx],
                            $time/10 );   // Cycle number = nano time / 10ns
                pass_cnt++;
            end else begin
                $display("  [FAIL] idx=%3d | in=%4d | got=%4d | exp=%4d | ✘ | cycle=%0d  <<<",
                            out_idx,
                            intt_mem[out_idx],
                            data_out,
                            expect_mem[out_idx],
                            $time/10 );
                fail_cnt++;
            end
            out_idx++;
        end
    end : output_checker

    // ----------------------------------------------------------
    // Main Stimulus
    // ----------------------------------------------------------
    initial begin : stim

        // -- Initialize signals ---------------------------------
        rst_n    = 1'b0;
        valid_in = 1'b0;
        data_in  = 12'h000;

        // -- Apply reset (4 cycles) -----------------------------
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1'b1;

        // -- Report Header --------------------------------------
        @(posedge clk);
        $display("");
        $display("  ================================================================");
        $display("  Kyber Final Multiply — Testbench");
        $display("  EQU : out = (in * 3303) mod 3329");
        $display("  Multiply  : 3303 = (1<<12)-(1<<9)-(1<<8)-(1<<4)-(1<<3)-1");
        $display("              (shift / add / sub)");
        $display("  mod q     : Barrett Reduction  (q=3329, R=2^12, μ=5039)");
        $display("  Latency   : 1 clock cycle per element");
        $display("  Inputs  : intt_output.txt   (%0d Elements)", N);
        $display("  Expected   : final_output.txt  (%0d Elements)", N);
        $display("  ================================================================");
        $display("  idx  |  Input | Got  | Expected | Status | Cycle");
        $display("  -----|--------|------|----------|--------|------");

        // -- Feed N inputs, one per cycle -----------------------
        for (int i = 0; i < N; i++) begin
            @(negedge clk);          // Setup data before posedge
            data_in  = intt_mem[i];
            valid_in = 1'b1;
            @(posedge clk);          // Clock edge
            cycle_cnt++;
        end

        // -- Deassert valid_in and pipeline flush cycle ---------
        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk);              // Last element appears here
        cycle_cnt++;

        // -- Wait for checker counters to update ----------------
        repeat(4) @(posedge clk);

        // -- Results Summary ------------------------------------
        $display("");
        $display("  ================================================================");
        $display("  Summary of Results");
        $display("  ================================================================");
        $display("  Total Elements   : %0d", N);
        $display("  PASS              : %0d", pass_cnt);
        $display("  FAIL              : %0d", fail_cnt);
        $display("  Cycles/Element        : 1 Clock Cycle  (Single-Stage Pipeline)");
        $display("  Total Cycles    : %0d  (= N + 1 Filter Cycle)", cycle_cnt);
        $display("  ================================================================");

        // -- Final Result Message -------------------------------
        if (fail_cnt == 0 && pass_cnt == N) begin
            $display("");
            $display("  ==========================================================================");
            $display("          ✔  ALL %0d / %0d ELEMENTS PASS  ✔              ",
                        pass_cnt, N);
            $display("                                                          ");
            $display("          Clock Cycles per Element : 1 clock cycle           ");
            $display("          Total Cycles  : %0d Clock Cycles                 ",
                        cycle_cnt);
            $display("                                                          ");
            $display("  ==========================================================================");
            $display("");
        end else begin
            $display("");
            $display("  =======================================================");
            $display("      !!  SOME TESTS FAILED                         ");
            $display("      FAIL = %0d / %0d                              ",
                        fail_cnt, N);
            $display("  =======================================================");
            $display("");
        end

        $finish;
    end : stim

endmodule
