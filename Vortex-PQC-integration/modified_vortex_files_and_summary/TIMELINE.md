# Timeline — Kyber PQC Integration

## Phase 1: Mathematical Primitive Design

- Design and verification of the core Kyber arithmetic modules:
  - `barrett_reduction_kyber.sv` — 24-bit Barrett reduction (mod 3329)
  - `barrett_reduction_kyber_wide.sv` — 36-bit Barrett reduction (mod 3329)
  - `modq.sv` — Conditional mod q correction
  - `kyber_final_mult.sv` — Post-INTT final multiplication by 3303
  - `ct_butterfly.sv` — Cooley-Tukey NTT butterfly with pipelined Barrett
  - `gs_butterfly.sv` — Gentleman-Sande INTT butterfly with pipelined Barrett
  - `basemul_kyber_v2.sv` — Base multiplication with wide Barrett reduction

## Phase 2: ALU Pipeline Integration

- Design of ALU PE wrappers (the bridge between Vortex pipeline and PQC modules):
  - `VX_alu_ct_butterfly.sv` — Pipeline interface wrapper for CT butterfly
  - `VX_alu_gs_butterfly.sv` — Pipeline interface wrapper for GS butterfly
  - `VX_alu_basemul.sv` — Pipeline interface wrapper for base multiplication

## Phase 3: Vortex Core Integration

- Modification of `VX_alu_unit.sv` to route PQC instructions to the new PEs
- Addition of PQC opcodes to `VX_gpu_pkg.sv`
- Addition of latency parameters to `VX_config.vh` (Verilog) and `VX_config.h` (C++)

## Phase 4: Decode & Pipeline Integration

- Modification of `VX_decode.sv` to decode PQC instructions from INST_EXT1 space
- funct2 field at bits [26:25] maps to CT_BF (00), GS_BF (01), BASEMUL (10)
- Integration of `sim/rtlsim/Makefile` to add `-I$(RTL_DIR)/pqc` include path

## Phase 5: SimX Simulator Support

- Addition of `AluType::CT_BF`, `AluType::GS_BF`, `AluType::BASEMUL` to `sim/simx/types.h`
- Addition of PQC delay computation in `sim/simx/func_unit.cpp`
- Cycle-accurate SimX timing mirrors RTL latency parameters

## Phase 6: Kernel Intrinsic API

- Addition of `vx_ct_butterfly()`, `vx_gs_butterfly()`, `vx_basemul()` to `kernel/include/vx_intrinsics.h`
- Inline assembly wrappers using `.insn r4` directive
- Three-operand R4-type instructions with funct2 encoding

## Phase 7: Verification

- Module-level testbenches for each PQC arithmetic module
- Integration tests under `tests/regression/kyber/`
- RTL simulation validation (rtlsim)
- SimX model validation (functional equivalence)

---

## File Creation Order (Inferred from Dependencies)

```
1. barrett_reduction_kyber.sv        (no internal dependencies)
2. barrett_reduction_kyber_wide.sv   (no internal dependencies)
3. modq.sv                            (no internal dependencies)
4. kyber_final_mult.sv               (depends on barrett_reduction_kyber)
5. ct_butterfly.sv                    (depends on barrett_reduction_kyber, modq)
6. gs_butterfly.sv                    (depends on barrett_reduction_kyber, modq)
7. basemul_kyber_v2.sv               (depends on barrett_reduction_kyber_wide)
8. VX_alu_ct_butterfly.sv            (depends on ct_butterfly)
9. VX_alu_gs_butterfly.sv            (depends on gs_butterfly)
10. VX_alu_basemul.sv                 (depends on basemul_kyber_v2)
11. VX_gpu_pkg.sv (mod)              (opcode definitions)
12. VX_config.vh (mod)               (latency parameters)
13. VX_alu_unit.sv (mod)             (PE routing integration)
```

---

## Verification Sequence

```
Module-level testbenches (per PQC module)
        │
        ▼
Integration testbenches (ALU PE wrappers)
        │
        ▼
RTL simulation (rtlsim — processor-level)
        │
        ▼
SimX model validation (functional equivalence check)
```

---

## Key Dates (Repository)

| Event | Description |
|-------|-------------|
| Vortex fork + PQC extension start | Repository creation |
| Primitive module completion | All 7 PQC modules operational |
| PE wrapper completion | All 3 ALU wrappers operational |
| Pipeline integration | VX_alu_unit.sv modified |
| Verification complete | Tests passing in rtlsim/SimX |
