# VX_gpu_pkg.sv — Global GPU Package

**Path:** `hw/rtl/VX_gpu_pkg.sv`
**Type:** Modified (existing Vortex file)
**Role:** Defines instruction opcodes, ALU types, and pipeline data types

---

## Kyber-Related Modifications

### New Opcode Constants

```systemverilog
INST_ALU_CT_BF   = 5'b00001   // Cooley-Tukey NTT butterfly
INST_ALU_GS_BF   = 5'b00110   // Gentleman-Sande INTT butterfly
INST_ALU_BASEMUL = 5'b10000   // Base polynomial multiplication
```

These opcodes are defined within the existing ALU opcode enum and are decoded in the ALU routing logic.

### ALU Type Assignment

PQC instructions use the **existing** ALU type constants — no new ALU type constants were added:

| Instruction | xtype assigned | Reason |
|-------------|----------------|--------|
| `INST_ALU_CT_BF` | `ALU_TYPE_ARITH` | Arithmetic operation (like ADD/SUB) |
| `INST_ALU_GS_BF` | `ALU_TYPE_ARITH` | Arithmetic operation (like ADD/SUB) |
| `INST_ALU_BASEMUL` | `ALU_TYPE_OTHER` | Multi-cycle, uses wide Barrett reduction |

Source (`VX_decode.sv` lines 549, 553, 557):
```systemverilog
// CT_BF and GS_BF use ALU_TYPE_ARITH
op_args.alu.xtype = ALU_TYPE_ARITH;

// BASEMUL uses ALU_TYPE_OTHER (multi-cycle with different resource needs)
op_args.alu.xtype = ALU_TYPE_OTHER;
```

---

## Impact on Existing Types

| Type/Struct | Modification |
|-------------|-------------|
| `alu_opcodes_t` | Extended with 3 new values |
| `execute_dyn_t` | Unchanged — existing fields sufficient |
| `result_dyn_t` | Unchanged — existing fields sufficient |

No new ALU type constants were added. The existing `ALU_TYPE_ARITH` / `ALU_TYPE_OTHER` constants are reused.

---

## How Opcodes Flow Through the Pipeline

```
Fetch → Decode → op_type = INST_ALU_CT_BF/GS_BF/BASEMUL
               → op_args.alu.xtype = ALU_TYPE_ARITH or ALU_TYPE_OTHER
                      │
                      ▼
              VX_alu_unit selects PE based on op_type + xtype
                      │
                      ▼
              PE wrapper executes the operation
                      │
                      ▼
              Result committed via standard path
```
