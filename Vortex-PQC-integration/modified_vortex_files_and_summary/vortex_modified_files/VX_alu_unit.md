# VX_alu_unit.sv — ALU Top-Level Integration

**Path:** `hw/rtl/core/VX_alu_unit.sv`
**Type:** Modified (existing Vortex file)
**Role:** Routes ALU instructions to the correct processing element (PE)

---

## Overview

`VX_alu_unit.sv` is the top-level ALU unit in the Vortex GPGPU pipeline. It instantiates all ALU processing elements and routes incoming instructions to the correct PE based on the decoded `op_type` and ALU subtype.

## Kyber-Specific Modifications

Three new processing elements are added alongside the existing integer ALU and multiply-divide units:

### New PE Index Assignments

PE indices are computed dynamically based on the `EXT_M_ENABLED` configuration:

```systemverilog
localparam PE_IDX_INT   = 0;
localparam PE_IDX_MDV   = PE_IDX_INT + `EXT_M_ENABLED;  // 0 or 1
localparam PE_IDX_CTBF  = PE_IDX_MDV + 1;
localparam PE_IDX_GSBF  = PE_IDX_CTBF + 1;
localparam PE_IDX_BASEMUL = PE_IDX_GSBF + 1;
```

**When `EXT_M_ENABLED = 1`** (M-extension present, common case):

| PE Name | Index | Purpose |
|---------|-------|---------|
| `PE_IDX_INT` | 0 | Integer ALU (existing) |
| `PE_IDX_MDV` | 1 | Multiply/Divide (existing) |
| `PE_IDX_CTBF` | 2 | **Cooley-Tukey butterfly (NEW)** |
| `PE_IDX_GSBF` | 3 | **Gentleman-Sande butterfly (NEW)** |
| `PE_IDX_BASEMUL` | 4 | **Base multiplication (NEW)** |

**When `EXT_M_ENABLED = 0`** (no M-extension):

| PE Name | Index | Purpose |
|---------|-------|---------|
| `PE_IDX_INT` | 0 | Integer ALU (existing) |
| `PE_IDX_CTBF` | 1 | **Cooley-Tukey butterfly (NEW)** |
| `PE_IDX_GSBF` | 2 | **Gentleman-Sande butterfly (NEW)** |
| `PE_IDX_BASEMUL` | 3 | **Base multiplication (NEW)** |

### PE Selection Logic

```systemverilog
pe_switch_sel = op_args.alu.op_type;
```

The `pe_select` logic maps ALU opcodes to PE IDs:
- `INST_ALU_CT_BF` → `PE_IDX_CTBF`
- `INST_ALU_GS_BF` → `PE_IDX_GSBF`
- `INST_ALU_BASEMUL` → `PE_IDX_BASEMUL`

### New Ports/Interfaces

No new top-level ports. The existing `execute_if` (input) and `result_if` (output) interfaces are retained. The new PEs are instantiated internally and connected through the existing `VX_pe_switch` module.

---

## Key Design Points

1. **Drop-in integration**: New PEs use the same `VX_execute_if` / `VX_result_if` interface as existing PEs.
2. **PE switch unchanged**: `VX_pe_switch` already supports multi-PE selection; new PEs just increase the port count.
3. **Pipeline latency**: Each PE reports its latency (from `VX_config.vh`) for pipeline alignment via `VX_pe_serializer`.
4. **No structural hazards**: Each PQC PE is independent; concurrent PQC operations of different types can be in-flight simultaneously.

---

## Connection Diagram

```
                     VX_alu_unit
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  execute_if ──▶ pe_select ──▶ ┌─────────────────────┐  │
│                              │ VX_pe_switch          │  │
│                              │  ├─ PE_IDX_INT  (0)   │  │
│                              │  ├─ PE_IDX_MDV  (1)   │  │
│                              │  ├─ PE_IDX_CTBF (2)───┼──▶ VX_alu_ct_butterfly
│                              │  ├─ PE_IDX_GSBF (3)───┼──▶ VX_alu_gs_butterfly
│                              │  ├─ PE_IDX_BASEMUL(4)─┼──▶ VX_alu_basemul
│                              │  └────────────────────┘  │
│                                           │             │
│                              result_if ◀─┘             │
└─────────────────────────────────────────────────────────┘
```
