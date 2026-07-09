# Phase 2: Vortex GPGPU Integration

NTT-based CRYSTALS-Kyber (ML-KEM) polynomial multiplication accelerated on the Vortex RISC-V GPGPU with custom instructions and hardware pipelines.

<div align="center">
  <p><em>Part of the <a href="../README.md">CRYSTALS-Kyber Hardware Accelerator</a> project</em></p>
</div>

## Table of Contents

- [About this Project](#about-this-project)
- [Relationship to Phase 1](#relationship-to-phase-1)
- [Overview](#overview)
- [Relationship to Vortex](#relationship-to-vortex)
- [Features](#features)
- [Architecture Overview](#architecture-overview)
  - [Custom Instruction Pipeline](#custom-instruction-pipeline)
- [Performance](#performance)
- [Repository Structure](#repository-structure)

## About this Project

Vortex-PQC is a research project built on top of the open-source [Vortex GPGPU](https://github.com/vortexgpgpu/vortex) architecture. The original Vortex project provides a RISC-V SIMT GPU research platform, offering a complete hardware/software stack for experimenting with GPGPU compute on RISC-V hardware.

This work extends Vortex with custom hardware accelerators for CRYSTALS-Kyber (ML-KEM), a post-quantum key-encapsulation mechanism. The objective is to exploit Vortex's SIMT parallelism to accelerate the Number Theoretic Transform (NTT), the computational core of Kyber's polynomial multiplication, through dedicated custom instructions and hardware pipelines rather than relying purely on software execution.

This repository is **not** a replacement for the original Vortex repository, and it is **not** a complete mirror of it. It contains only the files required to build, simulate, and evaluate the Kyber hardware/software integration described here. Readers who need the full Vortex framework — including its complete set of backends, simulators, and runtime components — should refer to the [original Vortex GPGPU repository](https://github.com/vortexgpgpu/vortex).

## Relationship to Phase 1

This directory represents **Phase 2** of a two-phase engineering project. The NTT arithmetic modules (butterflies, Barrett reduction, basecase multiplication) were originally designed, implemented, and verified in Phase 1 as standalone SystemVerilog components. Phase 2 takes those verified modules, wraps them as ALU processing elements, and integrates them into the Vortex GPGPU pipeline with custom RISC-V instructions.

The hardware pipeline modules in `hw/rtl/pqc/` are direct descendants of the Phase 1 RTL in [`HW-design/Design/`](../HW-design/Design/). For detailed module-level documentation, pipeline depths, and the original verification environment, see the [Phase 1 README](../HW-design/README.md).

## Overview

Vortex-PQC implements polynomial multiplication over the Kyber ring `Z_3329[x]/(x^256 + 1)` on the Vortex GPGPU — a 64-bit RISC-V SIMT processor. This work replaces the original sequential implementation with a **concurrent dual-NTT** strategy: 256 threads simultaneously transform both input polynomials (`A` and `B`) in the forward NTT, then perform point-wise multiplication (basemul), inverse NTT, and final scaling.

Three custom RISC-V instructions — `vx_ct_butterfly`, `vx_gs_butterfly`, and `vx_basemul` — execute in dedicated SystemVerilog pipelines with 2–3 cycle latency. The design is verified against a software reference and validated on both the SimX (C++ functional) and RTLsim (Verilator) simulators.

## Relationship to Vortex

This repository is derived from the original Vortex GPGPU project. It includes only the files necessary for the Kyber accelerator integration described in this README: the modified kernel sources, the custom hardware pipelines, the supporting runtime headers, and the regression tests used to validate the design.

The following categories of content from the upstream Vortex repository have been intentionally omitted, as they are unrelated to this work:

- Hardware backends not used by this project
- Runtime components outside the scope of the Kyber integration
- Experimental modules under active development upstream
- Optional simulators not required for SimX or RTLsim validation
- Third-party packages and dependencies not exercised by this design

If you need the complete Vortex framework — including the full range of backends, simulators, and tooling — please refer to the [original Vortex GPGPU repository](https://github.com/vortexgpgpu/vortex).

## Features

- **Kyber ML-KEM polynomial multiplication** — ring `Z_3329[x]/(x^256 + 1)` (N = 256, q = 3329)
- **Concurrent NTT** — 256 threads run NTT(A) and NTT(B) in parallel (threads 0–127 on A, 128–255 on B)
- **Custom RISC-V instructions** — `vx_ct_butterfly`, `vx_gs_butterfly`, `vx_basemul` with R4-type encoding in custom-0 opcode space
- **Dedicated hardware pipelines** — 2-cycle CT/GS butterflies, 3-cycle basemul, all fully pipelined
- **Barrett reduction** — optimized shift/add multiply by 3303 for post-INTT scaling
- **Dual simulation** — verified on SimX (C++ functional) and RTLsim (Verilator RTL)
- **2816 custom instructions** per kernel launch with `__syncthreads()` barriers between stages

## Architecture Overview

```
              ┌──────────────────────────────────┐
              │     HOST (main.cpp)              │
              │  Upload A, B, twiddles, ζ        │
              │  Launch 1 block × 256 threads    │
              └────────────────┬─────────────────┘
                               │
                               ▼
                ┌─────────────────────────────────────┐
                │   GPU KERNEL (256 threads)          │
                │                                     │
                │  ┌─── NTT(A) ←── threads 0-127      │
                │  │   (7 layers CT butterfly)        │
                │  │                                  │
                │  │   ── concurrent ──               │
                │  │                                  │
                │  └─── NTT(B) ←── threads 128-255    │
                │       (7 layers CT butterfly)       │
                │                                     │
                │     __syncthreads() × 7             │
                │                                     │
                │  ┌─── BASEMUL ←── threads 0-127     │
                │  │   128 point-wise mults           │
                │  │   (with twisting factor ζ)       │
                │  │                                  │
                │     __syncthreads()                 │
                │                                     │
                │  ┌─── INTT ←── threads 0-127
                │  │   (7 layers GS butterfly)        │
                │  │                                  │
                │     __syncthreads() × 7             │
                │                                     │
                │  ┌─── SCALE(×3303) ←── threads 0-127
                │  │   2 coeffs per thread            │
                │  │   (Barrett reduction)            │
                └──────┬──────────────────────────────┘
                       │
                       ▼
                ┌───────────────────────────────┐
                │   RESULT C = A·B mod (x²⁵⁶+1) │
                │   256 coefficients, q=3329    │
                │   Verified: PASSED            │
                └───────────────────────────────┘
```

### Custom Instruction Pipeline

| Instruction | Pipeline Stages | Latency | Hardware Module |
|---|---|---|---|
| `vx_ct_butterfly(A, B, W)` | Barrett(B·W) → modq(A±BW) | 2 cycles | `ct_butterfly.sv` |
| `vx_gs_butterfly(A, B, W)` | modq(A±B) → Barrett(diff·W) | 2 cycles | `gs_butterfly.sv` |
| `vx_basemul(A0,A1,B0,B1,ζ)` | 4 multipliers → accumulate → Wide Barrett | 3 cycles | `basemul_kyber_v2.sv` |
| Final scale `val × 3303 mod q` | Shift-add ×3303 → Barrett | 1 cycle | `kyber_final_mult.sv` |

## Performance

| Metric | polymul (sequential) | kyber (concurrent NTT) | Improvement |
|---|---|---|---|
| Instructions | 282,976 | 192,961 | 1.47× fewer |
| Cycles (rtlsim) | 610,729 | 180,951 | 3.38× faster |
| IPC (rtlsim) | 0.46 | 1.07 | 2.30× higher |
| Kernel exec cycles | — | 37,800 | — |

The concurrent NTT strategy doubles thread utilization during the forward transform, significantly improving IPC and reducing total cycles. See [docs/performance.md](docs/performance.md) for detailed analysis.

## Repository Structure

This repository contains the hardware RTL, kernel code, and documentation for the Kyber PQC integration. It is a curated subset of the original Vortex GPGPU project — see [Relationship to Vortex](#relationship-to-vortex) for details.

```
Vortex-PQC-integration/
├── README.md                              # This file
├── hw/
│   ├── VX_config.h                        # C config macros (auto-generated)
│   ├── VX_types.h                         # C type/CSR macros (auto-generated)
│   └── rtl/
│       ├── VX_config.vh                   # Verilog config defines
│       ├── VX_define.vh                   # Verilog common defines
│       ├── VX_platform.vh                 # Verilog platform defines
│       ├── VX_types.vh                    # Verilog type/CSR defines
│       └── pqc/
│           ├── ct_butterfly.sv            # Cooley-Tukey butterfly
│           ├── gs_butterfly.sv            # Gentleman-Sande butterfly
│           ├── basemul_kyber_v2.sv        # Base-case polynomial multiply
│           ├── barrett_reduction_kyber.sv  # 24-bit Barrett reduction
│           ├── barrett_reduction_kyber_wide.sv  # 36-bit Wide Barrett
│           ├── kyber_final_mult.sv        # Final scaling (×3303)
│           └── modq.sv                    # Conditional mod q
├── kernel/
│   └── include/
│       └── vx_intrinsics.h                # Custom instruction intrinsics
├── tests/
│   └── regression/
│       ├── kyber/                         # Kyber test suite
│       │   ├── kernel.cpp                 # GPU kernel source
│       │   ├── main.cpp                   # Host driver
│       │   ├── common.h                   # Shared constants + twiddles
│       │   ├── Makefile                   # Build rules
│       │   └── RUN.md                     # Build & run instructions
│       └── polymul/                       # Original polymul test for baseline
│           ├── kernel.cpp
│           ├── main.cpp
│           ├── common.h
│           ├── Makefile
│           └── overall_process.md
├── docs/                                  # Documentation and test outputs
│   ├── README.md                          # Doc index
│   ├── architecture_and_implementation.md # Detailed architecture document
│   ├── performance.md                     # Performance analysis
│   ├── performance_comparison.md          # Performance comparison table
│   ├── performance_summary.md             # Structured perf summary
│   ├── running.md                         # Run instructions
│   ├── results.md                         # Test results
│   ├── kyber_ntt_architecture.md          # NTT architecture diagram
│   ├── test_output.log                    # Full test output
│   └── test_output.md                     # Formatted test output
└── modified_vortex_files_and_summary/     # Integration documentation
    ├── README.md                          # Index
    ├── INDEX.md                           # File index
    ├── ARCHITECTURE.md                    # System architecture
    ├── CHANGE_MAP.md                      # Change inventory
    ├── GLOSSARY.md                        # Terminology
    ├── TIMELINE.md                        # Integration history
    ├── DATA_FLOW.md                       # Data movement diagrams
    ├── DEPENDENCY_GRAPH.md                # Module dependencies
    ├── PIPELINE_IMPACT.md                 # Pipeline timing analysis
    └── vortex_modified_files/             # Per-file documentation
        ├── VX_decode.md
        ├── VX_alu_unit.md
        ├── VX_alu_basemul.md
        ├── VX_alu_ct_butterfly.md
        ├── VX_alu_gs_butterfly.md
        ├── VX_gpu_pkg.md
        ├── VX_config.md
        ├── func_unit_cpp.md
        ├── simx_types.md
        └── vx_intrinsics_h.md
```

## License and Acknowledgments

For repository-wide license information, please refer to the [repository root README](../README.md).

Vortex-PQC is built upon and incorporates portions of the open-source [Vortex GPGPU](https://github.com/vortexgpgpu/vortex) project. It includes both reused Vortex components and original hardware/software extensions developed for the integration of CRYSTALS-Kyber acceleration.
