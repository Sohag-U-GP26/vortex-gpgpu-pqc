# Design — RTL Implementation (Phase 1)

> Part of [Phase 1: Standalone RTL Architecture](../README.md) — the hardware accelerator modules for CRYSTALS-Kyber polynomial multiplication.

## Purpose

This directory contains all SystemVerilog RTL modules implementing the hardware accelerator for CRYSTALS-Kyber polynomial multiplication. Each module is a self-contained, pipelined, constant-time hardware block that performs one operation in the NTT-based multiplication pipeline.

## Module Architecture

```
┌──────────────────────────────────────────────────────┐
│              Module Dependency Stack                 │
├──────────────────────────────────────────────────────┤
│                                                      │
│  kyber_final_mult                                    │
│  ┌─────────────────────┐   ┌──────────────────────┐  │
│  │ barrett_reduction   │   │ barrett_reduction    │  │
│  │ _kyber (24-bit)     │   │ _kyber_wide (36-bit) │  │
│  └─────────────────────┘   └──────────────────────┘  │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │ modq.sv — constant-time conditional reduce   │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │ ct_butterfly.sv  —  Forward NTT butterfly    │    │
│  │ gs_butterfly.sv  —  Inverse NTT butterfly    │    │
│  │ basemul_kyber_v2.sv — Basecase multiply      │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

## Module Descriptions

### `modq.sv` — Conditional Reduction

**Operation**: Given a 16-bit signed input in [-3328, 6656], reduce to [0, 3328].

**Why needed**: Butterfly sum/difference operations produce values outside [0, q-1]. This module brings them back using constant-time mask-based selection.

**Design**: Two-stage conditional correction:
1. If negative, add q (using mask)
2. If still > 3328, subtract q (using mask)

**Pipeline**: 1 cycle | **Throughput**: 1 element/cycle

---

### `barrett_reduction_kyber.sv` — 24-bit Barrett Reduction

**Operation**: Compute `C mod q` for 24-bit input C < q² ≈ 11M, where q = 3329.

**Algorithm**: Standard Barrett reduction with precomputed μ = floor(2^12 / q) = 5039.

```
μ = 5039 = 4096 + 1024 - 64 - 16 - 1
     C2 = C × μ          (shift-add-subtract)
     C3 = C2 >> 24       (quotient estimate)
     C4 = C3 × q         (shift-add-subtract)
     C5 = C - C4         (remainder estimate, in [0, 2q))
     P  = C5 ≥ q ? C5-q : C5   (constant-time mask)
```

**Why needed**: The core reduction primitive used in butterfly and final scaling modules.

**Pipeline**: 1 cycle | **Throughput**: 1 element/cycle

---

### `barrett_reduction_kyber_wide.sv` — 36-bit Barrett Reduction

**Operation**: Compute `C mod q` for 36-bit input (used when inputs exceed q², such as A1·B1·ζ products).

```
μ = floor(2^36 / q) = 20,642,678
  = 2^24 + 2^22 - 2^18 - 2^16 - 2^10 - 2^7 - 2^3 - 2^1
```

**Why needed**: In `basemul_kyber_v2`, raw products accumulate to 36 bits. Standard 24-bit Barrett cannot handle this range.

**Pipeline**: 1 cycle | **Throughput**: 1 element/cycle

---

### `ct_butterfly.sv` — Cooley-Tukey Butterfly (Forward NTT)

**Operation**: Compute the NTT butterfly for Kyber:
```
A' = (A + B × W) mod q
B' = (A - B × W) mod q
```

**Architecture**:
```
Stage 1: B × W → Barrett reduction → BW_mod
Stage 2: A ± BW_mod → modq (×2) → A', B'
```

**Why needed**: The forward NTT decomposes polynomials into the NTT domain where multiplication becomes coefficient-wise.

**Pipeline**: 2 cycles | **Throughput**: 1 butterfly/cycle

**Twiddle factors**: W[k] = ζ^bit_rev7(k) mod q for k = 1..127. The 127 twiddle factors are documented in the module header.

---

### `gs_butterfly.sv` — Gentleman-Sande Butterfly (Inverse NTT)

**Operation**: Compute the inverse NTT butterfly:
```
A' = (A + B) mod q
B' = (A - B) × W mod q
```

**Architecture**:
```
Stage 1: A ± B → modq (×2) → sum_mod, diff_mod
Stage 2: diff_mod × W → Barrett reduction → B'
```

**Note**: The INTT module includes a pipeline alignment fix for back-to-back valid_in scenarios — a second pipeline register (`A_out_reg2`) captures the A output precisely when barrett_valid fires, preventing overwrite by subsequent butterfly operations.

**Pipeline**: 2 cycles | **Throughput**: 1 butterfly/cycle

---

### `basemul_kyber_v2.sv` — Basecase Polynomial Multiplication

**Operation**: Multiply two degree-1 polynomials modulo (X² - ζ):
```
C0 = A0·B0 + A1·B1·ζ   (mod q)
C1 = A0·B1 + A1·B0     (mod q)
```

**Key innovation (v2)**: Instead of reducing intermediate products after each multiplication, accumulate all raw products first, then apply one wide Barrett reduction at the end.

**Pipeline**: 3 cycles
```
Cycle 0 (comb): 4 parallel multiplications (m00, m11, m01, m10)
Cycle 1 (FF):   Register products + m11×ζ (36-bit)
Cycle 2 (FF):   Register raw sums + assemble raw_C0
Cycle 3 (FF):   Wide Barrett reduction → final C0, C1
```

**Why needed**: After NTT, polynomials are in degree-2 "pair" representation. Pairwise (basecase) multiplication in the NTT domain replaces full polynomial multiplication.

---

### `kyber_final_mult.sv` — Final Scaling After INTT

**Operation**: Multiply each coefficient by n⁻¹ = 3303 mod q:
```
out = (in × 3303) mod 3329
```

**Multiplier-free decomposition**:
```
3303 = 4096 - 512 - 256 - 16 - 8 - 1
     = (1<<12) - (1<<9) - (1<<8) - (1<<4) - (1<<3) - 1
```

**Pipeline**: 1 cycle (combinational shift-add → Barrett FF)

**Why needed**: The INTT produces results scaled by n. FIPS-203 requires multiplication by n⁻¹ mod q to recover the original product.

---

## Dataflow and Scalability

### Data Widths Through the Pipeline

```
Polynomial coefficients: 12 bits  (0..3328)

Forward NTT:
  12-bit × 12-bit × twiddle → 24-bit → Barrett → 12-bit

Basecase multiplication:
  12-bit × 12-bit → 24-bit product
  24-bit × 12-bit (zeta) → 36-bit
  36-bit → wide Barrett → 12-bit

Inverse NTT (reverse order):
  12-bit ± 12-bit → 16-bit signed → modq → 12-bit
  12-bit × 12-bit twiddle → 24-bit → Barrett → 12-bit

Final multiply:
  12-bit × 3303 → 24-bit → Barrett → 12-bit
```

### Scalability

All modules are parameterized by q (default 3329), making them adaptable to other lattice-based crypto schemes with different moduli. The barrel-shift-add arithmetic scales naturally with wider datapaths.

## Dependency Overview

```
kyber_final_mult
  └── barrett_reduction_kyber

basemul_kyber_v2
  ├── barrett_reduction_kyber_wide (×2)

ct_butterfly
  ├── barrett_reduction_kyber
  └── modq (×2)

gs_butterfly
  ├── modq (×2)
  └── barrett_reduction_kyber

barrett_reduction_kyber       (standalone)
barrett_reduction_kyber_wide  (standalone)
modq                          (standalone)
```

## Coding Conventions

All modules in this directory follow these coding conventions:

- `lowercase_snake_case` for module and signal names
- 4-space indentation
- Labeled `always_comb` / `always_ff` blocks
- Constant-time mask-based selection
- Shift-add-subtract for constant multiplications
- Documented pipeline depths and data widths
- Active-low reset (`rst_n`), synchronous, asserted low
- Pipeline registers for both data and valid signals

## Future Extensions

- **FSM controller**: Add a top-level finite state machine to sequence NTT → basecase → INTT → final scaling for complete polynomial multiplication
- **DMA interface**: Add AXI-stream or similar interface for loading coefficients from memory
- **Multi-poly support**: Pipeline multiple polynomial multiplications concurrently
- **DSP slice inference**: Optionally use DSP slices for wider multipliers on FPGAs that have them
- **Power analysis**: Add clock gating and operand isolation for lower power
- **Formal properties**: Add SystemVerilog Assertions (SVA) for formal verification
