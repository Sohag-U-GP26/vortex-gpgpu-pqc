// ============================================================
//  barrett_reduction_kyber_wide.sv
//  Wide Barrett Reduction for CRYSTALS-Kyber
// ============================================================
//
//  Differences from barrett_reduction_kyber.sv:
//    - accepts a 36-bit input instead of 24-bit
//    - μ = floor(2^36 / q) = 20,642,678  (instead of μ_24 = 5039)
//    - used when inputs exceed q² (e.g., A1·B1·ζ)
//
//  Bounds:
//    C ∈ [0, 2^36)   →   P ≡ C mod q  ∈ [0, q)
//
//  Algorithm (non-Montgomery Barrett):
//    prod  = C × μ              (61-bit)
//    q_est = prod >> 36         (estimate of floor(C/q))
//    rem   = C − q_est × q      (∈ [0, 2q) guaranteed by Barrett)
//    P     = (rem ≥ q) ? rem−q : rem
//
//  Latency: 1 clock cycle (combinational + 1 FF)
//
//  Note: If the input is less than 36-bit (e.g., raw_C1 at 25-bit),
//        zero-extending to 36-bit before feeding is sufficient.
// ============================================================

module barrett_reduction_kyber_wide #(
    parameter int      Q  = 3329,
    // μ = floor(2^36 / Q) = 20,642,678
    // تحقق: 20,642,678 × 3329 = 68,719,475,062  <  2^36 = 68,719,476,736  ✓
    parameter longint  MU = 20_642_678
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [35:0] C,          // input: 0 ≤ C < 2^36
    output logic [11:0] P,          // output: P ≡ C mod q
    output logic        valid_out
);

    // ----------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------
    logic [60:0] prod;       // C (36-bit) × μ (25-bit) = 61-bit
    logic [24:0] q_est;      // >> 36 → 25-bit  (q_est ≤ floor(C/q) ≤ ~11M)
    logic [35:0] q_est_q;    // q_est × q  ≤ C < 2^36
    logic [35:0] rem;        // estimated remainder ∈ [0, 2q)
    logic [11:0] P_comb;     // combinational result before registering

    // ----------------------------------------------------------
    // Combinational logic
    // ----------------------------------------------------------
    always_comb begin
        // Step 1: C × μ  (36 × 25 = 61 bits)
        prod    = {25'b0, C} * {36'b0, MU[24:0]};

        // Step 2: >> 36  →  estimate floor(C/q)
        q_est   = prod[60:36];

        // Step 3: q_est × q
        q_est_q = 36'(q_est) * 36'(Q);

        // Step 4: rem = C − q_est×q  ∈ [0, 2q)
        rem     = C - q_est_q;

        // Step 5: final correction
        P_comb  = (rem >= 36'(Q)) ? 12'(rem) - 12'(Q)
                        : 12'(rem);
    end

    // ----------------------------------------------------------
    // Register stage (1 cycle latency)
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P         <= 12'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in)
                P <= P_comb;
        end
    end

endmodule
