// ============================================================
//  Conditional Addition/Subtraction Reduction (Kyber)
//  Range: [-3328 , 6656]
// ============================================================

module modq #(
    parameter int Q = 3329
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               valid_in,
    input  logic signed [15:0] C,      // Must be signed to accept negative
    output logic        [11:0] P,      // Output is always positive [0, 3328]
    output logic               valid_out
);

    logic signed [16:0] c_step1;
    logic signed [16:0] c_step2;

    logic signed [16:0] mask1, mask2;

    always_comb begin
        // 1. First condition: mask-based constant-time selection
        // If C[15]=1 (negative) -> mask1=0xFFFF, else mask1=0x0000
        mask1 = {17{C[15]}};
        c_step1 = C + (mask1 & $signed(17'(Q)));

        // 2. Second condition: mask-based constant-time selection
        mask2 = {17{c_step1 > $signed(17'(3328))}};
        c_step2 = c_step1 - (mask2 & $signed(17'(Q)));
    end

    // -------------------------------------------------------
    // Register Stage (Flip-Flops)
    // -------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P         <= 12'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                P <= 12'(c_step2); // Safely take lower 12 bits
            end
        end
    end

endmodule