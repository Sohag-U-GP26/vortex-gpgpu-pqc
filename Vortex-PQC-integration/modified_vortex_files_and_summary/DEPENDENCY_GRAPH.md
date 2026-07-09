# Dependency Graph — Kyber PQC Integration

## Module Dependency Diagram

```mermaid
graph TD
    subgraph "Kernel Space"
        vx_intrinsics["vx_intrinsics.h<br/>(vx_ct_butterfly/GS/basemul)"]
    end

    subgraph "Decode"
        VX_decode["VX_decode.sv<br/>(funct2→op_type)"]
    end

    subgraph "ALU Pipeline"
        VX_alu_unit["VX_alu_unit.sv"]
        VX_alu_ct_pe["VX_alu_ct_butterfly"]
        VX_alu_gs_pe["VX_alu_gs_butterfly"]
        VX_alu_bm_pe["VX_alu_basemul"]
    end

    subgraph "PQC Core Modules"
        ct_butterfly
        gs_butterfly
        basemul_kyber_v2
        kyber_final_mult
    end

    subgraph "Reduction Primitives"
        barrett_reduction_kyber
        barrett_reduction_kyber_wide
        modq
    end

    subgraph "Configuration"
        VX_config_vh["VX_config.vh (LATENCY_*)"]
        VX_gpu_pkg["VX_gpu_pkg.sv (INST_ALU_*)"]
    end

    subgraph "SimX Simulator"
        types_h["simx/types.h (AluType)"]
        func_cpp["simx/func_unit.cpp (delay)"]
        VX_config_h["VX_config.h (LATENCY_* C++)"]
    end

    vx_intrinsics --> VX_decode
    VX_gpu_pkg --> VX_decode
    VX_decode --> VX_alu_unit
    VX_gpu_pkg --> VX_alu_unit
    VX_alu_unit --> VX_alu_ct_pe
    VX_alu_unit --> VX_alu_gs_pe
    VX_alu_unit --> VX_alu_bm_pe
    VX_alu_ct_pe --> ct_butterfly
    VX_alu_gs_pe --> gs_butterfly
    VX_alu_bm_pe --> basemul_kyber_v2
    ct_butterfly --> barrett_reduction_kyber
    ct_butterfly --> modq
    gs_butterfly --> barrett_reduction_kyber
    gs_butterfly --> modq
    basemul_kyber_v2 --> barrett_reduction_kyber_wide
    kyber_final_mult --> barrett_reduction_kyber
    VX_config_vh --> VX_alu_ct_pe
    VX_config_vh --> VX_alu_gs_pe
    VX_config_vh --> VX_alu_bm_pe
    VX_config_vh -.-> VX_config_h
    VX_config_h --> types_h
    VX_config_h --> func_cpp
    types_h --> func_cpp
```

## Dependency Table

| Module | Depends On | Used By |
|--------|-----------|---------|
| `barrett_reduction_kyber` | — | `ct_butterfly`, `gs_butterfly`, `kyber_final_mult` |
| `barrett_reduction_kyber_wide` | — | `basemul_kyber_v2` |
| `modq` | — | `ct_butterfly`, `gs_butterfly` |
| `ct_butterfly` | `barrett_reduction_kyber`, `modq` | `VX_alu_ct_butterfly` |
| `gs_butterfly` | `barrett_reduction_kyber`, `modq` | `VX_alu_gs_butterfly` |
| `basemul_kyber_v2` | `barrett_reduction_kyber_wide` | `VX_alu_basemul` |
| `kyber_final_mult` | `barrett_reduction_kyber` | Standalone (part of PQC lib) |
| `VX_alu_ct_butterfly` | `ct_butterfly`, `VX_config.vh` | `VX_alu_unit` |
| `VX_alu_gs_butterfly` | `gs_butterfly`, `VX_config.vh` | `VX_alu_unit` |
| `VX_alu_basemul` | `basemul_kyber_v2`, `VX_config.vh` | `VX_alu_unit` |
| `VX_config.vh` | — | PE wrappers, PE delay |
| `VX_config.h` | — | `types.h`, `func_unit.cpp` |
| `VX_gpu_pkg.sv` | — | `VX_decode.sv`, `VX_alu_unit` |
| `VX_decode.sv` | `VX_gpu_pkg.sv` | Vortex decode stage |
| `VX_alu_unit` | All 3 PE wrappers, `VX_gpu_pkg.sv` | Vortex pipeline |
| `types.h` | `VX_config.h` | `func_unit.cpp` |
| `func_unit.cpp` | `types.h`, `VX_config.h` | SimX simulation |
| `vx_intrinsics.h` | — | GPU kernel code |

## Full Hierarchical View

```
Kernel Space
└── vx_intrinsics.h (vx_ct_butterfly, vx_gs_butterfly, vx_basemul)
    │
    ▼
Decode Stage
└── VX_decode.sv (funct2 decode → INST_ALU_CT_BF/GS_BF/BASEMUL)
    │
    ▼
ALU Pipeline
└── VX_alu_unit
    ├── VX_alu_ct_butterfly
    │   └── ct_butterfly
    │       ├── barrett_reduction_kyber
    │       └── modq
    ├── VX_alu_gs_butterfly
    │   └── gs_butterfly
    │       ├── barrett_reduction_kyber
    │       └── modq
    └── VX_alu_basemul
        └── basemul_kyber_v2
            └── barrett_reduction_kyber_wide

Configuration
├── VX_config.vh (Verilog) → PE wrappers
├── VX_config.h (C++) → SimX
└── VX_gpu_pkg.sv → Decode + ALU Unit

SimX Simulation
├── types.h (AluType enum)
└── func_unit.cpp (delay computation)
```

There are no circular dependencies. The dependency graph is a DAG rooted at `vx_intrinsics.h` (kernel) and `VX_decode.sv` (hardware), with leaf nodes being the primitive modules (`barrett_reduction_kyber`, `barrett_reduction_kyber_wide`, `modq`).
