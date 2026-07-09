# Running the Kyber Test

## SimX Mode (C++ Functional Simulator)

SimX provides fast functional verification without RTL simulation overhead.

```bash
cd build
LD_LIBRARY_PATH=build/runtime VORTEX_DRIVER=simx \
  build/tests/regression/kyber/kyber -k build/tests/regression/kyber/kernel.vxbin
```

### Using blackbox wrapper

```bash
cd build
./ci/blackbox.sh --driver=simx --app=kyber
```

## RTLsim Mode (Verilator RTL)

RTLsim simulates the actual RTL design with Verilator, providing cycle-accurate results.

```bash
cd build
LD_LIBRARY_PATH=build/runtime VORTEX_DRIVER=rtlsim \
  build/tests/regression/kyber/kyber -k build/tests/regression/kyber/kernel.vxbin
```

### Using blackbox wrapper

```bash
cd build
./ci/blackbox.sh --driver=rtlsim --app=kyber
```

## Understanding Test Output

A successful run prints:

```
======================================================================
  INPUT POLYNOMIALS A and B
======================================================================
Polynomial coefficients modulo 3329
A = [2619, 456, 102, 3037, 1126, 1003, ...]
B = [262, 1384, 86, 2409, 2268, 942, ...]

======================================================================
  GPU TEST
======================================================================

PERF: core0: instrs=192961, cycles=180951, IPC=1.066
=========================================================
  SUMMARY
=========================================================
  Algorithm: NTT(A) || NTT(B) → basemul(â,b̂) → INTT(ĉ) → scale(×3303)
  Parallel threads: 256 total
  Custom instructions: 2816 total
  Synchronization barriers: 16
  Result: ✓ PASSED

=========================================================
  ✓ ALL KYBER TESTS PASSED
  ✓ INPUT POLYNOMIALS VERIFIED
  ✓ NTT(A) VERIFIED
  ✓ NTT(B) VERIFIED
  ✓ BASEMUL VERIFIED
  ✓ INTT VERIFIED
  ✓ FINAL POLYNOMIAL VERIFIED
  ✓ ALL 50 FINAL COMPARISON SAMPLES MATCH
=========================================================
```

### Key metrics

- **core0 instrs**: Total instructions retired on core 0
- **core0 cycles**: Total clock cycles on core 0
- **IPC**: Instructions per cycle
- **Custom instructions**: Count of `vx_ct_butterfly`, `vx_gs_butterfly`, `vx_basemul`
- **Synchronization barriers**: Number of `__syncthreads()` calls
