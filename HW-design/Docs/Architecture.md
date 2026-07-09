# Architecture Overview (Phase 1)

> Part of [Phase 1: Standalone RTL Architecture](../README.md) — this document describes the NTT pipeline architecture, module design philosophy, and Kyber parameter choices.

## What Is This Project?

This repository implements the hardware acceleration of **polynomial multiplication for CRYSTALS-Kyber**, a post-quantum cryptographic key-encapsulation mechanism (KEM) selected by NIST for standardization. The core operation is the **Number Theoretic Transform (NTT)**, which reduces polynomial multiplication from O(n^2) to O(n log n) — the same principle as the FFT but over a finite field.

## Kyber Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| n | 256 | Polynomial degree |
| q | 3329 | Prime modulus |
| $\zeta$ | 17 | Primitive 256th root of unity modulo q |
| Security levels | Kyber-512, Kyber-768, Kyber-1024 |

## High-Level System Architecture

```
                     ┌──────────────────────────────────────┐
                     │         Polynomial A (256 coeffs)    │
                     │         Polynomial B (256 coeffs)    │
                     └──────────┬────────────────┬──────────┘
                                │                │
                                ▼                ▼
                     ┌──────────────────┐  ┌──────────────────┐
                     │   NTT (CT Units) │  │   NTT (CT Units) │
                     │   7 stages       │  │   7 stages       │
                     │   127 butterflies│  │   127 butterflies│
                     └────────┬─────────┘  └────────┬─────────┘
                              │                     │
                              ▼                     ▼
                     ┌─────────────────────────────────────┐
                     │        NTT(A)     NTT(B)            │
                     │        128 pairs each               │
                     └────────────────┬────────────────────┘
                                      │
                                      ▼
                     ┌─────────────────────────────────────┐
                     │    Basecase Multiplication          │
                     │    64 pairs, zeta-weighted          │
                     │    basemul_kyber_v2 (3-cycle pipe)  │
                     └────────────────┬────────────────────┘
                                      │
                                      ▼
                     ┌─────────────────────────────────────┐
                     │    INTT (GS Units)                  │
                     │    7 stages (reverse order)         │
                     │    127 butterflies                  │
                     └────────────────┬────────────────────┘
                                      │
                                      ▼
                     ┌─────────────────────────────────────┐
                     │    Final Multiplication (×n⁻¹)      │
                     │    kyber_final_mult (1-cycle pipe)  │
                     └────────────────┬────────────────────┘
                                      │
                                      ▼
                     ┌─────────────────────────────────────┐
                     │    Result C = A · B mod (xⁿ + 1)    │
                     └─────────────────────────────────────┘
```

## Design Philosophy

### 1. Modularity
Each arithmetic operation is a standalone SystemVerilog module with a well-defined interface. The butterfly, Barrett reduction, basecase multiplication, and final scaling are independent and reusable.

### 2. Pipelining
All datapath modules are fully pipelined with registered inputs and outputs. This allows high clock frequencies and deterministic latency:

| Module | Pipeline Depth | Throughput |
|--------|---------------|------------|
| `barrett_reduction_kyber` | 1 cycle | 1 result/cycle |
| `barrett_reduction_kyber_wide` | 1 cycle | 1 result/cycle |
| `modq` | 1 cycle | 1 result/cycle |
| `ct_butterfly` | 2 cycles | 1 butterfly/cycle |
| `gs_butterfly` | 2 cycles | 1 butterfly/cycle |
| `basemul_kyber_v2` | 3 cycles | 1 pair/cycle |
| `kyber_final_mult` | 1 cycle | 1 element/cycle |

### 3. Constant-Time Operations
Critical for cryptographic implementations: all reductions use bit-masking and constant-time selection (`mask ? a : b`) rather than conditional branches, preventing timing side-channel leakage.

### 4. Multiplier-Free Arithmetic
Wherever possible, multiplications by constants (μ, q, 3303, etc.) are decomposed into shift-add-subtract sequences. This eliminates the need for DSP slices or large multiplier primitives, making the design suitable for resource-constrained FPGAs.

## Module Hierarchy

```
kyber_final_mult          ← Top-level polynomial multiplier
├── basemul_kyber_v2 (×64)    Basecase multiplication
│   ├── barrett_reduction_kyber_wide (×2)  36-bit Barrett
├── ct_butterfly (×127)       Forward NTT butterflies
│   ├── barrett_reduction_kyber (×1)   24-bit Barrett
│   └── modq (×2)              Conditional reduction
├── gs_butterfly (×127)       Inverse NTT butterflies
│   ├── modq (×2)              Conditional reduction
│   └── barrett_reduction_kyber (×1)   24-bit Barrett
```

## The NTT in Kyber

Kyber uses a **negative-wrapped convolution** NTT. Unlike a full NTT that reduces to degree-1 polynomials, Kyber's NTT stops at degree-2 polynomials (128 pairs of 2 coefficients each). This is why the basecase multiplication step is needed — it performs the final pairwise multiplication in the NTT domain.

The NTT has 7 stages (log2(128) = 7), consuming 127 twiddle factors total:

| Stage | Half-Length | Butterflies | Twiddle Indices |
|-------|-------------|-------------|-----------------|
| 0 | 128 | 1 | W[1] |
| 1 | 64 | 2 | W[2..3] |
| 2 | 32 | 4 | W[4..7] |
| 3 | 16 | 8 | W[8..15] |
| 4 | 8 | 16 | W[16..31] |
| 5 | 4 | 32 | W[32..63] |
| 6 | 2 | 64 | W[64..127] |

## Memory and Data Flow

Polynomial coefficients are 12-bit values in the range [0, q-1] = [0, 3328]. All datapaths maintain this width internally, with carefully managed bit growth at intermediate stages:

- Raw product of two 12-bit values: **24 bits** (handled by standard Barrett)
- Accumulated sum of three 24-bit values with zeta multiplication: **36 bits** (handled by wide Barrett)
- Butterfly sum/difference before reduction: requires **16-bit signed** arithmetic

## Target Platforms

The design is FPGA-agnostic RTL, synthesizable on any platform supporting SystemVerilog. The pure shift-add-subtract arithmetic means it does not require DSP slices, making it suitable for:
- Xilinx 7-series and UltraScale
- Intel/Altera Cyclone and Stratix
- Lattice ECP5 and Nexus
- Custom ASIC flows
