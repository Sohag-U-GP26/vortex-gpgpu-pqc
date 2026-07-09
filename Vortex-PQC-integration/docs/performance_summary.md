# Performance Summary Report

## Test Configuration

| Property | Value             |
| -------- | ----------------- |
| **Test** | kyber             |
| **Ring** | Z₃₃₂₉[x]/(x²⁵⁶+1) |
| **N**    | 256               |
| **q**    | 3329              |

## RTL Simulation Results

| Metric                           | Value    |
| -------------------------------- | -------- |
| **Instructions**                 | 192,961  |
| **Cycles**                       | 180,951  |
| **IPC (Instructions Per Cycle)** | 1.066372 |

## Kernel Cycles Comparison

| Simulation Type | Cycles |
| --------------- | ------ |
| **RTL Sim**     | 37,800 |

## Test Status

| Status                  | Result    |
| ----------------------- | --------- |
| **Overall Status**      | ✅ PASSED |
| **PQC Reference Match** | ✅ true   |
| **Polymul Match**       | ✅ true   |

### Summary

The Kyber test completed successfully with all validations passing. The RTL simulation achieved an IPC of 1.066372 with 180,951 cycles over 192,961 instructions.
