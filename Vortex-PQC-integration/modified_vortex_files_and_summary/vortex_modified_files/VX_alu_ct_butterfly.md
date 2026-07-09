# VX_alu_ct_butterfly.sv — Cooley-Tukey Butterfly ALU PE

**Path:** `hw/rtl/core/VX_alu_ct_butterfly.sv`
**Type:** New file
**Latency:** 2 cycles (from `VX_config.vh`: `LATENCY_CT_BF`)
**Purpose:** Pipeline interface wrapper for the `ct_butterfly` PQC module

---

## Function

Computes the Cooley-Tukey NTT butterfly:

```
A' = (A + B · W) mod q
B' = (A − B · W) mod q
```

where:
- A, B are polynomial coefficients (12-bit values mod 3329)
- W is the twiddle factor (12-bit value, root of unity)
- q = 3329

---

## Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | Clock |
| `reset` | Input | Synchronous reset |
| `execute_if` | Input | Pipeline execute interface (Vortex standard) |
| `result_if` | Output | Pipeline result interface (Vortex standard) |

### Operand Mapping (from execute_if)

| Operand | Source | Content |
|---------|--------|---------|
| `rs1_data` | Source reg 1 | A coefficient (12-bit) |
| `rs2_data` | Source reg 2 | B coefficient (12-bit) |
| `rs3_data` | Source reg 3 | W twiddle factor (12-bit) |

### Result Mapping (to result_if)

| Field | Content |
|-------|---------|
| `result_data[15:0]` | B' coefficient (12-bit, padded) |
| `result_data[31:16]` | A' coefficient (12-bit, padded) |

---

## Implementation

The wrapper uses `VX_pe_serializer` to align the pipeline stages with other PEs. Inside:

1. Receives operands from the execute interface
2. Routes them to `ct_butterfly.sv` instance
3. Applies 2-cycle pipeline delay (matching `LATENCY_CT_BF`)
4. Packs A' and B' into the result

### Pipeline Stages

| Stage | Cycle | Activity |
|-------|-------|----------|
| 0 | 1 | Operand capture + W·B multiplication start |
| 1 | 2 | Barrett reduction of W·B, A±W·B compute |
| Output | 2+ | Result available on `result_if` |
