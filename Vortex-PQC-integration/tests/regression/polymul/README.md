# tests/regression/polymul/ — Sequential Polymul Baseline (Phase 2)

> Part of [Phase 2: Vortex GPGPU Integration](../../../README.md) — original sequential polynomial multiplication test, used as a performance baseline for the concurrent NTT strategy.

**Files:**
- `kernel.cpp` — GPU kernel source (sequential NTT)
- `main.cpp` — Host driver
- `common.h` — Shared constants and twiddle factors
- `Makefile` — Build rules
- `overall_process.md` — Process documentation
