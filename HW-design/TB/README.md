# TB — Verification Environment (Phase 1)

> Part of [Phase 1: Standalone RTL Architecture](../README.md) — the verification environment for the Kyber polynomial multiplication accelerator.

## Purpose

This directory contains the complete verification environment for the CRYSTALS-Kyber hardware accelerator. It includes SystemVerilog testbenches at multiple abstraction levels, simulation automation scripts, and golden reference vectors for cross-validation.

## Verification Philosophy

The verification strategy follows a **bottom-up, cross-validated** approach:

1. **Unit-level tests**: Each RTL module is verified independently with simple, manually crafted test vectors
2. **Integration tests**: Full NTT and INTT pipelines are driven with polynomial-length data
3. **Golden cross-validation**: All testbench outputs are compared against Python-generated reference vectors

This ensures that every verified module is correct at three levels: algorithmic (does it compute the right value?), architectural (does it pipeline correctly?), and integration (do all modules work together?).

## Verification Flow Diagram

```
┌──────────────────────┐
│ Python Golden Model  │──► Generates reference vectors (TB/Ref/)
└──────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│              SystemVerilog Testbenches               │
├──────────────┬───────────────────┬───────────────────┤
│  Simple TBs  │   Full TBs        │   Simulation      │
│  (per module)│   (NTT/INTT pipe)  │   Scripts        │
├──────────────┼───────────────────┼───────────────────┤
│ tb_barrett   │ tb_ntt_full       │ Do_Files/         │
│   _simple    │ tb_intt_full      │  run_ntt.do       │
│ tb_modq      │ tb_basemul_kyber  │  run_intt.do      │
│   _simple    │   _v2             │                   │
│ tb_ct_       │                    │                  │
│   butterfly  │                    │                  │
│   _simple    │                    │                  │
│ tb_gs_       │                    │                  │
│   butterfly  │                    │                  │
│   _simple    │                    │                  │
│ tb_basemul   │                    │                  │
│   _simple    │                    │                  │
│ tb_kyber_    │                    │                  │
│   final_mult │                    │                  │
│   _simple    │                    │                  │
└──────────────┴───────────────────┴───────────────────┘
         │                               │
         ▼                               ▼
┌─────────────────┐          ┌──────────────────────┐
│ Module-level    │          │ Pipeline-level       │
│ correctness     │          │ end-to-end correctness│
└─────────────────┘          └──────────────────────┘
```

## Testbench Types

### Simple Testbenches (`tb_*_simple.sv`)

These testbenches verify individual modules in isolation. Each one:

- Instantiates one DUT (design under test)
- Drives a set of representative input values
- Computes expected outputs inline using the same algorithm
- Waits the module's known pipeline latency
- Compares actual vs. expected and reports PASS/FAIL

| Testbench | DUT | Latency | Test Vectors |
|-----------|-----|---------|-------------|
| `tb_barrett_simple` | `barrett_reduction_kyber` | 1 cycle | 30 values (0 to ~11M) |
| `tb_modq_simple` | `modq` | 1 cycle | 30 signed values |
| `tb_ct_butterfly_simple` | `ct_butterfly` | 2 cycles | 30 triples (A, B, W) |
| `tb_gs_butterfly_simple` | `gs_butterfly` | 2 cycles | 30 triples (A, B, W) |
| `tb_basemul_simple` | `basemul_kyber_v2` | 3 cycles | 30 quadruples |
| `tb_kyber_final_mult_simple` | `kyber_final_mult` | 1 cycle | 30 values |

### Full Integration Testbenches

These testbenches exercise complete NTT or INTT pipelines with full 256-coefficient polynomials.

#### `tb_ntt_full.sv`

- DUT: `ct_butterfly` (used iteratively for all 7 NTT stages)
- Reads input from: `Ref/a_ntt_input.txt`
- Compares against: `Ref/a_ntt_output.txt`
- Executes 127 butterfly operations (1+2+4+8+16+32+64)
- Pipeline-aware driving: each butterfly takes 3 clock cycles (1 drive + 2 pipeline)
- Reports PASS/FAIL per coefficient with final summary

#### `tb_intt_full.sv`

- DUT: `gs_butterfly` + `kyber_final_mult`
- Reads input from: `Ref/basemul_output.txt`
- Compares against: `Ref/final_output.txt` (includes n⁻¹ scaling)
- Executes 127 butterfly operations (reverse NTT layer order)
- Applies `kyber_final_mult` for all 256 coefficients (×3303 scaling)
- Reports PASS/FAIL per coefficient with final summary

#### `tb_basemul_kyber_v2.sv`

- DUT: `basemul_kyber_v2`
- Reads NTT(A) from `a_ntt_output.hex`, NTT(B) from `b_ntt_output.hex`
- Compares against: `basemul_output.hex`
- Tests all 128 coefficient pairs using the ZETA_POS matrix for twiddle selection
- Reports PASS/FAIL per pair

#### `tb_kyber_final_mult.sv`

- DUT: `kyber_final_mult`
- Reads input from: `intt_output.txt`
- Compares against: `final_output.txt`
- Feeds 256 elements at 1 element/cycle
- 1-cycle pipeline latency; checks valid_out for result capture

## Simulation Workflow

### Using ModelSim DO Scripts

```bash
# From the TB/ directory

# Run NTT simulation
vsim -do Do_Files/run_ntt.do

# Run INTT simulation
vsim -do Do_Files/run_intt.do
```

### Manual Simulation

```bash
# Compile and run individual testbench
vlog -sv barrett_reduction_kyber.sv ../Design/modq.sv
vlog -sv tb_barrett_simple.sv
vsim -novopt tb_barrett_simple -t 1ns
run -all
```

### Interpreting Results

Each testbench prints:
- Per-test PASS/FAIL lines showing actual vs. expected values
- A summary line: `Total Passed: X / Y`
- If all pass: ★★★ banner with module name
- If any fail: mismatch details for debugging

## Golden Model Integration

The Python golden model (`Golden-python-model/kyber_ntt.py`) generates all reference vector files:

| File | Contents | Used By |
|------|----------|---------|
| `a_ntt_input.txt` | 256 random coefficients | `tb_ntt_full` |
| `a_ntt_output.txt` | NTT of input A | `tb_ntt_full` |
| `b_ntt_input.txt` | 256 random coefficients | `tb_basemul_kyber_v2` |
| `b_ntt_output.txt` | NTT of input B | `tb_basemul_kyber_v2` |
| `basemul_output.hex` | Basecase multiplication result | `tb_basemul_kyber_v2` |
| `basemul_output.txt` | Basecase result (decimal) | `tb_intt_full` |
| `intt_output.txt` | INTT before final scaling | `tb_kyber_final_mult` |
| `final_output.txt` | Complete multiplication result | `tb_intt_full`, `tb_kyber_final_mult` |

To regenerate all reference vectors:

```bash
cd Golden-python-model/
python kyber_ntt.py
```

## Adding New Tests

To add a test for a new module:

1. **Create a simple testbench** (`tb_<module>_simple.sv`):
   - Instantiate the DUT
   - Drive ~20-30 representative inputs covering edge cases (0, 1, q-1, q, large values, negative values)
   - Compute expected outputs inline
   - Wait for pipeline latency, then compare
   - Print PASS/FAIL and final summary

2. **If the module is part of the NTT pipeline**, create a full testbench:
   - Generate reference vectors using the Python golden model
   - Save to `TB/Ref/`
   - Drive the DUT with pipeline-level data

3. **Optionally**, create a `.do` script in `TB/Do_Files/` for one-command simulation.

## Debugging Recommendations

- **Pipeline timing mismatches**: Verify the testbench latency constant matches the module's actual pipeline depth (+ 1 cycle for the final output register read). Common bug: reading outputs one cycle too early or too late.

- **Bit width errors**: If intermediate values overflow, the Barrett reduction may produce wrong results. Check that data widths match the module's documented ranges.

- **Reference vector mismatches**: Regenerate the Python golden model reference vectors. If the Python model was updated, the RTL may need corresponding changes.

- **Constant-time vs. behavioral**: Inline expected computations in testbenches use `% Q` which may not match the constant-time reduction exactly at boundary conditions (e.g., when remainder = q). Verify with the Python model.

- **Back-to-back valid_in**: The `gs_butterfly` module has a specific pipeline alignment fix for back-to-back valid assertions. If debugging INTT failures, check that the testbench does not drive back-to-back butterflies without accounting for pipeline registers.

## Directory Structure

```
TB/
├── Do_Files/            # ModelSim simulation scripts
│   ├── run_ntt.do       #  NTT butterfly test
│   └── run_intt.do      #  INTT butterfly + final mult test
├── Ref/                 # Golden reference vectors
│   ├── a_ntt_input.txt  #  NTT input polynomial A
│   ├── a_ntt_output.txt #  NTT(A)
│   ├── a_ntt_output.hex #  NTT(A) in hex
│   ├── b_ntt_input.txt  #  NTT input polynomial B
│   ├── b_ntt_output.txt #  NTT(B)
│   ├── b_ntt_output.hex #  NTT(B) in hex
│   ├── basemul_output.txt   #  Basecase result (decimal)
│   ├── basemul_output.hex   #  Basecase result (hex)
│   ├── intt_output.txt      #  INTT output (before final scaling)
│   └── final_output.txt     #  Final result after ×3303
├── tb_barrett_simple.sv      #  Barrett reduction unit test
├── tb_basemul_kyber_v2.sv    #  Full basecase testbench
├── tb_basemul_simple.sv      #  Basecase unit test
├── tb_ct_butterfly_simple.sv #  CT butterfly unit test
├── tb_gs_butterfly_simple.sv #  GS butterfly unit test
├── tb_intt_full.sv           #  Full INTT pipeline testbench
├── tb_kyber_final_mult.sv    #  Final multiply full testbench
├── tb_kyber_final_mult_simple.sv  #  Final multiply unit test
├── tb_modq_simple.sv         #  modq unit test
└── tb_ntt_full.sv            #  Full NTT pipeline testbench
```
