// ============================================================
//  tb_intt_full.sv
//  Full INTT Testbench — Kyber-512/768/1024
//
//  Reads 256-element input from:   ../Ref/basemul_output.txt
//  Compares output against:        ../Ref/intt_output.txt
//
//  Drives the gs_butterfly DUT through all 7 INTT stages.
//  INTT processes NTT layers in REVERSE order (Layer 6 → 0).
//  Twiddle factors: INTT_W[k] = (NTT_W[ntt_k])^(-1) mod q
//
//  Pipeline latency per butterfly: 2 clock cycles
//  Total butterflies: 127  (sum of 64+32+16+8+4+2+1)
//
//  NOTE: This testbench now includes the final n^-1 scaling
//        using the kyber_final_mult module, complying with FIPS-203.
//        It verifies the output against ../Ref/final_output.txt.
//
//  Pass/Fail display:
//    Each verified output element is printed.
//    Final banner: ★★★  ALL 256 OUTPUTS PASS  ★★★  (if all match)
// ============================================================

`timescale 1ns / 1ps

module tb_intt_full;

    // ─── Parameters ──────────────────────────────────────────
    localparam int Q       = 3329;
    localparam int N       = 256;
    localparam int LATENCY = 3;   // gs_butterfly: modq(1) + A_out_reg(1) + A_out_reg2(1)
    localparam int CLK_P   = 10;   // 10 ns → 100 MHz

    // ─── DUT Signals ─────────────────────────────────────────
    logic        clk, rst_n, valid_in;
    logic [11:0] A, B, W;
    logic [11:0] A_out, B_out;
    logic        valid_out;

    // ─── DUT ─────────────────────────────────────────────────
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

    // ─── Final Mult DUT ──────────────────────────────────────
    logic [11:0] fm_in, fm_out;
    logic        fm_valid_in, fm_valid_out;

    kyber_final_mult dut_fm (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (fm_valid_in),
        .data_in  (fm_in),
        .data_out (fm_out),
        .valid_out(fm_valid_out)
    );

    // ─── Clock ───────────────────────────────────────────────
    initial clk = 0;
    always #(CLK_P/2) clk = ~clk;

    // ─── Working array ───────────────────────────────────────
    logic [11:0] poly [0:N-1];

    // ─── INTT twiddle table ──────────────────────────────────
    // INTT_W[k] = modinv(NTT_W[ntt_k]) mod q
    // 127 entries in INTT traversal order (Layer 6 first → Layer 0 last)
    // Index 0..126
    localparam int INTT_W [0:126] = '{
        1175,  2444,   394,  1219,  2300,  1455,  2117,  1607,
        2443,   554,  1179,  2186,  2303,  2926,  2237,   525,
         735,   863,  2768,  1230,  2572,   556,  3010,  2266,
        1684,  1239,   780,  2954,   109,  1292,  1031,  1745,
        2688,  3061,   992,  2596,   941,   892,  1021,  2390,
         642,  1868,  2377,  1482,  1540,   540,  1678,  1626,
         279,   314,  1173,  2573,  3096,    48,   667,  1920,
        2229,  1041,  2606,  1692,   680,  2746,   568,  3312,
        2419,  2102,   219,   855,  2681,  1848,   712,   682,
         927,  1795,   461,  1891,  2877,  2522,  1894,  1010,
        1414,  2009,  3296,   464,  2697,   816,  1352,  2679,
        1274,  1052,  1025,  2132,  1573,    76,  2998,  3040,
        2508,  1355,   450,   936,   447,  2794,  1235,  1903,
        1996,  1089,  3273,   283,  1853,  1990,   882,  3033,
        1583,  2760,    69,   543,  2532,  3136,  1410,  2267,
        2481,  1432,  2699,   687,    40,   749,  1600
    };

    // ─── Helper: one butterfly via DUT ───────────────────────
    task automatic run_butterfly(
        input  int idx_a, idx_b, tw_idx,
        output logic [11:0] out_a, out_b
    );
        @(posedge clk);
        A        <= poly[idx_a];
        B        <= poly[idx_b];
        W        <= 12'(INTT_W[tw_idx]);
        valid_in <= 1'b1;

        @(posedge clk);
        valid_in <= 1'b0;

        repeat (LATENCY) @(posedge clk);

        out_a = A_out;
        out_b = B_out;
    endtask

    // ─── Helper: one final mult via DUT ──────────────────────
    task automatic run_final_mult(
        input  int idx,
        output logic [11:0] out_val
    );
        @(posedge clk);
        fm_in       <= poly[idx];
        fm_valid_in <= 1'b1;

        @(posedge clk);
        fm_valid_in <= 1'b0;

        @(posedge clk); // Latency is 1 cycle for final_mult
        out_val = fm_out;
    endtask

    // ─── Counters ─────────────────────────────────────────────
    int pass_count, fail_count, cycle_count;

    // ─── Main test ───────────────────────────────────────────
    int ref_in  [0:N-1];
    int ref_out [0:N-1];

    integer fd;
    int     tmp;
    int     half, start, tw_idx, j;
    logic [11:0] ra, rb;
    int     cycle_start, cycle_end;

    initial begin
        $display("============================================================");
        $display("  Kyber INTT Full Testbench  (GS Butterfly, q=%0d, N=%0d)", Q, N);
        $display("============================================================");

        // --- Load reference data ---
        fd = $fopen("../Ref/basemul_output.txt", "r");
        if (fd == 0) begin
            $display("[ERROR] Cannot open ../Ref/basemul_output.txt");
            $finish;
        end
        for (int i = 0; i < N; i++) begin
            void'($fscanf(fd, "%d", tmp));
            ref_in[i] = tmp;
            poly[i]   = 12'(tmp);
        end
        $fclose(fd);

        fd = $fopen("../Ref/final_output.txt", "r");
        if (fd == 0) begin
            $display("[ERROR] Cannot open ../Ref/final_output.txt");
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

        // --- Run 7-stage INTT (NTT layers in reverse: 6,5,4,3,2,1,0) ---
        pass_count  = 0;
        fail_count  = 0;
        cycle_count = 0;
        tw_idx      = 0;   // index into INTT_W[]

        cycle_start = $time / CLK_P;

        for (int layer = 6; layer >= 0; layer--) begin
            half = 128 >> layer;                 // layer6→half=2, layer0→half=128
            for (start = 0; start < N; start = start + 2*half) begin
                for (j = start; j < start + half; j++) begin
                    run_butterfly(j, j+half, tw_idx, ra, rb);
                    cycle_count++;
                    poly[j]      = ra;
                    poly[j+half] = rb;
                end
                tw_idx++;
            end
        end

        // --- Run Final Mult (n^-1 scaling, FIPS-203) ---
        for (int i = 0; i < N; i++) begin
            run_final_mult(i, ra);
            poly[i] = ra;
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
        $display("  INTT Results: %0d PASSED,  %0d FAILED  (out of %0d)",
                    pass_count, fail_count, N);
        $display("  Total butterflies executed : %0d", cycle_count);
        $display("  Cycles per output element  : 3  (1 drive + 2 pipeline)");
        $display("  Total simulation cycles    : %0d", cycle_end - cycle_start);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("");
            $display("  ╔══════════════════════════════════════════════╗");
            $display("  ║  ★★★   ALL %0d INTT OUTPUTS PASS  ★★★     ║", N);
            $display("  ║         Cycles per element: 3 clk            ║");
            $display("  ╚══════════════════════════════════════════════╝");
            $display("");
        end else begin
            $display("  ✗✗✗  %0d FAILURES — CHECK DESIGN  ✗✗✗", fail_count);
        end

        $finish;
    end

endmodule
