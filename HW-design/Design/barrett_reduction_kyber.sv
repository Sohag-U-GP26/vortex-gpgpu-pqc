// ============================================================
//  Optimized Barrett Reduction for CRYSTALS-Kyber (Fixed)
// ============================================================

module barrett_reduction_kyber #(
    parameter int Q     = 3329,   // Prime modulus
    parameter int LOG2R = 12      // R = 2^LOG2R
)(
    input  logic        clk,
    input  logic        rst_n,    
    input  logic        valid_in,
    input  logic [23:0] C,        // Input: 0 <= C < q²
    output logic [11:0] P,        // Output: P ≡ C mod q
    output logic        valid_out
);

    // -------------------------------------------------------
    // Internal signals with correct bit extensions
    // -------------------------------------------------------
    logic signed [37:0] C2;  // C * μ (needs space for 24 bits + 13 bits for μ)
    logic [11:0]        C3;  // C2 >> 24 (estimated quotient)
    logic signed [25:0] C4;  // C3 * q
    logic signed [25:0] C5;  // C - C4
    logic signed [25:0] C6;  // C5 - q

    logic [11:0] mask_b;

    // -------------------------------------------------------
    // Combinational logic
    // -------------------------------------------------------
    always_comb begin

        //------------------------------------------------------
        // Step 1 : C2 = C * μ 
        // μ = 5039 = 4096 + 1024 - 64 - 16 - 1
        // Apply multiplication to full C to preserve precision
        //------------------------------------------------------
        C2 = $signed({14'b0, C} << 12)
            + $signed({14'b0, C} << 10)
            - $signed({14'b0, C} << 6)
            - $signed({14'b0, C} << 4)
            - $signed({14'b0, C});

        //------------------------------------------------------
        // Step 2 : C3 = C2 >> 24
        // This is equivalent to dividing by R² = 2^24
        //------------------------------------------------------
        // assert (C2 <= 55_813_207_840) else $error("C2 overflow!");
        C3 = 12'(unsigned'(C2) >> 24); // Extract required bits directly

        //------------------------------------------------------
        // Step 3 : C4 = C3 * q
        // q = 3329 = 4096 - 512 - 256 + 1
        //------------------------------------------------------
        C4 = $signed({14'b0, C3} << 12)
            - $signed({14'b0, C3} << 9)
            - $signed({14'b0, C3} << 8)
            + $signed({14'b0, C3});

        //------------------------------------------------------
        // Step 4 : C5 = C - C4
        // Use full bit widths to avoid any sign errors
        //------------------------------------------------------
        C5 = $signed({2'b0, C}) - C4;

        //------------------------------------------------------
        // Step 5 : C6 = C5 - q
        //------------------------------------------------------
        C6 = C5 - $signed(26'(Q));

        mask_b = {12{C6[25]}}; // all-1 if C6 < 0 (MSB=1)
    end

    // -------------------------------------------------------
    // Registration stage (Flip-Flops)
    // -------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P         <= 12'b0;
            valid_out <= 1'b0;
        end
        else begin
            valid_out <= valid_in;
            if (valid_in) begin
                P <= (mask_b & 12'(C5)) | (~mask_b & 12'(C6));
            end
        end
    end

endmodule
