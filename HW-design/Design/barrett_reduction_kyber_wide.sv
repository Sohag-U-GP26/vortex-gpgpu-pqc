// ============================================================
//  barrett_reduction_kyber_wide.sv
//  Wide Barrett Reduction for CRYSTALS-Kyber
// ============================================================
//
//  Differs from barrett_reduction_kyber.sv in:
//    - Accepts 36-bit input instead of 24-bit
//    - μ = floor(2^36 / q) = 20,642,678  (instead of μ₂₄ = 5039)
//    - Used when inputs are larger than q² (like A1·B1·ζ)
//
//  Bounds:
//    C ∈ [0, 2^36)   ->   P ≡ C mod q  ∈ [0, q)
//
//  Algorithm (non-Montgomery Barrett):
//    prod  = C * μ              (61-bit)
//    q_est = prod >> 36         (estimation floor(C/q))
//    rem   = C - q_est * q      (in [0, 2q) by Barrett guarantee)
//    P     = (rem >= q) ? rem-q : rem
//
//  Latency: 1 clock cycle (combinational + 1 FF)
//
//  Note: If the input is less than 36-bit (like raw_C1 with 25-bit),
//        it is sufficient to zero-extend it to 36-bit before passing.
// ============================================================

module barrett_reduction_kyber_wide #(
    parameter int      Q  = 3329,
    // μ = floor(2^36 / Q) = 20,642,678
    // Check: 20,642,678 * 3329 = 68,719,475,062  <  2^36 = 68,719,476,736  ✓
    parameter longint  MU = 20_642_678
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [35:0] C,          // Input: 0 <= C < 2^36
    output logic [11:0] P,          // Output: P ≡ C mod q
    output logic        valid_out
);

    // ----------------------------------------------------------
    // Internal signals with correct bit extensions
    // ----------------------------------------------------------
    logic signed [61:0] prod;       // C * μ (needs space for 36 bits + 25 bits for μ + sign)
    logic [25:0]        q_est;      // prod >> 36 (estimated quotient)
    logic signed [38:0] q_est_q;    // q_est * q (needs 26 bits + 12 bits for q + sign)
    logic signed [38:0] rem;        // C - q_est_q
    logic signed [38:0] P_comb_signed; // rem - q
    logic [11:0] P_comb;
    logic [11:0] mask_w;

    // ----------------------------------------------------------
    // Combinational logic
    // ----------------------------------------------------------
    always_comb begin
        //------------------------------------------------------
        // Step 1 : C * μ   (shift-add — no actual multiplication)
        // μ = 20,642,678 = 2^24 + 2^22 - 2^18 - 2^16 - 2^10 - 2^7 - 2^3 - 2^1
        // Apply multiplication to full C to preserve precision
        //------------------------------------------------------
        prod    = $signed({26'b0, C} << 24)
                + $signed({26'b0, C} << 22)
                - $signed({26'b0, C} << 18)
                - $signed({26'b0, C} << 16)
                - $signed({26'b0, C} << 10)
                - $signed({26'b0, C} << 7)
                - $signed({26'b0, C} << 3)
                - $signed({26'b0, C} << 1);

        //------------------------------------------------------
        // Step 2: >> 36  ->  estimate floor(C/q)
        // This is equivalent to dividing by 2^36
        //------------------------------------------------------
        q_est   = 26'(prod[61:36]); // Extract required bits directly

        //------------------------------------------------------
        // Step 3: q_est * q  (shift-add — no actual multiplication)
        // q = 3329 = 2^12 - 2^9 - 2^8 + 1
        //------------------------------------------------------
        q_est_q = $signed({13'b0, q_est} << 12)
                - $signed({13'b0, q_est} << 9)
                - $signed({13'b0, q_est} << 8)
                + $signed({13'b0, q_est});

        //------------------------------------------------------
        // Step 4: rem = C - q_est*q
        // Use full bit widths to avoid any sign errors
        //------------------------------------------------------
        rem     = $signed({3'b0, C}) - q_est_q;

        //------------------------------------------------------
        // Step 5: final correction
        //------------------------------------------------------
        P_comb_signed = rem - $signed(39'(Q));
        mask_w  = {12{P_comb_signed[38]}}; // MSB is bit 38
        P_comb  = (mask_w & 12'(rem)) | (~mask_w & 12'(P_comb_signed));
    end

    // ----------------------------------------------------------
    // Registration stage (1 cycle latency)
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
