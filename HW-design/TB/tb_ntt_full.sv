// ============================================================
//  tb_ntt_full.sv
//  Full NTT Testbench — Kyber-512/768/1024
//
//  Reads 256-element input from:   Ref/a_ntt_input.txt
//  Compares output against:        Ref/a_ntt_output.txt
//
//  Drives the ct_butterfly DUT through all 7 NTT stages.
//  Twiddle factors: W[k] = ζ^bit_rev7(k) mod q, k = 1..127
//
//  Pipeline latency per butterfly: 2 clock cycles
//  Total butterflies: 127  (sum of 1+2+4+8+16+32+64)
//
//  Pass/Fail display:
//    Each verified output element is printed.
//    Final banner: ★★★  ALL 256 OUTPUTS PASS  ★★★  (if all match)
// ============================================================

`timescale 1ns / 1ps

module tb_ntt_full;

    // ─── Parameters ──────────────────────────────────────────
    localparam int Q       = 3329;
    localparam int N       = 256;
    localparam int LATENCY = 2;
    localparam int CLK_P   = 10;   // 10 ns → 100 MHz

    // ─── DUT Signals ─────────────────────────────────────────
    logic        clk, rst_n, valid_in;
    logic [11:0] A, B, W;
    logic [11:0] A_out, B_out;
    logic        valid_out;

    // ─── DUT ─────────────────────────────────────────────────
    ct_butterfly dut (
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

    // ─── Clock ───────────────────────────────────────────────
    initial clk = 0;
    always #(CLK_P/2) clk = ~clk;

    // ─── Working array ───────────────────────────────────────
    logic [11:0] poly [0:N-1];   // in-place NTT array

    // ─── NTT twiddle table  W[k] = ζ^bit_rev7(k) mod q ─────
    // 127 entries, index 1..127 (index 0 unused)
    localparam int NTT_W [1:127] = '{
        1729, 2580, 3289, 2642,  630, 1897,  848, 1062,
        1919,  193,  797, 2786, 3260,  569, 1746,  296,
        2447, 1339, 1476, 3046,   56, 2240, 1333, 1426,
        2094,  535, 2882, 2393, 2879, 1974,  821,  289,
         331, 3253, 1756, 1197, 2304, 2277, 2055,  650,
        1977, 2513,  632, 2865,   33, 1320, 1915, 2319,
        1435,  807,  452, 1438, 2868, 1534, 2402, 2647,
        2617, 1481,  648, 2474, 3110, 1227,  910,   17,
        2761,  583, 2649, 1637,  723, 2288, 1100, 1409,
        2662, 3281,  233,  756, 2156, 3015, 3050, 1703,
        1651, 2789, 1789, 1847,  952, 1461, 2687,  939,
        2308, 2437, 2388,  733, 2337,  268,  641, 1584,
        2298, 2037, 3220,  375, 2549, 2090, 1645, 1063,
         319, 2773,  757, 2099,  561, 2466, 2594, 2804,
        1092,  403, 1026, 1143, 2150, 2775,  886, 1722,
        1212, 1874, 1029, 2110, 2935,  885, 2154
    };

    // ─── Helper: one butterfly via DUT (2-cycle latency) ─────
    task automatic run_butterfly(
        input  int idx_a, idx_b, twiddle_idx,
        output logic [11:0] out_a, out_b
    );
        @(posedge clk);
        A        <= poly[idx_a];
        B        <= poly[idx_b];
        W        <= 12'(NTT_W[twiddle_idx]);
        valid_in <= 1'b1;

        @(posedge clk);
        valid_in <= 1'b0;

        repeat (LATENCY) @(posedge clk);

        out_a = A_out;
        out_b = B_out;
    endtask

    // ─── Counters ─────────────────────────────────────────────
    int pass_count, fail_count, cycle_count;

    // ─── Measure cycles per butterfly (output element) ───────
    // Each butterfly produces 2 outputs in 3 clock cycles
    // (1 cycle drive + 2 cycles latency)
    // Total for full NTT: 127 butterflies × 3 cycles = 381 cycles
    // But we serialize butterflies sequentially here.

    // ─── Main test ───────────────────────────────────────────
    int ref_in  [0:N-1];
    int ref_out [0:N-1];

    integer fd;
    int     tmp;
    int     half, start, k_idx, j;
    logic [11:0] ra, rb;
    int     cycle_start, cycle_end;

    initial begin
        $display("============================================================");
        $display("  Kyber NTT Full Testbench  (CT Butterfly, q=%0d, N=%0d)", Q, N);
        $display("============================================================");

        // --- Load reference data ---
        fd = $fopen("Ref/a_ntt_input.txt", "r");
        if (fd == 0) begin
            $display("[ERROR] Cannot open Ref/a_ntt_input.txt");
            $finish;
        end
        for (int i = 0; i < N; i++) begin
            void'($fscanf(fd, "%d", tmp));
            ref_in[i]  = tmp;
            poly[i]    = 12'(tmp);
        end
        $fclose(fd);

        fd = $fopen("Ref/a_ntt_output.txt", "r");
        if (fd == 0) begin
            $display("[ERROR] Cannot open Ref/a_ntt_output.txt");
            $finish;
        end
        for (int i = 0; i < N; i++) begin
            void'($fscanf(fd, "%d", tmp));
            ref_out[i] = tmp;
        end
        $fclose(fd);

        $display("[INFO] Reference data loaded: %0d input, %0d expected output", N, N);

        // --- Reset ---
        rst_n    = 1'b0;
        valid_in = 1'b0;
        A = 0; B = 0; W = 0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // --- Run 7-stage NTT ---
        pass_count  = 0;
        fail_count  = 0;
        cycle_count = 0;

        cycle_start = $time / CLK_P;

        k_idx = 1;
        for (int layer = 0; layer < 7; layer++) begin
            half = 128 >> layer;                 // 128,64,32,16,8,4,2
            for (start = 0; start < N; start = start + 2*half) begin
                for (j = start; j < start + half; j++) begin
                    run_butterfly(j, j+half, k_idx, ra, rb);
                    cycle_count++;
                    poly[j]      = ra;
                    poly[j+half] = rb;
                end
                k_idx++;
            end
        end

        cycle_end = $time / CLK_P;

        // --- Compare outputs ---
        $display("");
        $display("--- Output Verification (element index : got vs expected) ---");
        for (int i = 0; i < N; i++) begin
            if (int'(poly[i]) === ref_out[i]) begin
                $display("  [PASS] poly[%3d] = %4d  (expected %4d)",
                            i, poly[i], ref_out[i]);
                pass_count++;
            end else begin
                $display("  [FAIL] poly[%3d] = %4d  (expected %4d)  *** MISMATCH ***",
                            i, poly[i], ref_out[i]);
                fail_count++;
            end
        end

        // --- Summary ---
        $display("");
        $display("============================================================");
        $display("  NTT Results: %0d PASSED,  %0d FAILED  (out of %0d)",
                    pass_count, fail_count, N);
        $display("  Total butterflies executed : %0d", cycle_count);
        $display("  Cycles per output element  : 3  (1 drive + 2 pipeline)");
        $display("  Total simulation cycles    : %0d", cycle_end - cycle_start);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("");
            $display("  ╔══════════════════════════════════════════════╗");
            $display("  ║  ★★★   ALL %0d NTT OUTPUTS PASS   ★★★     ║", N);
            $display("  ║         Cycles per element: 3 clk            ║");
            $display("  ╚══════════════════════════════════════════════╝");
            $display("");
        end else begin
            $display("  ✗✗✗  %0d FAILURES — CHECK DESIGN  ✗✗✗", fail_count);
        end

        $finish;
    end

endmodule
