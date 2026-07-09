# Index — Kyber PQC Integration in Vortex

## High-Level Summary

The Kyber PQC integration adds **three custom RISC-V instructions** to the Vortex GPGPU architecture, executed by **three new processing elements** in the ALU pipeline. These PEs perform NTT butterfly operations, INTT butterfly operations, and base polynomial multiplication — the core arithmetic primitives required for Kyber (NIST ML-KEM).

The integration spans **19 files** across seven layers: ALU pipeline, PQC arithmetic, configuration, simulation, kernel intrinsics, build system, and tests.

---

## Complete List of All Modified/Created Files

### Category A — ALU Pipeline Integration (4 files)

| # | File | Path | Status |
|---|------|------|--------|
| 1 | `VX_decode.sv` | `hw/rtl/core/VX_decode.sv` | Modified |
| 2 | `VX_alu_unit.sv` | `hw/rtl/core/VX_alu_unit.sv` | Modified |
| 3 | `VX_gpu_pkg.sv` | `hw/rtl/VX_gpu_pkg.sv` | Modified |
| 4 | `VX_config.vh` | `hw/rtl/VX_config.vh` | Modified |

### Category B — New ALU Processing Elements (3 files)

| # | File | Path | Status |
|---|------|------|--------|
| 5 | `VX_alu_basemul.sv` | `hw/rtl/core/VX_alu_basemul.sv` | New |
| 6 | `VX_alu_ct_butterfly.sv` | `hw/rtl/core/VX_alu_ct_butterfly.sv` | New |
| 7 | `VX_alu_gs_butterfly.sv` | `hw/rtl/core/VX_alu_gs_butterfly.sv` | New |

### Category C — PQC Arithmetic Modules (7 files)

| # | File | Path | Status |
|---|------|------|--------|
| 8 | `ct_butterfly.sv` | `hw/rtl/pqc/ct_butterfly.sv` | New |
| 9 | `gs_butterfly.sv` | `hw/rtl/pqc/gs_butterfly.sv` | New |
| 10 | `basemul_kyber_v2.sv` | `hw/rtl/pqc/basemul_kyber_v2.sv` | New |
| 11 | `barrett_reduction_kyber.sv` | `hw/rtl/pqc/barrett_reduction_kyber.sv` | New |
| 12 | `barrett_reduction_kyber_wide.sv` | `hw/rtl/pqc/barrett_reduction_kyber_wide.sv` | New |
| 13 | `kyber_final_mult.sv` | `hw/rtl/pqc/kyber_final_mult.sv` | New |
| 14 | `modq.sv` | `hw/rtl/pqc/modq.sv` | New |

### Category D — Configuration (C++ SimX header) (1 file)

| # | File | Path | Status |
|---|------|------|--------|
| 15 | `VX_config.h` | `hw/VX_config.h` | Modified |

### Category E — SimX Functional Simulator (2 files)

| # | File | Path | Status |
|---|------|------|--------|
| 16 | `types.h` | `sim/simx/types.h` | Modified |
| 17 | `func_unit.cpp` | `sim/simx/func_unit.cpp` | Modified |

### Category F — Kernel Intrinsics (1 file)

| # | File | Path | Status |
|---|------|------|--------|
| 18 | `vx_intrinsics.h` | `kernel/include/vx_intrinsics.h` | Modified |

### Category G — Build System (1 file)

| # | File | Path | Status |
|---|------|------|--------|
| 19 | `Makefile` | `sim/rtlsim/Makefile` | Modified |

---

## File Descriptions

### RTL: ALU Pipeline Integration

| File | Role |
|------|------|
| `VX_decode.sv` | Decodes PQC instructions from RISC-V custom-0 space (funct2 selects op) |
| `VX_alu_unit.sv` | Top-level ALU unit. Routes PQC instructions to the correct PE. |
| `VX_gpu_pkg.sv` | Opcode definitions: `INST_ALU_CT_BF`, `INST_ALU_GS_BF`, `INST_ALU_BASEMUL` |
| `VX_config.vh` | Verilog latency config: `LATENCY_CT_BF=2`, `LATENCY_GS_BF=2`, `LATENCY_BASEMUL=3` |

### RTL: ALU PE Wrappers

| File | Latency | Function |
|------|---------|----------|
| `VX_alu_ct_butterfly` | 2 cycles | Wraps `ct_butterfly.sv` with Vortex pipeline interface |
| `VX_alu_gs_butterfly` | 2 cycles | Wraps `gs_butterfly.sv` with Vortex pipeline interface |
| `VX_alu_basemul` | 3 cycles | Wraps `basemul_kyber_v2.sv` with Vortex pipeline interface |

### RTL: PQC Arithmetic Modules

| File | Function |
|------|----------|
| `ct_butterfly.sv` | Cooley-Tukey NTT butterfly: A'=A+BW, B'=A−BW mod q |
| `gs_butterfly.sv` | Gentleman-Sande INTT butterfly: A'=A+B, B'=(A−B)W mod q |
| `basemul_kyber_v2.sv` | Base multiplication: C0=A0·B0+A1·B1·ζ, C1=A0·B1+A1·B0 mod q |
| `barrett_reduction_kyber.sv` | Barrett reduction 24-bit→12-bit mod q |
| `barrett_reduction_kyber_wide.sv` | Barrett reduction 36-bit→12-bit mod q |
| `kyber_final_mult.sv` | Final multiply by 3303 mod q (post-INTT normalization) |
| `modq.sv` | Conditional add/sub correction to [0, q-1] |

### C++: SimX Simulator Support

| File | Role |
|------|------|
| `VX_config.h` | C++ latency defines matching Verilog config |
| `types.h` | `AluType::CT_BF`, `AluType::GS_BF`, `AluType::BASEMUL` enum values |
| `func_unit.cpp` | Delay computation: returns `LATENCY_CT_BF`/`LATENCY_GS_BF`/`LATENCY_BASEMUL` |

### C: Kernel Intrinsic API

| File | Role |
|------|------|
| `vx_intrinsics.h` | `vx_ct_butterfly()`, `vx_gs_butterfly()`, `vx_basemul()` inline asm wrappers |

### Build System

| File | Role |
|------|------|
| `sim/rtlsim/Makefile` | Added `-I$(RTL_DIR)/pqc` include path for Verilator |

---

## Integration Workflow

```
1. Kernel Code (vx_intrinsics.h)
   vx_ct_butterfly(A, B, W)  →  .insn r4 CUSTOM0, 0, 0, rd, rs1, rs2, rs3
   │
   ▼
2. Instruction Decode (VX_decode.sv)
   funct2=00 → op_type=INST_ALU_CT_BF, ex_type=EX_ALU
   │
   ▼
3. ALU Dispatch (VX_alu_unit.sv)
   pe_select: INST_ALU_CT_BF → PE_IDX_CTBF
   │
   ▼
4. ALU PE Execution (VX_alu_ct_butterfly → ct_butterfly)
   A'=A+BW mod q, B'=A−BW mod q  (2 cycles)
   │
   ▼
5. Result Commit (standard Vortex commit path)
   rd = {A'[15:0], B'[15:0]}
```

---

## Detailed Documentation

| File | Documentation |
|------|---------------|
| VX_decode.sv | [files/VX_decode.md](vortex_modified_files/VX_decode.md) |
| VX_alu_unit.sv | [files/VX_alu_unit.md](vortex_modified_files/VX_alu_unit.md) |
| VX_gpu_pkg.sv | [files/VX_gpu_pkg.md](vortex_modified_files/VX_gpu_pkg.md) |
| VX_config.vh | [files/VX_config.md](vortex_modified_files/VX_config.md) |
| VX_alu_ct_butterfly.sv | [files/VX_alu_ct_butterfly.md](vortex_modified_files/VX_alu_ct_butterfly.md) |
| VX_alu_gs_butterfly.sv | [files/VX_alu_gs_butterfly.md](vortex_modified_files/VX_alu_gs_butterfly.md) |
| VX_alu_basemul.sv | [files/VX_alu_basemul.md](vortex_modified_files/VX_alu_basemul.md) |
| ct_butterfly.sv | [files/ct_butterfly.md](vortex_modified_files/ct_butterfly.md) |
| gs_butterfly.sv | [files/gs_butterfly.md](vortex_modified_files/gs_butterfly.md) |
| basemul_kyber_v2.sv | [files/basemul_kyber_v2.md](vortex_modified_files/basemul_kyber_v2.md) |
| barrett_reduction_kyber.sv | [files/barrett_reduction_kyber.md](vortex_modified_files/barrett_reduction_kyber.md) |
| barrett_reduction_kyber_wide.sv | [files/barrett_reduction_kyber_wide.md](vortex_modified_files/barrett_reduction_kyber_wide.md) |
| kyber_final_mult.sv | [files/kyber_final_mult.md](vortex_modified_files/kyber_final_mult.md) |
| modq.sv | [files/modq.md](vortex_modified_files/modq.md) |
| VX_config.h | [files/VX_config_h.md](vortex_modified_files/VX_config_h.md) |
| func_unit.cpp | [files/func_unit_cpp.md](vortex_modified_files/func_unit_cpp.md) |
| types.h | [files/simx_types.md](vortex_modified_files/simx_types.md) |
| vx_intrinsics.h | [files/vx_intrinsics_h.md](vortex_modified_files/vx_intrinsics_h.md) |

---

## File Categories

| Category | Files | Purpose |
|----------|-------|---------|
| **Decode** | VX_decode.sv | Instruction → op_type mapping |
| **Top-level integration** | VX_alu_unit.sv, VX_gpu_pkg.sv, VX_config.vh | PE routing, opcodes, latency config |
| **ALU PE wrappers** | VX_alu_ct_butterfly, VX_alu_gs_butterfly, VX_alu_basemul | Pipeline interface adapters |
| **PQC arithmetic** | ct_butterfly, gs_butterfly, basemul_kyber_v2, barrett_reduction_kyber, barrett_reduction_kyber_wide, kyber_final_mult, modq | Kyber modular arithmetic |
| **SimX support** | VX_config.h, types.h, func_unit.cpp | Functional simulator timing |
| **Kernel API** | vx_intrinsics.h | C intrinsics for GPU code |
| **Build system** | sim/rtlsim/Makefile | Verilator PQC include path |
