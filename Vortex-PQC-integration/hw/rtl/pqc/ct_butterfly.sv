// ============================================================
//  ct_butterfly.sv
//  Cooley-Tukey (CT) Butterfly for Kyber NTT
//
//  Diagram:
//    A ──────────────────(+)───── A' = (A + B·W) mod q
//                     ╲╱
//    B ──⊗[Barrett]──(−)───── B' = (A − B·W) mod q
//         ↑
//      twiddle W
//
//  Operation:
//    BW    = Barrett_reduce(B × W)
//    A'    = modq(A + BW)
//    B'    = modq(A − BW)
//
//  Parameters (Kyber-512/768/1024):
//    q = 3329,  data width = 12 bits
//
//  Pipeline:  Stage 1 → Barrett (1 clk)
//             Stage 2 → modq   (1 clk)
//  Total latency = 2 clock cycles
//
// ============================================================
//  TWIDDLE FACTORS  (ζ = 17, q = 3329)
//  W[k] = ζ^bit_rev7(k) mod q   for k = 1..127
//  127 values, consumed in NTT layer order (Layer 0 first)
//
//  NTT_TWIDDLES_W[127] = {
//     1729,  2580,  3289,  2642,   630,  1897,   848,  1062,
//     1919,   193,   797,  2786,  3260,   569,  1746,   296,
//     2447,  1339,  1476,  3046,    56,  2240,  1333,  1426,
//     2094,   535,  2882,  2393,  2879,  1974,   821,   289,
//      331,  3253,  1756,  1197,  2304,  2277,  2055,   650,
//     1977,  2513,   632,  2865,    33,  1320,  1915,  2319,
//     1435,   807,   452,  1438,  2868,  1534,  2402,  2647,
//     2617,  1481,   648,  2474,  3110,  1227,   910,    17,
//     2761,   583,  2649,  1637,   723,  2288,  1100,  1409,
//     2662,  3281,   233,   756,  2156,  3015,  3050,  1703,
//     1651,  2789,  1789,  1847,   952,  1461,  2687,   939,
//     2308,  2437,  2388,   733,  2337,   268,   641,  1584,
//     2298,  2037,  3220,   375,  2549,  2090,  1645,  1063,
//      319,  2773,   757,  2099,   561,  2466,  2594,  2804,
//     1092,   403,  1026,  1143,  2150,  2775,   886,  1722,
//     1212,  1874,  1029,  2110,  2935,   885,  2154
//  };
//
//  Layer breakdown (Layer : half-size : count : first W values):
//    Layer 0 : half=128 :   1 butterfly  : W = [1729]
//    Layer 1 : half= 64 :   2 butterflies: W = [2580, 3289]
//    Layer 2 : half= 32 :   4 butterflies: W = [2642, 630, 1897, 848]
//    Layer 3 : half= 16 :   8 butterflies: W = [1062, 1919, 193, 797, ...]
//    Layer 4 : half=  8 :  16 butterflies: W = [296, 2447, 1339, 1476, ...]
//    Layer 5 : half=  4 :  32 butterflies: W = [289, 331, 3253, 1756, ...]
//    Layer 6 : half=  2 :  64 butterflies: W = [17, 2761, 583, 2649, ...]
// ============================================================

module ct_butterfly (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [11:0] A,       // First  butterfly input  ∈ [0, q-1]
    input  logic [11:0] B,       // Second butterfly input  ∈ [0, q-1]
    input  logic [11:0] W,       // Twiddle factor (pre-computed) ∈ [0, q-1]
    output logic [11:0] A_out,   // A' = (A + B·W) mod q
    output logic [11:0] B_out,   // B' = (A − B·W) mod q
    output logic        valid_out
);

    localparam int Q = 3329;

    // ── Stage 1 : Barrett multiply B × W ──────────────────────
    logic [23:0] BW_raw;          // B × W  (up to 3328² ≈ 11 M, fits in 24 bits)
    logic [11:0] BW_mod;          // B·W  mod q  (Barrett output)
    logic        barrett_valid;

    assign BW_raw = 24'(B) * 24'(W);

    barrett_reduction_kyber u_br (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .C        (BW_raw),
        .P        (BW_mod),
        .valid_out(barrett_valid)
    );

    // ── Pipeline register: delay A to align with Barrett output ──
    logic [11:0] A_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            A_reg <= 12'b0;
        else if (valid_in)
            A_reg <= A;
    end

    // ── Stage 2 : Butterfly add / subtract → modq ─────────────
    logic signed [15:0] sum_raw;   // A + BW_mod  (may exceed q)
    logic signed [15:0] diff_raw;  // A − BW_mod  (may be negative)

    assign sum_raw  = $signed({4'b0, A_reg}) + $signed({4'b0, BW_mod});
    assign diff_raw = $signed({4'b0, A_reg}) - $signed({4'b0, BW_mod});

    // modq for sum path → A_out
    logic        modq_sum_valid;

    modq u_modq_sum (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (barrett_valid),
        .C        (sum_raw),
        .P        (A_out),
        .valid_out(modq_sum_valid)
    );

    // modq for diff path → B_out
    modq u_modq_diff (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (barrett_valid),
        .C        (diff_raw),
        .P        (B_out),
        .valid_out(valid_out)       // use one valid_out as the butterfly valid
    );

endmodule
