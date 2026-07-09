// ============================================================
//  kyber_final_mult.sv
//  CRYSTALS-Kyber — final step after INTT in NTT multiplication

//  Equation:   out = (in × 3303) mod 3329

//  Multiply by 3303 without a direct multiplier (shift / add / sub only):
//    3303 = 4096 − 512 − 256 − 16 − 8 − 1
//         = (1<<12) − (1<<9) − (1<<8) − (1<<4) − (1<<3) − (1<<0)

//  Check:  4096−512=3584 | −256=3328 | −16=3312 | −8=3304 | −1=3303 ✓

//  The mod q is performed by the ready-made Barrett reduction unit.

//  Pipeline structure:
//    ┌─────────┐ comb  ┌────────────────────┐  FF  ┌────────┐
//    │ data_in │──────►│ mult × 3303 (comb) │─────►│Barrett │──► data_out
//    └─────────┘       └────────────────────┘      │  (FF)  │
//                                                  └────────┘
//    Latency  = 1 clock cycle
//    Throughput = 1 element/cycle  (fully pipelined)

//  Signal ranges:
//    data_in   : [0, 3328]      (12 bit)
//    product   : [0, 10,992,384]  < q²=11,082,241  (24 bit)  ✓
//    data_out  : [0, 3328]      (12 bit)
// ============================================================

module kyber_final_mult (
    input  logic        clk,
    input  logic        rst_n,      // active-low reset
    input  logic        valid_in,   // input data is valid
    input  logic [11:0] data_in,    // INTT coefficient: 0 ≤ data_in < q
    output logic [11:0] data_out,   // (data_in × 3303) mod 3329
    output logic        valid_out   // output data is valid
);

    // ----------------------------------------------------------
    // Step 1 — multiply data_in × 3303 using shift/add/sub
    //
    //  3303 = (1<<12) − (1<<9) − (1<<8) − (1<<4) − (1<<3) − 1
    //
    //  Extend the bits of each term to 25-bit signed to accommodate subtraction:
    //    {1'b0 , data_in, 12'b0}  = 1+12+12 = 25 bit  → data_in × 4096
    //    {4'b0 , data_in,  9'b0}  = 4+12+ 9 = 25 bit  → data_in ×  512
    //    {5'b0 , data_in,  8'b0}  = 5+12+ 8 = 25 bit  → data_in ×  256
    //    {9'b0 , data_in,  4'b0}  = 9+12+ 4 = 25 bit  → data_in ×   16
    //    {10'b0, data_in,  3'b0}  =10+12+ 3 = 25 bit  → data_in ×    8
    //    {13'b0, data_in       }  =13+12    = 25 bit  → data_in ×    1
    //
    //  The result is always ≥ 0 and fits in 24-bit.
    // ----------------------------------------------------------
    logic signed [24:0] mult_s;
    logic        [23:0] product;

    always_comb begin : mult_3303
        mult_s =   $signed({1'b0,  data_in, 12'b0})   // + data_in × 4096
                 - $signed({4'b0,  data_in,  9'b0})   // − data_in ×  512
                 - $signed({5'b0,  data_in,  8'b0})   // − data_in ×  256
                 - $signed({9'b0,  data_in,  4'b0})   // − data_in ×   16
                 - $signed({10'b0, data_in,  3'b0})   // − data_in ×    8
                 - $signed({13'b0, data_in});          // − data_in ×    1
                                                       // ─────────────────
                                                       // = data_in × 3303

        product = mult_s[23:0];   // Always non-negative and fits in 24-bit
    end : mult_3303

    // ----------------------------------------------------------
    // Step 2 — Barrett Reduction: product mod 3329
    //   q=3329, R=2^12, μ=5039
    //   The unit is registered (1 FF stage) → latency = 1 clock cycle
    // ----------------------------------------------------------
    barrett_reduction_kyber #(
        .Q     (3329),
        .LOG2R (12)
    ) u_barrett (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .C         (product),
        .P         (data_out),
        .valid_out (valid_out)
    );

endmodule
