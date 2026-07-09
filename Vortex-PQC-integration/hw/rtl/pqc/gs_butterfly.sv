// ============================================================
//  gs_butterfly.sv
//  Gentleman-Sande (GS) Butterfly for Kyber Inverse NTT
//
//  Diagram:
//    A ──────╲──── (A+B) mod q ──[modq]──────────────── A'
//             ╲╱
//    B ──────╱──── (A-B) mod q ──[modq]──⊗[Barrett]──── B'
//                                          ↑
//                                       twiddle W
//
//  Operation:
//    A'  = modq(A + B)
//    tmp = modq(A − B)
//    B'  = Barrett_reduce(tmp × W)
//
//  Parameters (Kyber-512/768/1024):
//    q = 3329,  data width = 12 bits
//
//  Pipeline:  Stage 1 → modq     (1 clk)
//             Stage 2 → Barrett  (1 clk)
//  Total latency = 2 clock cycles
//
// ============================================================
//  TWIDDLE FACTORS  (ζ = 17, q = 3329)
//  INTT_W[k] = (ζ^bit_rev7(ntt_k))^(-1) mod q
//  where ntt_k is traversed in REVERSE NTT order (Layer 6 → Layer 0)
//  127 values total, NO final n^-1 scaling needed.
//
//  INTT_TWIDDLES_W[127] = {
//     3312,   568,  2746,   680,  1692,  2606,  1041,  2229,
//     1920,   667,    48,  3096,  2573,  1173,   314,   279,
//     1626,  1678,   540,  1540,  1482,  2377,  1868,   642,
//     2390,  1021,   892,   941,  2596,   992,  3061,  2688,
//     1745,  1031,  1292,   109,  2954,   780,  1239,  1684,
//     2266,  3010,   556,  2572,  1230,  2768,   863,   735,
//      525,  2237,  2926,  2303,  2186,  1179,   554,  2443,
//     1607,  2117,  1455,  2300,  1219,   394,  2444,  1175,
//     3040,  2998,    76,  1573,  2132,  1025,  1052,  1274,
//     2679,  1352,   816,  2697,   464,  3296,  2009,  1414,
//     1010,  1894,  2522,  2877,  1891,   461,  1795,   927,
//      682,   712,  1848,  2681,   855,   219,  2102,  2419,
//     3033,   882,  1990,  1853,   283,  3273,  1089,  1996,
//     1903,  1235,  2794,   447,   936,   450,  1355,  2508,
//     2267,  1410,  3136,  2532,   543,    69,  2760,  1583,
//      687,  2699,  1432,  2481,   749,    40,  1600
//  };
//
//  INTT Layer breakdown (inverse NTT layer order, Layer 6 first):
//    Layer 6 inv: half=  2 :  64 butterflies: W = [3312, 568, 2746, 680, ...]
//    Layer 5 inv: half=  4 :  32 butterflies: W = [3040, 2998, 76, 1573, ...]
//    Layer 4 inv: half=  8 :  16 butterflies: W = [3033, 882, 1990, 1853, ...]
//    Layer 3 inv: half= 16 :   8 butterflies: W = [2267, 1410, 3136, 2532, ...]
//    Layer 2 inv: half= 32 :   4 butterflies: W = [687, 2699, 1432, 2481]
//    Layer 1 inv: half= 64 :   2 butterflies: W = [749, 40]
//    Layer 0 inv: half=128 :   1 butterfly  : W = [1600]
//
//  NOTE: The INTT does NOT require multiplying by n^-1 = 256^-1 mod q.
//        The reference data in intt_output.txt was generated without scaling.
// ============================================================

module gs_butterfly (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [11:0] A,       // First  butterfly input  ∈ [0, q-1]
    input  logic [11:0] B,       // Second butterfly input  ∈ [0, q-1]
    input  logic [11:0] W,       // Twiddle factor (pre-computed) ∈ [0, q-1]
    output logic [11:0] A_out,   // A' = (A + B)   mod q
    output logic [11:0] B_out,   // B' = (A − B)·W mod q
    output logic        valid_out
);

    localparam int Q = 3329;

    // ── Stage 1 : Sum and Difference paths through modq ───────
    logic signed [15:0] sum_raw;   // A + B  (may exceed q)
    logic signed [15:0] diff_raw;  // A − B  (may be negative)

    assign sum_raw  = $signed({4'b0, A}) + $signed({4'b0, B});
    assign diff_raw = $signed({4'b0, A}) - $signed({4'b0, B});

    // modq for sum path → A_out (final result)
    logic [11:0] sum_mod;
    logic        modq_sum_valid;

    modq u_modq_sum (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .C        (sum_raw),
        .P        (sum_mod),
        .valid_out(modq_sum_valid)
    );

    // modq for diff path → intermediate diff_mod
    logic [11:0] diff_mod;
    logic        modq_diff_valid;

    modq u_modq_diff (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .C        (diff_raw),
        .P        (diff_mod),
        .valid_out(modq_diff_valid)
    );

    // ── Pipeline register: delay W to align with modq output ──
    logic [11:0] W_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            W_reg <= 12'b0;
        else if (valid_in)
            W_reg <= W;
    end

    // ── Stage 2 : Multiply diff_mod × W, then Barrett reduce ──
    logic [23:0] diff_W_raw;       // diff_mod × W  (up to 3328², fits in 24 bits)
    logic [11:0] B_out_barrett;
    logic        barrett_valid;

    assign diff_W_raw = 24'(diff_mod) * 24'(W_reg);

    barrett_reduction_kyber u_br (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (modq_diff_valid),
        .C        (diff_W_raw),
        .P        (B_out_barrett),
        .valid_out(barrett_valid)
    );

    // ── Pipeline register: delay A_out (sum_mod) to align with Barrett ──
    logic [11:0] A_out_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            A_out_reg <= 12'b0;
        else if (modq_sum_valid)
            A_out_reg <= sum_mod;
    end

    // ── Final outputs ─────────────────────────────────────────
    assign A_out    = A_out_reg;
    assign B_out    = B_out_barrett;
    assign valid_out = barrett_valid;

endmodule
