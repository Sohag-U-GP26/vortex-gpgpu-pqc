# VX_decode.sv — Instruction Decoder

**Path:** `hw/rtl/core/VX_decode.sv`
**Type:** Modified (existing Vortex file)
**Role:** Decodes RISC-V instructions and maps them to internal operation types

---

## Kyber-Specific Modifications

PQC instructions are decoded in the **`INST_EXT1` custom opcode space** (RISC-V custom-0), using `funct2` at bit positions [26:25] to select the specific operation.

### Decode Logic (lines 536-561)

```systemverilog
// INST_EXT1[6:0] = 7'b0001011 (RISC-V custom-0)
// funct3[14:12] = 3'b000
// funct2[26:25] selects: 00=CT_BF, 01=GS_BF, 10=BASEMUL

if (funct3 == 3'h0 && funct2 <= 2'h2) begin
    ex_type = EX_ALU;                          // Route to ALU
    op_args.alu.use_imm = 0;                   // No immediate
    op_args.alu.use_PC  = 0;                   // Not PC-relative
    op_args.alu.is_w    = 0;                   // Full register width
    // All 4 register fields used: rd, rs1, rs2, rs3
    case (funct2)
        2'b00: op_type = INST_ALU_CT_BF;      // Cooley-Tukey butterfly
        2'b01: op_type = INST_ALU_GS_BF;      // Gentleman-Sande butterfly
        2'b10: op_type = INST_ALU_BASEMUL;    // Base multiplication
    endcase
end
```

### Instruction Encoding (R4-type)

```
31    27 26   25 24     20 19     15 14  12 11      7 6           0
┌───────┬───────┬─────────┬─────────┬──────┬─────────┬─────────────┐
│ rs3   │funct2 │  rs2    │  rs1    │funct3│   rd    │  opcode     │
│       │[26:25]│         │         │=000  │         │INST_EXT1    │
└───────┴───────┴─────────┴─────────┴──────┴─────────┴─────────────┘
```

| funct2[26:25] | Instruction | Kernel Intrinsic |
|---------------|-------------|------------------|
| `2'b00` | CT Butterfly (`INST_ALU_CT_BF`) | `vx_ct_butterfly(rs1, rs2, rs3)` |
| `2'b01` | GS Butterfly (`INST_ALU_GS_BF`) | `vx_gs_butterfly(rs1, rs2, rs3)` |
| `2'b10` | Base Multiply (`INST_ALU_BASEMUL`) | `vx_basemul(rs1, rs2, rs3)` |

### Key Points

1. **`EX_ALU` routing**: All PQC ops are decoded as ALU-type instructions, targeting `VX_alu_unit`
2. **4-register R4 format**: Uses rd, rs1, rs2, rs3 (custom-0 extension with funct2)
3. **`use_imm=0`**: All inputs come from registers (no immediate encoding)
4. **`funct3=000`**: Reserved encoding space, guarded by `funct2 <= 2'h2`
5. **`funct2=11`**: Reserved (no operation assigned)

### Default Case Fallthrough

The PQC decode sits in the `default` case of the `INST_EXT1` decoder, meaning it only triggers when funct3=000 and funct2≤2. All other INST_EXT1 encodings pass through to existing decode logic unchanged.
