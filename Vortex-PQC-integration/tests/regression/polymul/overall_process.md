# Overall Process: Polynomial Multiplication on Vortex GPGPU

## Problem

Compute **C = A × B** in the ring **R = Z_q[X]/(X^N + 1)** where:
- N = 256 (polynomial degree)
- q = 3329 (modulus, a prime chosen for Kyber ML-KEM)

Multiplication in this ring uses **negative-wrapping convolution**:
for k = 0..N-1:
    C[k] = sum_{i=0}^{k}   A[i] × B[k-i]  -  sum_{i=k+1}^{N-1} A[i] × B[N+k-i]   (mod q)

This is not a standard convolution — the minus sign on the "wrap-around" terms comes from the X^N = -1 relation in the quotient ring.

## Reference: NTT-Based Multiplication (`PQC_REF/`)

The conventional approach in post-quantum cryptography uses **Number-Theoretic Transform (NTT)**:
```
A, B  →  NTT(A), NTT(B)  →  pointwise multiply  →  INTT  →  result
                    (basemul in NTT domain)
```

Files in `/home/moaz-linex/PQC_REF/`:

- `A_input.txt`, `B_input.txt` — input polynomials
- `A_NTT_output.txt`, `B_NTT_output.txt` — NTT transforms
- `basemul_output.txt` — coefficient-wise multiplication in NTT domain
- `INTT_output.txt` — inverse NTT (raw product before final alignment)
- `final_output.txt` — final C = A × B in Z_q[X]/(X^N+1)

## GPU Implementation: Schoolbook O(N²)

The Vortex GPGPU implements the **direct schoolbook algorithm**:

1. **Input**: Two polynomials A, B (256 coefficients each, loaded from PQC_REF)
2. **Kernel**: Each GPU thread computes one coefficient C[k]
3. **Algorithm**: For each k, accumulate A[i] × B[j] with sign determined by i ≤ k or i > k
4. **Reduction**: Modulo q after summation

### Why schoolbook instead of NTT?

- Simpler GPU kernel (no NTT twiddle factors, no butterfly stages)
- Avoids shared memory bank conflicts from NTT reordering
- N=256 is small enough that O(N²) per thread is manageable (256 iterations)
- Kernel parallelism: 256 threads × 256 iterations = 65,536 multiply-accumulate ops

## Verification Strategy

```
                     +----------+
  A_input.txt ------->  Vortex  |------> C_GPU ------+
  B_input.txt ------->  GPGPU   |                    |
                     +----------+                    |
                                                     v
                                              Comparison
                                                     |
  PQC_REF/final_output.txt --------------------------+
  (NTT-based reference)                              |
                                                     v
                                               PASS/FAIL
```

Two independent references are compared:
1. **PQC_REF/final_output.txt** — NTT-based reference implementation
2. **CPU schoolbook** — sequential CPU implementation of the same algorithm

If all 256 coefficients match both references, the test PASSES.

## Performance

| Metric | SimX (C++ model) | RTL sim (Verilator) |
|--------|------------------|---------------------|
| Instructions | 282,976 | 282,976 |
| Cycles | 988,894 | 610,729 |
| IPC | 0.29 | 0.46 |

RTL simulation runs ~1.6× faster in cycles than the approximate C++ model.
