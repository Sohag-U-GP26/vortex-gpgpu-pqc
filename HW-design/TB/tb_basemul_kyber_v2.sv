// ============================================================
//  tb_basemul_kyber_v2.sv
//  Testbench for basemul_kyber_v2 (wide-Barrett version)
//  Latency = 3 cycles
// ============================================================
`timescale 1ns/1ps

module tb_basemul_kyber_v2;

    localparam int Q         = 3329;
    localparam int NUM_PAIRS = 128;
    localparam int LATENCY   = 3;
    localparam int CLK_HALF  = 5;

    logic        clk, rst_n, valid_in;
    logic [11:0] A0, A1, B0, B1;
    logic [11:0] zeta;
    logic [11:0] C0, C1;
    logic        valid_out;

    logic [11:0] A_mem [0:255];
    logic [11:0] B_mem [0:255];
    logic [11:0] C_exp [0:255];

    // ZETA_POS ROM for generating zeta in testbench
    localparam logic [11:0] ZETA_POS [0:63] = '{
        12'd17,   12'd2761, 12'd583,  12'd2649, 12'd1637, 12'd723,  12'd2288, 12'd1100,
        12'd1409, 12'd2662, 12'd3281, 12'd233,  12'd756,  12'd2156, 12'd3015, 12'd3050,
        12'd1703, 12'd1651, 12'd2789, 12'd1789, 12'd1847, 12'd952,  12'd1461, 12'd2687,
        12'd939,  12'd2308, 12'd2437, 12'd2388, 12'd733,  12'd2337, 12'd268,  12'd641,
        12'd1584, 12'd2298, 12'd2037, 12'd3220, 12'd375,  12'd2549, 12'd2090, 12'd1645,
        12'd1063, 12'd319,  12'd2773, 12'd757,  12'd2099, 12'd561,  12'd2466, 12'd2594,
        12'd2804, 12'd1092, 12'd403,  12'd1026, 12'd1143, 12'd2150, 12'd2775, 12'd886,
        12'd1722, 12'd1212, 12'd1874, 12'd1029, 12'd2110, 12'd2935, 12'd885,  12'd2154
    };

    int out_pair_idx = 0;
    int errors       = 0;
    int total_checked = 0;

    basemul_kyber_v2 #(.Q(Q)) dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .A0(A0), .A1(A1), .B0(B0), .B1(B1),
        .zeta(zeta),
        .C0(C0), .C1(C1), .valid_out(valid_out)
    );

    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    initial begin
        $readmemh("a_ntt_output.hex",   A_mem);
        $readmemh("b_ntt_output.hex",   B_mem);
        $readmemh("basemul_output.hex", C_exp);
    end

    // Output checker
    always @(posedge clk) begin
        if (valid_out) begin
            if (C0 !== C_exp[2*out_pair_idx]) begin
                $display("FAIL pair %0d: C0 got %0d, expected %0d",
                         out_pair_idx, C0, C_exp[2*out_pair_idx]);
                errors++;
            end
            if (C1 !== C_exp[2*out_pair_idx+1]) begin
                $display("FAIL pair %0d: C1 got %0d, expected %0d",
                         out_pair_idx, C1, C_exp[2*out_pair_idx+1]);
                errors++;
            end
            total_checked++;
            out_pair_idx++;

            if (out_pair_idx == NUM_PAIRS) begin
                $display("============================================");
                $display("[v2] Test complete: %0d pairs checked.", total_checked);
                if (errors == 0)
                    $display("[v2] ALL PASS (0 errors out of %0d pairs)", total_checked);
                else
                    $display("[v2] FAIL: %0d error(s)!", errors);
                $display("============================================");
                $finish;
            end
        end
    end

    // Stimulus
    integer i;
    initial begin
        rst_n = 0; valid_in = 0;
        A0 = 0; A1 = 0; B0 = 0; B1 = 0; zeta = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        for (i = 0; i < NUM_PAIRS; i++) begin
            A0       <= A_mem[2*i];
            A1       <= A_mem[2*i+1];
            B0       <= B_mem[2*i];
            B1       <= B_mem[2*i+1];
            zeta     <= (i[0]) ? (12'(Q) - ZETA_POS[i[6:1]]) : ZETA_POS[i[6:1]];
            valid_in <= 1'b1;
            @(posedge clk);
        end

        valid_in <= 0;
        repeat (LATENCY + 10) @(posedge clk);
        $display("TIMEOUT");
        $finish;
    end

endmodule
