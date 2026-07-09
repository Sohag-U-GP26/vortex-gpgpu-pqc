# Golden Python Model — Reference Implementation (Phase 1)

> Part of [Phase 1: Standalone RTL Architecture](../README.md) — the algorithmic reference for the Kyber polynomial multiplication accelerator.

## Purpose

This directory contains the Python golden model for CRYSTALS-Kyber polynomial multiplication. The model serves as the **single source of algorithmic truth** for the entire hardware project:

1. **Algorithmic reference** — defines the exact mathematical operations for NTT, INTT, basecase multiplication, and final scaling
2. **Reference vector generation** — produces all test vectors used by the SystemVerilog testbenches
3. **Cross-validation** — provides a naive O(n²) multiplication implementation for verifying NTT-based results
4. **Stage-by-stage debugging** — exports intermediate NTT/INTT stages for pipeline debug

## Implementation

```
Golden-python-model/
└── kyber_ntt.py    # Complete Kyber NTT/INTT implementation (~350 lines)
```

### What It Computes

#### Forward NTT (Cooley-Tukey)

The forward NTT transforms a polynomial from coefficient domain to NTT domain:

```python
for length in [128, 64, 32, 16, 8, 4, 2]:
    for each block:
        zeta = ZETAS[k]
        for each pair (j, j+length):
            t = zeta × r[j + length]
            r[j + length] = r[j] - t
            r[j] = r[j] + t
```

7 stages, 127 butterfly operations, 128 precomputed twiddle factors.

#### Inverse NTT (Gentleman-Sande)

The inverse NTT transforms back from NTT domain to coefficient domain:

```python
for length in [2, 4, 8, 16, 32, 64, 128]:
    for each block:
        zeta = ZETAS[k]  (used in reverse order)
        for each pair (j, j+length):
            t = r[j]
            r[j] = r[j] + r[j+length]
            r[j+length] = zeta × (r[j+length] - t)

# Final scaling: multiply all by N_INV = 3303
```

#### Basecase Multiplication

For each of 64 polynomial pairs:
```
C0 = A0×B0 + A1×B1×ζ   (mod q)
C1 = A0×B1 + A1×B0     (mod q)
```

#### Error Detection

The model includes a `poly_mul_naive()` function that performs O(n²) convolution-based multiplication. This is used to verify that the NTT-based result is mathematically identical:

```python
assert poly_mul(a, b) == poly_mul_naive(a, b)
```

## How to Use

### Generate Reference Vectors

```bash
python kyber_ntt.py
```

This:
- Computes NTT( A ), NTT( B ), basecase product, INTT, and final result
- Prints all stages and intermediate values to console
- Exports reference vectors to `TB/Ref/`:
  - `a_ntt_input.txt`, `a_ntt_output.txt`
  - `b_ntt_input.txt`, `b_ntt_output.txt`
  - `basemul_output.txt`, `basemul_output.hex`
  - `intt_output.txt`, `final_output.txt`
- Exports all data as JSON and JS for visualization tools

### Run as Standalone Demo

```bash
python kyber_ntt.py
```

The output includes a complete 256-element NTT demonstration with:
- All 128 twiddle factors (ζ array)
- Forward NTT with all 7 intermediate stages
- Inverse NTT with all stages
- Roundtrip verification: INTT(NTT(A)) == A → True/False
- Full polynomial multiplication: A × B via NTT
- NTT result vs. naive multiplication verification

### Use as Library

```python
from kyber_ntt import ntt, intt, poly_basemul, poly_mul, poly_mul_naive

a = [1, 2, 3, ..., 256]   # 256 coefficients
b = [7, 8, 9, ..., 256]

a_ntt = ntt(a)
b_ntt = ntt(b)
c_ntt = poly_basemul(a_ntt, b_ntt)
c = intt(c_ntt)

# Verify
assert c == poly_mul_naive(a, b)
```

## Parameters

```python
N = 256       # Polynomial degree
Q = 3329      # Prime modulus
N_INV = 3303  # 256^(-1) mod 3329
ROOT = 17     # Primitive 256th root of unity mod 3329
```

## How It Interacts With the RTL Design

```
Python Golden Model                 Hardware (SystemVerilog)
─────────────────────               ────────────────────────
ntt(a)                ──►           ct_butterfly × 127

poly_basemul(ntt_a,   ──►           basemul_kyber_v2 × 64
             ntt_b)

intt(c_ntt)           ──►           gs_butterfly × 127

× N_INV scaling       ──►           kyber_final_mult × 256
```

Every RTL module has a direct counterpart in the Python model. The Python model produces intermediate outputs that correspond to each RTL pipeline stage, enabling stage-by-stage debugging.

## File Outputs

When run, `kyber_ntt.py` produces:

| File | Format | Contents |
|------|--------|----------|
| `kyber_ntt_data.json` | JSON | All data in structured JSON format |
| `kyber_ntt_data.js` | JavaScript | Same data as a JS constant for web visualization |

## Extending the Golden Model

To add support for a new operation:

1. Implement the operation as a Python function in `kyber_ntt.py`
2. If it generates new reference vectors, add export code at the bottom of `__main__`
3. Run the script to verify correctness and generate vectors
4. Implement the corresponding RTL module
5. Verify RTL output matches the Python reference

The model is deliberately kept as a **single, self-contained file** for simplicity and ease of understanding. If it grows significantly, consider splitting into:
- `params.py` — Kyber parameters
- `ntt.py` — NTT/INTT operations
- `basemul.py` — Basecase multiplication
- `ref_vectors.py` — Reference vector generation
