# Data Flow — Kyber PQC Operations

## Operand Encoding & Pipeline Data Movement

### Register Operand Packing

All Kyber PQC instructions use three source register operands (rs1, rs2, rs3). Since the Vortex GPGPU has a 64-bit datapath (XLEN=64), multiple 12-bit coefficients are packed into each register.

### CT Butterfly: Operand → Result

```
rs1 = {52'b0, A_coeff[11:0]}        // A coefficient (lower bits)
rs2 = {52'b0, B_coeff[11:0]}        // B coefficient
rs3 = {52'b0, W_twiddle[11:0]}      // W twiddle factor

result = {52'b0, B_out[15:0], A_out[15:0]}
                    │           │
                    │           └─ A' coefficient (12-bit, zero-padded to 16)
                    └─ B' coefficient (12-bit, zero-padded to 16)
```

### GS Butterfly: Operand → Result

Same encoding as CT butterfly above.

### Base Multiply: Operand → Result

```
rs1 = {B1[11:0], A1[11:0]}          // B1 in high 12 bits, A1 in low 12 bits
rs2 = {B0[11:0], A0[11:0]}          // B0 in high 12 bits, A0 in low 12 bits
rs3 = {52'b0, zeta[11:0]}           // ζ twiddle factor

result = {48'b0, C1[15:0], C0[15:0]}
                     │          │
                     │          └─ C0 coefficient (12-bit, padded to 16)
                     └─ C1 coefficient (12-bit, padded to 16)
```

---

## Data Flow Within the ALU Pipeline

### Step-by-step: CT Butterfly

```
Cycle 0 (Dispatch):
  execute_if.valid = 1
  execute_if.op_type = INST_ALU_CT_BF
  execute_if.rs1_data = A          (via issue from regfile/bypass)
  execute_if.rs2_data = B
  execute_if.rs3_data = W

Cycle 1 (PE Stage 0):
  VX_alu_ct_butterfly captures operands
  ct_butterfly unit:
    product = B * W                              (12x12 mult)
    prod_mod = barrett_reduction(product)         (24→12 bit)

Cycle 2 (PE Stage 1):
  A_out = modq(A + prod_mod)                     (add + correct)
  B_out = modq(A - prod_mod)                     (sub + correct)
  result_if.valid = 1
  result_if.result_data = {A_out, B_out}

Cycle 3 (Commit):
  Result written to destination register rd
```

### Step-by-step: GS Butterfly

```
Cycle 0 (Dispatch):
  execute_if.op_type = INST_ALU_GS_BF
  execute_if.rs1_data = A
  execute_if.rs2_data = B
  execute_if.rs3_data = W

Cycle 1 (PE Stage 0):
  VX_alu_gs_butterfly captures operands
  gs_butterfly unit:
    A_sum = modq(A + B)                          (add + correct)
    B_diff = modq(A - B)                         (sub + correct)
    product = B_diff * W                         (12x12 mult)

Cycle 2 (PE Stage 1):
    B_out = barrett_reduction(product)           (24→12 bit)
    A_out = A_sum                                (from pipeline reg)
    result_if.valid = 1
    result_if.result_data = {A_out, B_out}
```

### Step-by-step: Base Multiply

```
Cycle 0 (Dispatch):
  execute_if.op_type = INST_ALU_BASEMUL
  execute_if.rs1_data = {B1, A1}
  execute_if.rs2_data = {B0, A0}
  execute_if.rs3_data = zeta

Cycle 1 (PE Stage 0):
  VX_alu_basemul captures operands
  basemul_kyber_v2 unit:
    P00 = A0 * B0                                (12x12 mult)
    P01 = A0 * B1                                (12x12 mult)
    P10 = A1 * B0                                (12x12 mult)
    P11 = A1 * B1                                (12x12 mult)
    P11zeta = P11 * zeta                         (12x12 mult)

Cycle 2 (PE Stage 1):
    sum_C0 = P00 + P11zeta                       (24-bit sum, may overflow)
    sum_C1 = P01 + P10                           (24-bit sum, may overflow)

Cycle 3 (PE Stage 2):
    C0 = barrett_reduction_kyber_wide(sum_C0)   (36→12 bit)
    C1 = barrett_reduction_kyber_wide(sum_C1)
    result_if.valid = 1
    result_if.result_data = {16'b0, C1, 16'b0, C0}
```

---

## Data Width Pipeline

```
Module            Input Widths     Internal Widths    Output Widths
───────           ────────────     ───────────────    ────────────
ct_butterfly      12 + 12 + 12     24, 12             12 + 12
gs_butterfly      12 + 12 + 12     24, 12             12 + 12
basemul_kyber_v2  12×5             24, 36             12 + 12
barrett_reduction 24               24                 12
barrett_wide      36               36                 12
modq              16 (signed)      16                 12
kyber_final_mult  12               24                 12
```

## NTT Computation Flow (256-point)

Kyber (FIPS 203) uses a 7-layer NTT for N=256:

```
Step 1: Bit-reversed ordering of 256 coefficients
Step 2: Layer 0 — 128 × CT_BF (ζ = 17^64 mod 3329)
Step 3: Layer 1 — 128 × CT_BF (ζ = 17^32 mod 3329)
Step 4: Layer 2 — 128 × CT_BF (ζ = 17^16 mod 3329)
Step 5: Layer 3 — 128 × CT_BF
Step 6: Layer 4 — 128 × CT_BF
Step 7: Layer 5 — 128 × CT_BF
Step 8: Layer 6 — 128 × CT_BF (ζ = 17^1 mod 3329 = 17)
         Total: 7 layers × 128 butterflies = 896 CT_BF instructions
```
