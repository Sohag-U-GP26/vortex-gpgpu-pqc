# hw/rtl/pqc/ — Kyber PQC Hardware Modules (Phase 2)

> Part of [Phase 2: Vortex GPGPU Integration](../../README.md) — custom SystemVerilog modules for Kyber polynomial arithmetic on the Vortex GPGPU. These modules are direct descendants of the [Phase 1 RTL](../../../HW-design/Design/).

Custom SystemVerilog modules implementing Kyber polynomial arithmetic on the Vortex GPGPU.

**Files (7):**
- `ct_butterfly.sv` — Cooley-Tukey NTT butterfly (2-cycle latency)
- `gs_butterfly.sv` — Gentleman-Sande INTT butterfly (2-cycle latency)
- `basemul_kyber_v2.sv` — Base-case polynomial multiply (3-cycle latency)
- `barrett_reduction_kyber.sv` — 24-bit Barrett reduction
- `barrett_reduction_kyber_wide.sv` — 36-bit Wide Barrett reduction
- `kyber_final_mult.sv` — Final scaling (×3303)
- `modq.sv` — Conditional mod q
