# VX_alu_gs_butterfly.sv — Gentleman-Sande Butterfly ALU PE

**Path:** `hw/rtl/core/VX_alu_gs_butterfly.sv`
**Type:** New file
**Latency:** 2 cycles (from `VX_config.vh`: `LATENCY_GS_BF`)
**Purpose:** Pipeline interface wrapper for the `gs_butterfly` PQC module

---

## Function

Computes the Gentleman-Sande INTT butterfly:

```
A' = (A + B) mod q
B' = (A − B) · W mod q
```

where:
- A, B are polynomial coefficients (12-bit values mod 3329)
- W is the twiddle factor (12-bit value, root of unity)
- q = 3329

---

## Interface

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | Input | Clock |
| `reset` | Input | Synchronous reset |
| `execute_if` | Input | Pipeline execute interface |
| `result_if` | Output | Pipeline result interface |

### Operand Mapping

| Operand | Source | Content |
|---------|--------|---------|
| `rs1_data` | Source reg 1 | A coefficient (12-bit) |
| `rs2_data` | Source reg 2 | B coefficient (12-bit) |
| `rs3_data` | Source reg 3 | W twiddle factor (12-bit) |

### Result Mapping

| Field | Content |
|-------|---------|
| `result_data[15:0]` | B' coefficient (12-bit, padded) |
| `result_data[31:16]` | A' coefficient (12-bit, padded) |

---

## Implementation

Same wrapping pattern as `VX_alu_ct_butterfly`. Uses `VX_pe_serializer` for alignment. Key difference: the GS butterfly computes addition BEFORE multiplication (unlike CT which computes multiplication before addition).

### Pipeline Stages

| Stage | Cycle | Activity |
|-------|-------|----------|
| 0 | 1 | A+B, A−B compute (modq), start W·(A−B) multiply |
| 1 | 2 | Barrett reduction of W·(A−B) |
| Output | 2+ | Result available on `result_if` |
