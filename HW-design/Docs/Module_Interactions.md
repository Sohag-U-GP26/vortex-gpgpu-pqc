# Module Interactions (Phase 1)

> Part of [Phase 1: Standalone RTL Architecture](../README.md) — module dependency graph, data flow, and signal interfaces.

## Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                      kyber_final_mult                           │
│  out = (in × 3303) mod 3329                                     │
│  Pipeline: 1 cycle                                              │
└────────────────────────────┬────────────────────────────────────┘
                             │ depends on
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     basemul_kyber_v2                            │
│  Computes (a0+a1X)(b0+b1X) mod (X² - ζ)                         │
│  Pipeline: 3 cycles                                             │
│  Key innovation: accumulate raw products, reduce once at end    │
└──────────┬──────────────────────────────────────┬───────────────┘
           │ depends on                           │ depends on
           ▼                                      ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│ barrett_reduction_kyber  │    │ barrett_reduction_kyber  │
│ _wide (36-bit input)     │    │ _wide (36-bit input)     │
│ P = raw_C0 mod q         │    │ P = raw_C1 mod q         │
│ Pipeline: 1 cycle        │    │ Pipeline: 1 cycle        │
└──────────────────────────┘    └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      ct_butterfly                               │
│  Cooley-Tukey: A' = A + B·W, B' = A - B·W                       │
│  Used in: Forward NTT (7 stages)                                │
│  Pipeline: 2 cycles                                             │
└──────────┬──────────────────────────────────────┬───────────────┘
           │ depends on                           │ depends on
           ▼                                      ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│ barrett_reduction_kyber  │    │ modq (×2)                │
│ (24-bit input)           │    │ Conditional reduction    │
│ P = (B×W) mod q          │    │ A' / B' ∈ [0, q-1]       │
│ Pipeline: 1 cycle        │    │ Pipeline: 1 cycle        │
└──────────────────────────┘    └──────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      gs_butterfly                               │
│  Gentleman-Sande: A' = A + B, B' = (A - B)·W                    │
│  Used in: Inverse NTT (7 stages, reverse order)                 │
│  Pipeline: 2 cycles                                             │
└──────────┬──────────────────────────────────────┬───────────────┘
           │ depends on                           │ depends on
           ▼                                      ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│ modq (×2)                │    │ barrett_reduction_kyber  │
│ A+B / A-B reduction      │    │ (A-B)×W mod q            │
│ Pipeline: 1 cycle        │    │ Pipeline: 1 cycle        │
└──────────────────────────┘    └──────────────────────────┘
```

## Data Flow Through the NTT Pipeline

### Forward NTT (Cooley-Tukey)

```
Input: Poly[0..255]  (coefficients in normal order)

Layer 0 (half=128):
  for each pair (i, i+128):
    W = NTT_W[1]
    {Poly[i], Poly[i+128]} = ct_butterfly(Poly[i], Poly[i+128], W)

Layer 1 (half=64):
  for each block of 128:
    for each pair (i, i+64) in block:
      W = NTT_W[2..3] (one per block)
      {Poly[i], Poly[i+64]} = ct_butterfly(Poly[i], Poly[i+64], W)

... (layers 2 through 6)

Layer 6 (half=2):
  for each block of 4:
    for each pair (i, i+2) in block:
      W = NTT_W[64..127] (one per block)
      {Poly[i], Poly[i+2]} = ct_butterfly(Poly[i], Poly[i+2], W)

Output: NTT(Poly)  (128 pairs of 2 coefficients)
```

### Basecase Multiplication

```
Input: NTT(A)[0..255], NTT(B)[0..255]

For each pair index i in 0..63:
  idx = 4 × i
  ζ_pos = ZETA_POS[i]
  
  pair at idx:   (A[idx], A[idx+1]) × (B[idx], B[idx+1]) with ζ = ζ_pos
  pair at idx+2: (A[idx+2], A[idx+3]) × (B[idx+2], B[idx+3]) with ζ = q - ζ_pos
  
  Result: C[idx..idx+3] (4 coefficients)

Output: C[0..255]  (product in NTT domain)
```

### Inverse NTT (Gentleman-Sande, Reverse Order)

```
Input: C[0..255]  (product from basecase)

Layer 6 (half=2):  (first in INTT, last in NTT)
  W = INTT_W[0..63]
  gs_butterfly on each pair

... (layers 5 through 0)

Layer 0 (half=128):
  W = INTT_W[126]  (only one)
  gs_butterfly on final pair

Then: multiply each coefficient by n⁻¹ = 3303

Output: A·B mod (xⁿ + 1)  (the final polynomial product)
```

## Signal Interfaces

### Standard Module Interface Pattern

Every module follows this convention:

```systemverilog
module module_name (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    // data inputs
    output logic        valid_out,
    // data outputs
);
```

### Valid Signal Semantics

- `valid_in`: data at the input ports is valid and should be processed
- `valid_out`: data at the output ports is valid and ready to be consumed
- The module registers the valid signal through its pipeline, maintaining alignment with data

### Pipeline Alignment

Data and valid signals travel through identical pipeline registers. This ensures that a module's output is always properly qualified by its `valid_out` signal, regardless of pipeline depth.

## Module Composition for Full Polynomial Multiplication

The complete polynomial multiplication (used by Kyber KEM) would compose these modules as follows:

```
NTT(A) = apply ct_butterfly × 127 on polynomial A
NTT(B) = apply ct_butterfly × 127 on polynomial B

For each of 64 coefficient groups:
  C[4i:4i+3] = basemul_kyber_v2(NTT(A)[4i:4i+3], NTT(B)[4i:4i+3], ζ[i])

Result = apply gs_butterfly × 127 on C
Result = apply kyber_final_mult × 256 on Result  (×n⁻¹ scaling)
```

Each stage is fully pipelined; a complete hardware accelerator would use FIFOs or register files between stages to absorb pipeline latency differences.
