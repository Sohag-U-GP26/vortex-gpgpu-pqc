# Architecture **(Phase 2 — Vortex GPGPU Integration)**

## Ring and Polynomial Representation

CRYSTALS-Kyber operates in the ring:

```
R_q = Z_q[x] / (x^N + 1)
```

with:

- **N = 256** — polynomial degree
- **q = 3329** — prime modulus (12-bit)
- **ζ = 17** — primitive 512-th root of unity modulo q

A polynomial is represented as 256 coefficients, each a 12-bit unsigned integer in `[0, q)`. Two input polynomials `A(x)` and `B(x)` are multiplied via NTT-based convolution:

```
C(x) = A(x) · B(x)  mod (x^256 + 1, 3329)
```

The negative wrapped convolution property of NTT over `x^N + 1` eliminates zero-padding, making N the transform length directly.

## NTT Algorithm

The forward NTT uses the Cooley-Tukey (CT) butterfly in 7 decimation-in-frequency layers:

```
Layer 0: half=128,  1 butterfly per group, W = ζ^1
Layer 1: half= 64,  2 butterflies per group
Layer 2: half= 32,  4 butterflies per group
Layer 3: half= 16,  8 butterflies per group
Layer 4: half=  8,  16 butterflies per group
Layer 5: half=  4,  32 butterflies per group
Layer 6: half=  2,  64 butterflies per group
```

Each butterfly computes for inputs `A`, `B` and twiddle `W`:

```
CT_butterfly(A, B, W):
    B' = A - B·W  mod q
    A' = A + B·W  mod q
```

The inverse NTT uses the Gentleman-Sande (GS) butterfly in 7 layers (reverse order):

```
GS_butterfly(A, B, W):
    A' = A + B      mod q
    B' = (A - B)·W  mod q
```

After INTT, every coefficient is multiplied by 3303 modulo 3329 (the scaling factor `n^(-1) = 256^(-1) mod 3329` combined with the inverse-NTT normalization).

### Twiddle Factors

NTT twiddles are powers of ζ = 17:

```
W[k] = ζ^bit_rev7(k)  mod q    for k = 1..127
```

INTT twiddles are the modular inverses:

```
W_inv[k] = (ζ^bit_rev7(k))^(-1)  mod q
```

Basemul uses 64 positive zeta factors for adjacent coefficient pairs, computed as:

```
zeta_pos[k] = 17^{br7(64+k)}  mod 3329   for k = 0..63
```

Each basemul pair `i` gets `zeta = zeta_pos[i>>1]` if `i` is even, or `Q - zeta_pos[i>>1]` if odd.

## Parallelization Strategy

The key optimization is **concurrent NTT(A) || NTT(B)** using 256 threads in a single block:

| Phase | Active Threads | Work per Thread | Custom Instrs |
|---|---|---|---|
| Load A | 0–127 | 2 coefficients | — |
| Load B | 128–255 | 2 coefficients | — |
| NTT(A) × 7 | 0–127 | 7 CT butterflies | 896 |
| NTT(B) × 7 | 128–255 | 7 CT butterflies | 896 |
| **syncthreads** | all 256 | — | — |
| Basemul | 0–127 | 1 basemul (2 coeffs) | 128 |
| **syncthreads** | all 256 | — | — |
| INTT × 7 | 0–127 | 7 GS butterflies | 896 |
| **syncthreads** | all 256 | — | — |
| Scale ×3303 | 0–127 | 2 coefficients | — |
| **syncthreads** | all 256 | — | — |

**Total**: 2816 custom instructions, 16 `__syncthreads()` barriers, 1 block × 256 threads.

### Thread-to-Data Mapping (NTT)

```
for each layer:
    half = 128 >> layer
    if tid < 128:
        poly = A_hat
        ltid = tid
    else:
        poly = B_hat
        ltid = tid - 128
    group = ltid / half
    j     = ltid % half
    a_idx = group * 2 * half + j
    b_idx = a_idx + half
    butterfly(poly[a_idx], poly[b_idx], W[group])
```

This ensures no bank conflicts in shared memory across the 256-thread warp.

## Custom Instruction Encoding

All three custom instructions use **R4-type RISC-V custom-0** encoding (opcode `0x0B`):

```
31     27 26   25  24   20 19   15 14  12 11     7 6      0
┌────────┬────────┬───────┬───────┬──────┬────────┬────────┐
│  rs3   │ funct2 │  rs2  │  rs1  │funct3│   rd   │ opcode │
│  (5)   │  (2)   │  (5)  │  (5)  │ (3)  │  (5)   │  (7)   │
└────────┴────────┴───────┴───────┴──────┴────────┴────────┘
```

| Instruction | funct3 | funct2 | Encoding (assembler) |
|---|---|---|---|
| `vx_ct_butterfly` | 000 | 00 | `.insn r4 0x0B, 0, 0, rd, rs1, rs2, rs3` |
| `vx_gs_butterfly` | 000 | 01 | `.insn r4 0x0B, 0, 1, rd, rs1, rs2, rs3` |
| `vx_basemul` | 000 | 10 | `.insn r4 0x0B, 0, 2, rd, rs1, rs2, rs3` |

### Return Value Packing

All three instructions pack two 12-bit results into a single 32-bit register:

- **CT/GS butterfly**: `rd = {4'b0, A'[11:0], 4'b0, B'[11:0]}`
- **Basemul**: `rd = {4'b0, C1[11:0], 4'b0, C0[11:0]}`

The kernel unpacks with:

```c
#define UNPACK_BF(rd, a, b)  \
    do { a = ((rd) >> 16) & 0xFFF;  b = (rd) & 0xFFF; } while (0)

#define UNPACK_BM(rd, c0, c1)  \
    do { c0 = (rd) & 0xFFF;  c1 = ((rd) >> 16) & 0xFFF; } while (0)
```

## Memory Layout

### Shared Memory

3 × 256 × 2 bytes = 1536 bytes allocated per thread group:

```
shmem = __local_mem(KYBER_N * 3 * sizeof(int16_t))
A_hat = shmem          // NTT(A) working buffer  (256 × int16)
B_hat = shmem + 256    // NTT(B) working buffer  (256 × int16)
C_hat = shmem + 512    // basemul/INTT result    (256 × int16)
```

### Global Memory

| Buffer | Size | Contents |
|---|---|---|
| A | 256 × uint16 | Input polynomial A |
| B | 256 × uint16 | Input polynomial B |
| C | 256 × uint16 + 16 B | Output + profiling timestamps |
| NTT twiddles | 127 × uint16 | Forward NTT twiddle factors |
| INTT twiddles | 127 × uint16 | Inverse NTT twiddle factors |
| Zeta pos | 64 × uint16 | Basemul twisting factors |

## Hardware Pipeline

### CT Butterfly (`ct_butterfly.sv`)

```
Stage 1 (comb):   BW_raw = B × W               (24-bit)
Stage 1 (FF):     Barrett_reduce(BW_raw) → BW_mod
Stage 2 (comb):   sum = A + BW_mod, diff = A - BW_mod
Stage 2 (FF):     modq(sum) → A', modq(diff) → B'
Latency: 2 cycles
```

### GS Butterfly (`gs_butterfly.sv`)

```
Stage 1 (comb):   sum = A + B, diff = A - B
Stage 1 (FF):     modq(sum) → sum_mod, modq(diff) → diff_mod
Stage 2 (comb):   diff_W_raw = diff_mod × W     (24-bit)
Stage 2 (FF):     Barrett_reduce(diff_W_raw) → B'
                  sum_mod registered → A'
Latency: 2 cycles
```

### Basemul v2 (`basemul_kyber_v2.sv`)

The v2 design avoids five sequential narrow Barrett reductions by accumulating raw products and applying one Wide Barrett (36-bit) per output:

```
Cycle 0 (comb):   m00 = A0·B0, m11 = A1·B1, m01 = A0·B1, m10 = A1·B0
Cycle 1 (FF):     store m00_r, m11_r, m01_r, m10_r, zeta_r
Cycle 1 (comb):   m11_zeta = m11_r × zeta_r     (36-bit)
                  raw_C1   = m01_r + m10_r       (25-bit)
Cycle 2 (FF):     store m00_r2, m11_zeta_r, raw_C1_r
Cycle 2 (comb):   raw_C0 = m00_r2 + m11_zeta_r   (36-bit)
Cycle 3 (FF):     barrett_reduction_kyber_wide(raw_C0) → C0
                  barrett_reduction_kyber_wide(raw_C1) → C1
Latency: 3 cycles
```

### Barrett Reduction

Two Barrett variants target different input ranges:

| Module | Input Bits | μ | R |
|---|---|---|---|
| `barrett_reduction_kyber` | 24-bit (≤ q²) | 5039 | 2¹² |
| `barrett_reduction_kyber_wide` | 36-bit (< 2³⁶) | 20,642,678 | 2³⁶ |

The 24-bit variant decomposes μ × C using shift/add:

```
μ × C = (C << 12) + (C << 10) - (C << 6) - (C << 4) - C
```

The 36-bit variant uses a direct multiply (36 × 25 = 61-bit product).

### Final Scaling (`kyber_final_mult.sv`)

After INTT, each coefficient is multiplied by 3303 using shift/add/sub only:

```
3303 = 4096 - 512 - 256 - 16 - 8 - 1
     = (1<<12) - (1<<9) - (1<<8) - (1<<4) - (1<<3) - (1<<0)
```

The 24-bit product is then reduced by `barrett_reduction_kyber`. Latency: 1 cycle.

### modq

The `modq` module handles values in the range `[-3329, 6656]` with two conditional corrections:

```
if C < 0:      C += Q
if C > 3328:   C -= Q
```

Registered output, 1 cycle latency.
