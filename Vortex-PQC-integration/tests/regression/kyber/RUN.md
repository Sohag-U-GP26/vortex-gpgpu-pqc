# Kyber PQC Test — Build & Run (RTLsim)

## 1. Build kernel

From the repository root:
```bash
make -C build/tests/regression/kyber clean
make -C build/tests/regression/kyber
```

## 2. Run RTLsim

From the repository root:
```bash
LD_LIBRARY_PATH=build/runtime \
VORTEX_DRIVER=rtlsim \
build/tests/regression/kyber/kyber \
-k build/tests/regression/kyber/kernel.vxbin
```
