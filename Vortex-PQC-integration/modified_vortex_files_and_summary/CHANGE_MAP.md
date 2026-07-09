# Change Map — Kyber PQC Integration

This document provides a mapping of every change made to the Vortex GPGPU repository to support the Kyber PQC integration.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| + | New file created |
| ~ | Existing file modified |
| ✓ | Verified no change needed |

---

## 1. Instruction Decode Layer

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `hw/rtl/core/VX_decode.sv` | Added PQC opcode decode in INST_EXT1 default case | ~ | Maps funct2→INST_ALU_CT_BF/GS_BF/BASEMUL |

---

## 2. Configuration Layer

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `hw/rtl/VX_config.vh` | Added `LATENCY_CT_BF=2`, `LATENCY_GS_BF=2`, `LATENCY_BASEMUL=3` | ~ | Pipeline depth for new PEs |
| `hw/VX_config.h` | Added C++ counterpart latency defines | ~ | SimX simulation latency |
| `hw/rtl/VX_gpu_pkg.sv` | Added `INST_ALU_CT_BF`, `INST_ALU_GS_BF`, `INST_ALU_BASEMUL` opcodes | ~ | ISA extension for Kyber |

---

## 3. ALU Pipeline Integration

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `hw/rtl/core/VX_alu_unit.sv` | Added PQC PE routing + instantiation | ~ | Routes PQC ops to new PEs |

---

## 4. New ALU Processing Elements

| File | Change | Type | Latency | Purpose |
|------|--------|------|---------|---------|
| `hw/rtl/core/VX_alu_ct_butterfly.sv` | Created | + | 2 cycles | Cooley-Tukey NTT butterfly |
| `hw/rtl/core/VX_alu_gs_butterfly.sv` | Created | + | 2 cycles | Gentleman-Sande INTT butterfly |
| `hw/rtl/core/VX_alu_basemul.sv` | Created | + | 3 cycles | Base polynomial multiplication |

---

## 5. PQC Arithmetic Modules

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `hw/rtl/pqc/ct_butterfly.sv` | Created | + | CT butterfly: A'=A+BW, B'=A−BW mod q |
| `hw/rtl/pqc/gs_butterfly.sv` | Created | + | GS butterfly: A'=A+B, B'=(A−B)W mod q |
| `hw/rtl/pqc/basemul_kyber_v2.sv` | Created | + | Base multiplication |
| `hw/rtl/pqc/barrett_reduction_kyber.sv` | Created | + | 24-bit Barrett reduction |
| `hw/rtl/pqc/barrett_reduction_kyber_wide.sv` | Created | + | 36-bit Barrett reduction |
| `hw/rtl/pqc/kyber_final_mult.sv` | Created | + | Post-INTT multiply by 3303 |
| `hw/rtl/pqc/modq.sv` | Created | + | Conditional mod q correction |

---

## 6. SimX Functional Simulator

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `sim/simx/types.h` | Added AluType::CT_BF, GS_BF, BASEMUL | ~ | AluType enum for PQC ops |
| `sim/simx/func_unit.cpp` | Added delay cases for PQC opcodes | ~ | Cycle-accurate SimX timing |

---

## 7. Kernel Intrinsic API

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `kernel/include/vx_intrinsics.h` | Added vx_ct_butterfly(), vx_gs_butterfly(), vx_basemul() | ~ | C inline intrinsics for GPU kernels |

---

## 8. Test Infrastructure

| File | Change | Type | Purpose |
|------|--------|------|---------|
| `tests/regression/kyber/` | Created | + | Kyber integration test suite |
| `sim/rtlsim/Makefile` | Added `-I$(RTL_DIR)/pqc` include path | ~ | Verilator PQC module discovery |

---

## 9. Files NOT Modified (Verified)

| Component | Status | Reason |
|-----------|--------|--------|
| Instruction fetch (`VX_fetch.sv`) | ✓ | PQC ops use existing custom opcode space |
| Scoreboard | ✓ | Standard register tracking |
| Warp scheduler | ✓ | No new scheduling semantics |
| Memory subsystem | ✓ | PQC ops are pure compute |
| L1/L2/L3 cache | ✓ | No cache changes needed |
| Pipeline control logic | ✓ | Existing hazard detection covers PQC ops |
| RISC-V core integer ALU | ✓ | PQC ops are separate PEs alongside, not replacing |
| Vortex runtime | ✓ | No runtime changes needed |

---

## Modified Files — Detailed Summary

### Decode Logic (VX_decode.sv)

```
INST_EXT1 default case (funct3=000, funct2≤2):
  funct2=00 → op_type = INST_ALU_CT_BF
  funct2=01 → op_type = INST_ALU_GS_BF
  funct2=10 → op_type = INST_ALU_BASEMUL
  All: ex_type = EX_ALU, use_imm = 0
```

### Configuration Additions

**VX_config.vh:**
```
+ LATENCY_CT_BF   = 2
+ LATENCY_GS_BF   = 2
+ LATENCY_BASEMUL = 3
```

**VX_config.h:**
```
+ #define LATENCY_CT_BF   2
+ #define LATENCY_GS_BF   2
+ #define LATENCY_BASEMUL 3
```

**VX_gpu_pkg.sv:**
```
+ INST_ALU_CT_BF   = 5'b00001
+ INST_ALU_GS_BF   = 5'b00110
+ INST_ALU_BASEMUL = 5'b10000
```

### Pipeline Integration (VX_alu_unit.sv)

```
+ PE_IDX_CTBF    = 2
+ PE_IDX_GSBF    = 3
+ PE_IDX_BASEMUL = 4
+ pe_select logic for INST_ALU_CT_BF, INST_ALU_GS_BF, INST_ALU_BASEMUL
+ Instantiation: VX_alu_ct_butterfly, VX_alu_gs_butterfly, VX_alu_basemul
```

### SimX Types (types.h)

```
AluType enum:
+ CT_BF
+ GS_BF
+ BASEMUL
```

### SimX Delay (func_unit.cpp)

```
+ case AluType::CT_BF:   delay = LATENCY_CT_BF;   break;
+ case AluType::GS_BF:   delay = LATENCY_GS_BF;   break;
+ case AluType::BASEMUL: delay = LATENCY_BASEMUL; break;
```

### Kernel Intrinsics (vx_intrinsics.h)

```
+ vx_ct_butterfly(a, b, w)   → .insn r4 CUSTOM0, 0, 0, rd, rs1, rs2, rs3
+ vx_gs_butterfly(a, b, w)   → .insn r4 CUSTOM0, 0, 1, rd, rs1, rs2, rs3
+ vx_basemul(a, b, zeta)     → .insn r4 CUSTOM0, 0, 2, rd, rs1, rs2, rs3
```

---

## New Files Summary

| Directory | Files | Total |
|-----------|-------|-------|
| `hw/rtl/core/` | 3 ALU PE wrappers | 3 |
| `hw/rtl/pqc/` | 7 arithmetic modules | 7 |
| `tests/regression/kyber/` | Integration test | 4+ |
| **Total new files** | | **14+** |
