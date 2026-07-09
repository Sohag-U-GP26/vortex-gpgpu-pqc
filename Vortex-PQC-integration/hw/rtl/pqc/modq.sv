// ============================================================
//  Conditional Addition/Subtraction Reduction (Kyber)
//  Range: [-3329 , 6656]
// ============================================================

module modq #(
    parameter int Q = 3329
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               valid_in,
    input  logic signed [15:0] C,      // Should be signed to accept negative values
    output logic        [11:0] P,      // Output is always non-negative [0, 3328]
    output logic               valid_out
);

    logic signed [16:0] c_step1;
    logic signed [16:0] c_step2;

    always_comb begin
        // 1. First condition: if c < 0
        if (C < 0) begin
            c_step1 = C + Q;
        end else begin
            c_step1 = C;
        end

        // 2. Second condition: if c > 3328
        if (c_step1 > 3328) begin
            c_step2 = c_step1 - Q; 
        end else begin
            c_step2 = c_step1;
        end
    end

    // -------------------------------------------------------
    // Register stage (Flip-Flops)
    // -------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P         <= 12'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                P <= 12'(c_step2); // Safely take the lower 12 bits
            end
        end
    end

endmodule