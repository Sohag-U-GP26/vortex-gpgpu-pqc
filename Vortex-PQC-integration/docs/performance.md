# Performance Analysis

## Metrics

All measurements on a single-core Vortex 64-bit configuration, N = 256, q = 3329.

| Metric | polymul | kyber | Improvement |
|---|---|---|---|
| **Instructions (core0)** | 282,976 | 192,961 | 1.47× fewer |
| **Cycles (rtlsim)** | 610,729 | 180,951 | 3.38× faster |
| **IPC (rtlsim)** | 0.463 | 1.066 | 2.30× higher |
| **Kernel execution cycles** | — | 37,800 | — |

## Comparison: polymul vs kyber

### polymul (Sequential NTT)

The `polymul` test performs NTT(A) and NTT(B) sequentially using 256 threads for each, effectively serializing the two transforms:

```
Phase          Threads     Stages     Instructions
───────        ──────────  ─────────  ────────────
NTT(A)         0–255       7 × 256    1,792 CT
NTT(B)         0–255       7 × 256    1,792 CT
Basemul        0–127       —          128 BM
INTT           0–127       7 × 128    896 GS
Scale          0–127       —          —
───────        ──────────  ─────────  ────────────
Total custom instrs:                  4,608
```

### kyber (Concurrent NTT)

The `kyber` test halves the thread count per polynomial but runs both NTTs simultaneously:

```
Phase          Threads     Stages     Instructions
───────        ──────────  ─────────  ────────────
NTT(A)         0–127       7 × 128    896 CT
NTT(B)         128–255     7 × 128    896 CT
Basemul        0–127       —          128 BM
INTT           0–127       7 × 128    896 GS
Scale          0–127       —          —
───────        ──────────  ─────────  ────────────
Total custom instrs:                  2,816 (39% fewer)
```

## IPC Improvement Analysis

The IPC jump from 0.46 to 1.07 is driven by:

1. **Concurrent NTT execution** — Both NTT(A) and NTT(B) run in parallel across 256 threads, doubling warp utilization during the forward transform. Instead of idle threads waiting for the other NTT to complete, all 256 threads are productive simultaneously.

2. **Fewer thread barriers** — The concurrent design eliminates redundant synchronization points. Threads 0–127 and 128–255 naturally synchronize at `__syncthreads()` boundaries without additional signaling.

3. **Better warp occupancy** — With 256 threads in a single block, all warps are active throughout the NTT phase. The sequential approach had half the warps idle during each NTT half.

## Cycle Breakdown

The kernel execution spans 37,800 cycles (measured from the first cycle after launch to the last store):

| Phase | Estimated Cycles |
|---|---|
| Load + NTT(A) || NTT(B) | ~15,000 |
| Basemul | ~3,000 |
| INTT | ~12,000 |
| Scale + Store | ~3,000 |
| Barriers + overhead | ~4,800 |
| **Total** | **~37,800** |

The remaining cycles (180,951 - 37,800 ≈ 143,151) include driver setup, kernel dispatch, memory transfers, and runtime overhead.

## Custom Instruction Pipeline Efficiency

| Instruction | Latency | Pipelinable | Issue rate |
|---|---|---|---|
| `vx_ct_butterfly` | 2 cycles | Yes | 1/cycle |
| `vx_gs_butterfly` | 2 cycles | Yes | 1/cycle |
| `vx_basemul` | 3 cycles | Yes | 1/cycle |

All three custom instructions are fully pipelined, sustaining 1 instruction/cycle throughput once the pipeline is filled. The 3-cycle basemul latency is hidden by interleaving independent coefficient pairs.
