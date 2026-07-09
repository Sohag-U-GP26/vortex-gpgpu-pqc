# simx/types.h — SimX Type Definitions

**Path:** `sim/simx/types.h`
**Type:** Modified (existing Vortex file)
**Role:** Defines `AluType` enum for the SimX cycle-approximate simulator

---

## Kyber-Specific Modifications

### AluType Enum (lines 173-175)

```cpp
enum class AluType {
  // ... existing integer ALU types (LUI, ADD, SUB, SLL, ...)
  CT_BF,    // Cooley-Tukey NTT butterfly
  GS_BF,    // Gentleman-Sande INTT butterfly
  BASEMUL   // Base polynomial multiplication
};
```

### Stream Operator (lines 199-201)

```cpp
case AluType::CT_BF:   os << "CT_BF";   break;
case AluType::GS_BF:   os << "GS_BF";   break;
case AluType::BASEMUL: os << "BASEMUL"; break;
```

---

## Usage

The `AluType` enum is the SimX-side equivalent of the Verilog `INST_ALU_*` opcodes. When the SimX decoder encounters a PQC instruction, it maps `funct2` to `AluType::CT_BF`, `AluType::GS_BF`, or `AluType::BASEMUL`, which is then used by `func_unit.cpp` to compute the correct execution delay.
