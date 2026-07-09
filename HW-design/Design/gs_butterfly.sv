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

    // ── Stage 1 output register: captures sum_mod one cycle after valid_in ──
    logic [11:0] A_out_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            A_out_reg <= 12'b0;
        else if (modq_sum_valid)
            A_out_reg <= sum_mod;
    end

    // ── Stage 2 output register: re-register A_out to align with barrett_valid ──
    //
    //  Bug scenario (back-to-back valid_in):
    //    T+0: BF1 valid_in=1
    //    T+1: BF2 valid_in=1 → modq_sum_valid → A_out_reg = sum_mod1  ✓
    //    T+2: BF3 valid_in=1 → modq_sum_valid → A_out_reg = sum_mod2  ← overwrite!
    //                         → barrett_valid fires for BF1
    //                         → A_out (= A_out_reg) = sum_mod2  ← WRONG!
    //
    //  Fix: capture A_out_reg into A_out_reg2 exactly when barrett_valid fires.
    //  At that cycle, A_out_reg still holds sum_mod1 before the new write arrives.
    //    T+2: A_out_reg2 = A_out_reg = sum_mod1 ✓  (then A_out_reg gets sum_mod2)
    //
    logic [11:0] A_out_reg2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            A_out_reg2 <= 12'b0;
        else if (barrett_valid)
            A_out_reg2 <= A_out_reg;
    end

    // ── Final outputs ─────────────────────────────────────────
    assign A_out     = A_out_reg2;
    assign B_out     = B_out_barrett;
    assign valid_out = barrett_valid;

endmodule
