// ============================================================
//  basemul_kyber_v2.sv
//  Base-Case Polynomial Multiplication — CRYSTALS-Kyber
//  Second version: single Wide Barrett at the end
// ============================================================
//
//  Differences from v1:
//    v1 → uses 5 sequential instances of barrett_reduction_kyber (24-bit)
//    v2 → accumulates raw products without reduction, then calls
//          barrett_reduction_kyber_wide (36-bit) once per output
//
//  Mathematics (without intermediate reduction):
//    raw_C0 = A0·B0 + A1·B1·ζ   ≤ (q-1)² + (q-1)³  <  2^36
//    raw_C1 = A0·B1 + A1·B0     ≤ 2·(q-1)²          <  2^25 < 2^36
//
//  Pipeline — 3 cycles latency:
//    Cycle 0 (comb) : m00,m11,m01,m10 and zeta
//    Cycle 1 (FF)   : store products + zeta
//    Cycle 1 (comb) : m11_zeta = m11_r × zeta_r  (36-bit)
//                     raw_C1   = m01_r + m10_r   (25-bit)
//    Cycle 2 (FF)   : store m00_r2, m11_zeta_r, raw_C1_r
//    Cycle 2 (comb) : raw_C0 = m00_r2 + m11_zeta_r (36-bit)
//    Cycle 3 (FF)   : inside barrett_reduction_kyber_wide → C0, C1, valid_out
// ============================================================

module basemul_kyber_v2 #(
    parameter int Q = 3329
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,

    input  logic [11:0] A0,         // A[2i]
    input  logic [11:0] A1,         // A[2i+1]
    input  logic [11:0] B0,         // B[2i]
    input  logic [11:0] B1,         // B[2i+1]

    input  logic [11:0] zeta,       // Twisting factor ζ for this pair

    output logic [11:0] C0,         // C[2i]   — صالح بعد 3 دورات
    output logic [11:0] C1,         // C[2i+1]
    output logic        valid_out
);

    // =========================================================================
    //  Details of the Zeta array (Twisting Factors) used in Basecase
    // =========================================================================
    //  In the Kyber algorithm, the prime modulus (q) = 3329.
    //  The primitive 512th root of unity ζ = 17.
    //  In the Basecase stage (the final stage of NTT), we use specific ζ values
    //  for each adjacent pair of elements.
    //
    //  The 64 positive ζ values are computed as:
    //      zeta_pos[k] = 17^{br7(64+k)} mod 3329    for k = 0..63
    //  where br7 is the 7-bit bit reversal.
    //
    //  Values of ZETA_POS array (64 positive values):
    //  17,   2761, 583,  2649, 1637, 723,  2288, 1100,
    //  1409, 2662, 3281, 233,  756,  2156, 3015, 3050,
    //  1703, 1651, 2789, 1789, 1847, 952,  1461, 2687,
    //  939,  2308, 2437, 2388, 733,  2337, 268,  641,
    //  1584, 2298, 2037, 3220, 375,  2549, 2090, 1645,
    //  1063, 319,  2773, 757,  2099, 561,  2466, 2594,
    //  2804, 1092, 403,  1026, 1143, 2150, 2775, 886,
    //  1722, 1212, 1874, 1029, 2110, 2935, 885,  2154
    //
    //  How to select ζ for each pair (pair_idx from 0 to 127):
    //  - Each pair index uses ZETA_POS[pair_idx/2], with alternating sign.
    //  - If pair_idx is even (pair_idx[0] == 0):
    //      zeta = ZETA_POS[pair_idx / 2]
    //  - If pair_idx is odd (pair_idx[0] == 1):
    //      zeta = 3329 - ZETA_POS[pair_idx / 2]  (i.e., negative ζ)
    //
    //  This module (`basemul_kyber_v2`) receives the precomputed zeta value
    //  as a direct input rather than computing it internally.
    // =========================================================================

    // ----------------------------------------------------------
    // Cycle 0: 4 parallel multipliers  12×12→24 bit
    // ----------------------------------------------------------
    logic [23:0] m00, m11, m01, m10;
    assign m00 = A0 * B0;
    assign m11 = A1 * B1;
    assign m01 = A0 * B1;
    assign m10 = A1 * B0;

    // ----------------------------------------------------------
    // valid shift register — 2 stages
    //   valid_sr[0]: after Cycle-1 FF
    //   valid_sr[1]: after Cycle-2 FF → feeds the Barrett instances
    // ----------------------------------------------------------
    logic [1:0] valid_sr;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_sr <= 2'b0;
        else        valid_sr <= {valid_sr[0], valid_in};
    end
    // valid_out comes from Barrett directly (see below)

    // ----------------------------------------------------------
    // Cycle 1 FF: store Cycle-0 products and zeta (gated by valid_in)
    // ----------------------------------------------------------
    logic [23:0] m00_r, m11_r, m01_r, m10_r;
    logic [11:0] zeta_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m00_r  <= 24'b0; m11_r  <= 24'b0;
            m01_r  <= 24'b0; m10_r  <= 24'b0;
            zeta_r <= 12'b0;
        end else begin
            m00_r  <= m00;  m11_r  <= m11;
            m01_r  <= m01;  m10_r  <= m10;
            zeta_r <= zeta;
        end
    end

    // ----------------------------------------------------------
    // Cycle 1 comb: second product (without reduction)
    //   m11_zeta = A1·B1·ζ  →  24-bit × 12-bit = 36-bit
    //   raw_C1   = A0·B1 + A1·B0  →  25-bit
    // ----------------------------------------------------------
    logic [35:0] m11_zeta;
    logic [24:0] raw_C1_s1;

    assign m11_zeta  = m11_r * zeta_r;
    assign raw_C1_s1 = {1'b0, m01_r} + {1'b0, m10_r};

    // ----------------------------------------------------------
    // Cycle 2 FF: store Cycle-1 results (gated by valid_sr[0])
    // ----------------------------------------------------------
    logic [23:0] m00_r2;
    logic [35:0] m11_zeta_r;
    logic [24:0] raw_C1_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m00_r2     <= 24'b0;
            m11_zeta_r <= 36'b0;
            raw_C1_r   <= 25'b0;
        end else if (valid_sr[0]) begin
            m00_r2     <= m00_r;
            m11_zeta_r <= m11_zeta;
            raw_C1_r   <= raw_C1_s1;
        end
    end

    // ----------------------------------------------------------
    // Cycle 2 comb: assemble final raw_C0
    //   raw_C0 = A0·B0 + A1·B1·ζ   ≤ (q-1)² + (q-1)³ < 2^36
    // ----------------------------------------------------------
    logic [35:0] raw_C0;
    assign raw_C0 = {12'b0, m00_r2} + m11_zeta_r;

    // raw_C1 extended to 36-bit (was 25-bit only, zero-extended)
    logic [35:0] raw_C1_ext;
    assign raw_C1_ext = {11'b0, raw_C1_r};

    // ----------------------------------------------------------
    // Cycle 3 (inside Barrett): apply Wide Barrett once per output
    //
    //   valid_sr[1] → valid_in for the Barrett instances
    //   Barrett registers the output in an internal FF → Cycle 3
    // ----------------------------------------------------------
    logic br_valid_out_c0, br_valid_out_c1;

    // --- Wide Barrett for C0 ---
    barrett_reduction_kyber_wide #(.Q(Q)) br_c0 (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_sr[1]),   // Cycle-2 data جاهز
        .C        (raw_C0),        // 36-bit raw
        .P        (C0),
        .valid_out(br_valid_out_c0)
    );

    // --- Wide Barrett for C1 ---
    barrett_reduction_kyber_wide #(.Q(Q)) br_c1 (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_sr[1]),
        .C        (raw_C1_ext),    // 25-bit ممتدة صفرياً إلى 36-bit
        .P        (C1),
        .valid_out(br_valid_out_c1)
    );

    // valid_out: both Barrett instances produce output in the same cycle
    assign valid_out = br_valid_out_c0;

endmodule
