# VX_alu_basemul.sv — Base Multiplication ALU PE

**Path:** `hw/rtl/core/VX_alu_basemul.sv`
**Type:** New file
**Latency:** 3 cycles (from `VX_config.vh`: `LATENCY_BASEMUL`)
**Purpose:** Pipeline interface wrapper for the `basemul_kyber_v2` PQC module

---

## Function

Computes Kyber base multiplication in R_q[X]/(X² − ζ):

```
C0 = A0·B0 + A1·B1·ζ  (mod q)
C1 = A0·B1 + A1·B0    (mod q)
```

where:
- A0, A1, B0, B1 are polynomial coefficients (12-bit mod 3329)
- ζ is the twiddle factor
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
| `rs1_data[15:0]` | Source reg 1 low | A1 coefficient (12-bit) |
| `rs1_data[31:16]` | Source reg 1 high | B1 coefficient (12-bit) |
| `rs2_data[15:0]` | Source reg 2 low | A0 coefficient (12-bit) |
| `rs2_data[31:16]` | Source reg 2 high | B0 coefficient (12-bit) |
| `rs3_data` | Source reg 3 | ζ twiddle factor (12-bit) |

### Result Mapping

Source (`VX_alu_basemul.sv` line 91): `pe_data_out[i] = (C1 << 16) | C0`

| Field | Content |
|-------|---------|
| `result_data[15:0]` | C0 coefficient (12-bit, padded to 16) |
| `result_data[31:16]` | C1 coefficient (12-bit, padded to 16) |

Kernel extraction:
```c
int C0 = result & 0xFFF;
int C1 = (result >> 16) & 0xFFF;
```

---

## Implementation

Uses `VX_pe_serializer` for pipeline alignment. Instantiates `basemul_kyber_v2.sv` as the computational core.

### Pipeline Stages

| Stage | Cycle | Activity |
|-------|-------|----------|
| 0 | 1 | Product computation: A0·B0, A0·B1, A1·B0, A1·B1·ζ |
| 1 | 2 | Summation: C0 = A0·B0 + A1·B1·ζ, C1 = A0·B1 + A1·B0 |
| 2 | 3 | Wide Barrett reduction (36-bit to 12-bit) |
| Output | 3+ | Result available on `result_if` |
