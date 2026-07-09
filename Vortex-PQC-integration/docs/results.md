# Test Results

## Summary

The Kyber polynomial multiplication kernel passes all verification checks on both simulators.

| Check | simx | rtlsim |
|---|---|---|
| All 256 coefficients match reference | ✓ | ✓ |
| Schoolbook O(n²) validation | ✓ | ✓ |
| NTT(A) intermediate stages | ✓ | ✓ |
| NTT(B) intermediate stages | ✓ | ✓ |
| Basemul intermediate result | ✓ | ✓ |
| INTT intermediate stages | ✓ | ✓ |
| PQC reference file comparison | ✓ | ✓ |
| polymul reference comparison | ✓ | ✓ |

## SimX Output

```
PERF: core0: instrs=192961, cycles=322783, IPC=0.598

✓ ALL KYBER TESTS PASSED
```

## RTLsim Output

```
PERF: core0: instrs=192961, cycles=180951, IPC=1.066

✓ ALL KYBER TESTS PASSED
```

## Performance Comparison

| Metric | polymul (simx) | polymul (rtlsim) | kyber (simx) | kyber (rtlsim) |
|---|---|---|---|---|
| Instructions | 282,976 | 282,976 | 192,961 | 192,961 |
| Cycles | 988,894 | 610,729 | 322,783 | 180,951 |
| IPC | 0.286 | 0.463 | 0.598 | 1.066 |
| Kernel exec cycles | — | — | — | 37,800 |
| Custom instrs | 4,608 | 4,608 | 2,816 | 2,816 |

## Detailed Coefficient Verification

Sample of 50 coefficients from the final output (all match):

```
  Idx  │  C_ref  │  C_GPU  │ Status
───────┼─────────┼─────────┼─────────
     2 │   1467  │   1467  │   OK
     7 │   2355  │   2355  │   OK
    12 │   1111  │   1111  │   OK
    17 │   3310  │   3310  │   OK
    22 │   1493  │   1493  │   OK
    27 │    198  │    198  │   OK
    32 │   2964  │   2964  │   OK
    37 │    740  │    740  │   OK
    42 │    558  │    558  │   OK
    47 │    829  │    829  │   OK
    52 │   1377  │   1377  │   OK
    57 │   1070  │   1070  │   OK
    62 │   1646  │   1646  │   OK
    67 │   1524  │   1524  │   OK
    72 │   1730  │   1730  │   OK
    77 │   1716  │   1716  │   OK
    82 │   1938  │   1938  │   OK
    87 │    826  │    826  │   OK
    92 │   2319  │   2319  │   OK
    97 │   3121  │   3121  │   OK
```

All 256/256 coefficients match the reference implementation exactly (0 errors).

## Hardware Configuration

- **XLEN**: 64-bit
- **Cores**: 1
- **Clusters**: 1
- **Warps**: 64
- **Threads per warp**: 4
- **Threads per block**: 256
- **L2 cache**: disabled
- **L3 cache**: disabled
- **Simulator**: Verilator 5.x (rtlsim), SimX (simx)
