# Kyber PQC Integration — Vortex GPGPU (Phase 2)

> Part of [Phase 2: Vortex GPGPU Integration](../README.md) — integration of CRYSTALS-Kyber hardware accelerators into the Vortex RISC-V GPGPU architecture.

## Purpose

This documentation describes the integration of **CRYSTALS-Kyber** (ML-KEM) Post-Quantum Cryptography (PQC) hardware accelerators into the **Vortex GPGPU** open-source RISC-V GPU architecture.

The documentation serves as the primary reference for engineers who need to understand, modify, extend, or maintain the Kyber PQC hardware within Vortex.

---

## Repository Overview

This repository is a fork of the [Vortex GPGPU](https://vortexgpgpu.org/) project, extended with custom hardware units that accelerate the polynomial arithmetic required by the Kyber key-encapsulation mechanism (KEM). The core NTT arithmetic modules are derived from [Phase 1](../../HW-design/Design/) of this project.

Kyber, standardized by NIST as **ML-KEM**, relies on modular polynomial multiplication in the ring R = Z_q[X]/(X^N + 1) with q = 3329, N = 256. The core operations — **Number Theoretic Transform (NTT)**, **Inverse NTT (INTT)**, and **base multiplication** — are implemented as dedicated processing elements within the Vortex ALU pipeline.

---

## Documentation Organization

```
modified_vortex_files_and_summary/
│
├── README.md                  ← You are here
├── INDEX.md                   ← File index & integration workflow
├── ARCHITECTURE.md            ← Architecture & data flow
├── CHANGE_MAP.md              ← Change mapping table
├── TIMELINE.md                ← Integration chronology
├── GLOSSARY.md                ← Terminology reference
├── DATA_FLOW.md               ← Detailed data flow
├── DEPENDENCY_GRAPH.md        ← Module dependency diagrams
├── PIPELINE_IMPACT.md         ← Pipeline timing analysis
│
└── vortex_modified_files/     ← Per-file detailed documentation (10 files)
    ├── VX_decode.md            Decoder: funct2→instruction mapping
    ├── VX_alu_unit.md          ALU top-level PE routing
    ├── VX_alu_basemul.md       Base multiplication PE wrapper
    ├── VX_alu_ct_butterfly.md  CT butterfly PE wrapper
    ├── VX_alu_gs_butterfly.md  GS butterfly PE wrapper
    ├── VX_gpu_pkg.md           Opcode definitions
    ├── VX_config.md            Verilog latency parameters
    ├── func_unit_cpp.md        SimX ALU delay computation
    ├── simx_types.md           SimX AluType enum
    └── vx_intrinsics_h.md      Kernel intrinsic API
```

---

## Reading Guide

### Recommended Reading Order

| Step | Document | For |
|------|----------|-----|
| 1 | **INDEX.md** | High-level summary of what was changed and why |
| 2 | **GLOSSARY.md** | Understand Kyber and Vortex terminology |
| 3 | **ARCHITECTURE.md** | Understand how the hardware fits together |
| 4 | **CHANGE_MAP.md** | See the full list of modifications at a glance |
| 5 | **vortex_modified_files/\*.md** | Read per-file documentation for detailed understanding |
| 6 | **DATA_FLOW.md** | Understand data movement through the pipeline |
| 7 | **DEPENDENCY_GRAPH.md** | See module interactions |
| 8 | **TIMELINE.md** | Understand the integration history |
| 9 | **PIPELINE_IMPACT.md** | Understand timing and performance implications |

### Navigation

- **[INDEX.md](INDEX.md)** — Complete file index
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — System architecture
- **[CHANGE_MAP.md](CHANGE_MAP.md)** — Change inventory
- **[TIMELINE.md](TIMELINE.md)** — Integration history
- **[GLOSSARY.md](GLOSSARY.md)** — Terminology
- **[DATA_FLOW.md](DATA_FLOW.md)** — Data movement
- **[DEPENDENCY_GRAPH.md](DEPENDENCY_GRAPH.md)** — Module dependencies
- **[PIPELINE_IMPACT.md](PIPELINE_IMPACT.md)** — Pipeline timing
- **[vortex_modified_files/](vortex_modified_files/)** — Per-file documentation

---

## Kyber Integration — At a Glance

The Kyber PQC integration adds **three new instruction types** to the Vortex GPGPU ISA:

| Instruction | Opcode | Hardware Module | Function |
|-------------|--------|-----------------|----------|
| `CT_BUTTERFLY` | `INST_ALU_CT_BF` | `ct_butterfly.sv` | Cooley-Tukey NTT butterfly: (A, B, W) → (A+B·W, A−B·W) mod q |
| `GS_BUTTERFLY` | `INST_ALU_GS_BF` | `gs_butterfly.sv` | Gentleman-Sande INTT butterfly: (A, B, W) → (A+B, (A−B)·W) mod q |
| `BASEMUL` | `INST_ALU_BASEMUL` | `basemul_kyber_v2.sv` | Base multiplication: (A0,A1,B0,B1,ζ) → (C0,C1) |

These instructions are executed by **three new processing elements** integrated into the ALU pipeline alongside the existing integer and multiply-divide units. The pipeline integration required modifications to:

- **`VX_alu_unit.sv`** — Routing logic that dispatches PQC instructions to the correct PE
- **`VX_gpu_pkg.sv`** — New opcode definitions and ALU type constants
- **`VX_config.vh`** — Latency configuration parameters for the new units

The PQC arithmetic is performed by **seven hardware modules** in `hw/rtl/pqc/`, which implement Kyber's core mathematical operations: NTT butterflies, modular reduction (Barrett), base multiplication, and final multiplication.

---

## Quick Summary

| Metric | Count |
|--------|-------|
| New PQC hardware modules | 7 |
| New ALU processing elements | 3 |
| Modified Vortex core files | 8 |
| New ISA instructions | 3 |
| PQC operation latency (min) | 2 cycles |
| PQC operation latency (max) | 3 cycles |
| Kyber modulus q | 3329 |
| Polynomial degree N | 256 |
