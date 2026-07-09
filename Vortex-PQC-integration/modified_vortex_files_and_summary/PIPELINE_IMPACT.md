# Pipeline Impact Analysis — Kyber PQC Integration

## Latency Summary

| Operation | Latency (cycles) | Pipeline Stages in PE | Notes |
|-----------|-----------------|----------------------|-------|
| Integer ALU op | 1 | 0 (combinational) | Baseline |
| CT Butterfly | 2 | 2 | Barrett in stage 0, modq in stage 1 |
| GS Butterfly | 2 | 2 | modq in stage 0, Barrett in stage 1 |
| Base Multiply | 3 | 3 | Mult in stage 0, sum in stage 1, Barrett in stage 2 |

---

## Pipeline Stage Utilization

### Existing ALU Pipeline

```
Cycle:  0         1         2         3
        ┌─────────┬─────────┬─────────┬─────────┐
        │  ISSUE  │  EXEC0  │  EXEC1  │  COMMIT │
        └─────────┴─────────┴─────────┴─────────┘
           │          │
        operate     int_alu
        regs      (combinational)
        ready
```

### With PQC PEs

```
Cycle:  0         1         2         3         4         5
        ┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
        │  ISSUE  │  EXEC0  │  EXEC1  │  EXEC2  │  EXEC3  │  COMMIT │
        └─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
                          │                    │
                     CT_BF/GS_BF           BaseMul
                     (2 cycles)            (3 cycles)
```

The pipeline does NOT add extra stages. Each PE internally sequences through its stages, and the PE serializer aligns the output to the correct commit cycle.

---

## Hazard Analysis

### Read-After-Write (RAW) Hazards

| Scenario | Handling |
|----------|----------|
| PQC instruction reads register written by previous instruction | Standard scoreboard stalls issue until register available |
| PQC instruction writes register read by subsequent ALU op | Standard forwarding applies (within ALU pipeline) |
| PQC instruction writes register read by subsequent memory op | Standard LSU hazard handling applies |

### Write-After-Read (WAR) / Write-After-Write (WAW)

No special handling needed — Vortex's in-order pipeline prevents these by design.

### Structural Hazards

| Resource | Potential Conflict | Resolution |
|----------|-------------------|------------|
| PE_IDX_CTBF | Only one CT_BF at a time | Scoreboard serializes same-type PQC ops |
| PE_IDX_GSBF | Only one GS_BF at a time | Scoreboard serializes same-type PQC ops |
| PE_IDX_BASEMUL | Only one BASEMUL at a time | Scoreboard serializes same-type PQC ops |
| Cross-PE | CT_BF + GS_BF concurrent | Supported — different PE indices |
| Cross-PE | CT_BF + BASEMUL concurrent | Supported — different PE indices |

---

## Throughput

| Operation | Latency | Initiation Interval | Max throughput (ops/cycle) |
|-----------|---------|-------------------|---------------------------|
| CT Butterfly | 2 cycles | 1 cycle (if no dep) | 1 / cycle |
| GS Butterfly | 2 cycles | 1 cycle (if no dep) | 1 / cycle |
| Base Multiply | 3 cycles | 1 cycle (if no dep) | 1 / cycle |

Since each PE has its own pipeline, CT, GS, and BASEMUL operations can be issued in consecutive cycles if they target different PEs.

---

## Impact on Vortex Pipeline Control

| Pipeline Component | Impact |
|--------------------|--------|
| **Issue logic** | No change — PEs share existing scoreboard interface |
| **Commit logic** | No change — results returned via standard result interface |
| **Forwarding network** | No change — existing forwarding covers ALU results |
| **Warp scheduler** | No change — PQC ops are just ALU ops to the scheduler |
| **Exception handling** | No change — PQC ops do not generate exceptions |
| **Interrupt handling** | No change — PQC ops complete within standard ALU latency |
