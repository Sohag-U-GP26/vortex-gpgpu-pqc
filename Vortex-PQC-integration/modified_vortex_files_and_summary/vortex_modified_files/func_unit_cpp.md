# func_unit.cpp — SimX Functional Unit Delay

**Path:** `sim/simx/func_unit.cpp`
**Type:** Modified (existing Vortex file)
**Role:** Computes ALU operation latency in the SimX simulator

---

## Kyber-Specific Modifications (lines 56-64)

```cpp
case AluType::CT_BF:
    delay = LATENCY_CT_BF;     // 2 cycles
    break;
case AluType::GS_BF:
    delay = LATENCY_GS_BF;     // 2 cycles
    break;
case AluType::BASEMUL:
    delay = LATENCY_BASEMUL;   // 3 cycles
    break;
```

---

## Purpose

The SimX functional simulator must match the RTL pipeline timing to produce cycle-accurate results. This switch statement ensures that PQC operations have the correct execution delay in SimX, matching the hardware latencies defined in `VX_config.vh` / `VX_config.h`.

## Flow

```
SimX Decode
  → AluType::CT_BF / GS_BF / BASEMUL
    → func_unit.cpp delay computation
      → returns LATENCY_CT_BF / LATENCY_GS_BF / LATENCY_BASEMUL
        → SimX pipeline scheduler aligns commit accordingly
```
