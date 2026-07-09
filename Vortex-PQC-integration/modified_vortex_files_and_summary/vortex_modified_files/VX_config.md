# VX_config.vh — Global Configuration

**Path:** `hw/rtl/VX_config.vh`
**Type:** Modified (existing Vortex file)
**Role:** Defines all architecture parameters and pipeline latencies

---

## Kyber-Specific Parameters

| Parameter | Value | Default | Used By |
|-----------|-------|---------|---------|
| `LATENCY_CT_BF` | 2 | — | `VX_alu_ct_butterfly.sv` |
| `LATENCY_GS_BF` | 2 | — | `VX_alu_gs_butterfly.sv` |
| `LATENCY_BASEMUL` | 3 | — | `VX_alu_basemul.sv` |

These parameters define the number of pipeline cycles required for each PQC operation. They are consumed by the PE serializers to ensure correct pipeline alignment.

---

## Configuration Context

These parameters follow the existing Vortex convention for ALU PE latencies:

| Existing Parameter | Value | PE |
|-------------------|-------|----|
| `LATENCY_ALU` | 1 | Integer ALU |
| `LATENCY_MDU` | Varies | Multiply/Divide |
| `LATENCY_CT_BF` | **2** | **CT butterfly (NEW)** |
| `LATENCY_GS_BF` | **2** | **GS butterfly (NEW)** |
| `LATENCY_BASEMUL` | **3** | **Base multiplication (NEW)** |

---

## Usage in Pipeline

```systemverilog
// In VX_alu_ct_butterfly.sv:
VX_pe_serializer #(
    .LATENCY(LATENCY_CT_BF)
) pe_serializer (...);
```
