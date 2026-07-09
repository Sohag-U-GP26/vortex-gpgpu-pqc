# vx_intrinsics.h — Kernel Intrinsic API

**Path:** `kernel/include/vx_intrinsics.h`
**Type:** Modified (existing Vortex file)
**Role:** Provides C/C++ inline intrinsic functions for GPU kernel code

---

## Kyber-Specific Intrinsics

### CT Butterfly (line 286-289)

```c
/// A' = (A + B·W) mod q,  B' = (A - B·W) mod q
/// Usage: int result = vx_ct_butterfly(A, B, W);
///        A' = (result >> 16) & 0xFFF;
///        B' = result & 0xFFF;
inline __attribute__((const)) int vx_ct_butterfly(int a, int b, int w) {
    int ret;
    __asm__ volatile (".insn r4 %1, 0, 0, %0, %2, %3, %4"
        : "=r"(ret) : "i"(RISCV_CUSTOM0), "r"(a), "r"(b), "r"(w));
    return ret;
}
```

### GS Butterfly (line 294-297)

```c
/// A' = (A + B) mod q,  B' = (A - B)·W mod q
/// Usage: int result = vx_gs_butterfly(A, B, W);
///        A' = (result >> 16) & 0xFFF;
///        B' = result & 0xFFF;
inline __attribute__((const)) int vx_gs_butterfly(int a, int b, int w) {
    int ret;
    __asm__ volatile (".insn r4 %1, 0, 1, %0, %2, %3, %4"
        : "=r"(ret) : "i"(RISCV_CUSTOM0), "r"(a), "r"(b), "r"(w));
    return ret;
}
```

### Base Multiply (line 301-304)

```c
/// C0 = A0·B0 + A1·B1·ζ,  C1 = A0·B1 + A1·B0  (mod q)
/// Usage: int result = vx_basemul({B1,A1}, {B0,A0}, zeta);
///        C0 = (result >> 16) & 0xFFF;
///        C1 = result & 0xFFF;
inline __attribute__((const)) int vx_basemul(int a, int b, int zeta) {
    int ret;
    __asm__ volatile (".insn r4 %1, 0, 2, %0, %2, %3, %4"
        : "=r"(ret) : "i"(RISCV_CUSTOM0), "r"(a), "r"(b), "r"(zeta));
    return ret;
}
```

---

## Encoding Pattern

The `.insn r4` assembler directive encodes R4-type custom instructions:

```
.insn r4 <opcode>, <func3>, <func2>, <rd>, <rs1>, <rs2>, <rs3>
```

| Intrinsic | func3 | func2 | Encoding |
|-----------|-------|-------|----------|
| `vx_ct_butterfly(a,b,w)` | 0 | 0 | `.insn r4 CUSTOM0, 0, 0, rd, rs1, rs2, rs3` |
| `vx_gs_butterfly(a,b,w)` | 0 | 1 | `.insn r4 CUSTOM0, 0, 1, rd, rs1, rs2, rs3` |
| `vx_basemul(a,b,zeta)` | 0 | 2 | `.insn r4 CUSTOM0, 0, 2, rd, rs1, rs2, rs3` |

---

## Usage in Kernel Code

```c
#include <vx_intrinsics.h>

// NTT butterfly
int r = vx_ct_butterfly(A, B, W);
int A_out = (r >> 16) & 0xFFF;
int B_out = r & 0xFFF;

// INTT butterfly
r = vx_gs_butterfly(A, B, W);
A_out = (r >> 16) & 0xFFF;
B_out = r & 0xFFF;

// Base multiply
r = vx_basemul((B1 << 16) | A1, (B0 << 16) | A0, zeta);
int C0 = (r >> 16) & 0xFFF;
int C1 = r & 0xFFF;
```
