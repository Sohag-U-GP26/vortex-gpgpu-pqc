# Glossary — Kyber PQC Integration

---

## Kyber / PQC Terminology

| Term | Definition |
|------|------------|
| **Kyber** | CRYSTALS-Kyber, a NIST-standardized post-quantum key encapsulation mechanism (ML-KEM). Based on the Module-LWE problem. |
| **ML-KEM** | Module-Lattice-Based Key Encapsulation Mechanism — NIST's designation for the standardized Kyber variant. |
| **PQC** | Post-Quantum Cryptography — cryptographic algorithms believed to be secure against attack by quantum computers. |
| **q** | Kyber modulus: 3329. All polynomial arithmetic is performed modulo q. |
| **N** | Polynomial degree: 256. Kyber operates on polynomials of degree less than 256. |
| **ζ (zeta)** | Primitive N-th root of unity modulo q (ζ = 17 for Kyber). Used as twiddle factor in NTT. |
| **ω (omega)** | Primitive 2N-th root of unity modulo q (ω = 3844 for Kyber). Related to ζ by ω² = ζ. |
| **ψ (psi)** | Primitive 2N-th root of unity used for pre-/post-processing in Kyber NTT. |

## NTT / INTT Terminology

| Term | Definition |
|------|------------|
| **NTT** | Number Theoretic Transform — a discrete Fourier transform over a finite field. Used to accelerate polynomial multiplication in Kyber from O(N²) to O(N log N). |
| **INTT** | Inverse Number Theoretic Transform — the inverse of NTT. |
| **CT Butterfly** | Cooley-Tukey butterfly — the standard NTT butterfly. Computes (A, B, W) → (A + B·W, A − B·W) mod q. |
| **GS Butterfly** | Gentleman-Sande butterfly — the standard INTT butterfly. Computes (A, B, W) → (A + B, (A − B)·W) mod q. |
| **Twiddle factor** | A precomputed root of unity used in a butterfly operation. |
| **Base multiplication** | Polynomial multiplication modulo X² − ζ. Core operation in Kyber's NTT-domain multiplication. |

## Modular Arithmetic Terminology

| Term | Definition |
|------|------------|
| **Barrett reduction** | An algorithm for computing r = a mod m without division. Uses precomputed (1/m) and multiplication+shift. Efficient in hardware. |
| **mod q** | Reduction modulo 3329. |
| **Canonical form** | A value in [0, q-1] after reduction. |
| **Schoolbook multiplication** | Standard O(n²) polynomial multiplication (as opposed to NTT-based). |

## Vortex / Hardware Terminology

| Term | Definition |
|------|------------|
| **Vortex** | Open-source RISC-V GPGPU architecture. Supports SIMT execution model. |
| **ALU** | Arithmetic Logic Unit — the functional unit in Vortex that executes arithmetic/logic operations. |
| **PE** | Processing Element — a sub-unit of the ALU dedicated to a specific operation type (e.g., INT, MUL, CT_BF). |
| **PE switch** | The routing mechanism in `VX_alu_unit` that dispatches instructions to the correct processing element. |
| **SIMT** | Single Instruction, Multiple Threads — the execution model used by GPUs. |
| **Warp** | A group of threads that execute the same instruction simultaneously (SIMT). Equivalent to NVIDIA's warp concept. |
| **Pipeline latency** | The number of clock cycles between instruction dispatch and result availability. |
| **rs1/rs2/rs3** | RISC-V source register operands. |
| **XLEN** | Register width of the RISC-V core (32 or 64 bits). |
| **SimX** | Cycle-approximate C++ simulator for Vortex. Used as a reference model. |
| **rtlsim** | RTL-level simulation of the Vortex processor. |
| **VCD** | Value Change Dump — Verilog waveform dump format. |
| **GPGPU** | General-Purpose computing on Graphics Processing Units. |
| **TCU** | Tensor Core Unit — Vortex's tensor processing extension. |
| **LSU** | Load-Store Unit — handles memory operations. |

## Vortex Pipeline Terminology

| Term | Definition |
|------|------------|
| **Fetch** | Pipeline stage that reads instructions from the instruction cache. |
| **Decode** | Pipeline stage that decodes the instruction and reads the register file. |
| **Dispatch** | Pipeline stage that sends the instruction to the correct functional unit (ALU, LSU, FPU, etc.). |
| **Issue** | Pipeline stage that waits for operands (scoreboard) and issues to the execution unit. |
| **Execute** | The ALU execution stage(s) — where PQC operations are performed. |
| **Commit** | Pipeline stage that writes results back to the register file. |
| **Scoreboard** | Hardware structure tracking register dependencies to detect hazards. |
| **Forwarding** | Bypassing results to dependent instructions to avoid stalls. |

## Vortex Architecture Components

| Term | Definition |
|------|------------|
| **VX_config.vh** | Global configuration header — defines ALU count, pipeline latencies, cluster topology. |
| **VX_gpu_pkg.sv** | SystemVerilog package — defines opcodes, types, and helper constants. |
| **VX_alu_unit.sv** | Top-level ALU unit — instantiates and routes to all PEs. |
| **VX_pe_switch** | Module within VX_alu_unit that selects one PE's output per instruction. |
| **VX_pe_serializer** | Module that aligns multiple pipeline lanes for PE integration. |
