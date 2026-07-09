# tests/regression/kyber/ — Kyber Concurrent-NTT Test Suite (Phase 2)

> Part of [Phase 2: Vortex GPGPU Integration](../../../README.md) — GPU kernel and host driver for the Kyber polynomial multiplication test with concurrent dual-NTT strategy. See [RUN.md](./RUN.md) for build and run instructions.

**Files:**
- `kernel.cpp` — GPU kernel source (256 threads, concurrent NTT)
- `main.cpp` — Host driver
- `common.h` — Shared constants and twiddle factors
- `Makefile` — Build rules
- `RUN.md` — Build and run instructions
