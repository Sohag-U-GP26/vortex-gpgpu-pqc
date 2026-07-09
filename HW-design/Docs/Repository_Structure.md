# Repository Structure

## Top-Level Layout

```
HW-design/                      # Phase 1: Standalone RTL (see root README for project overview)
├── Design/                     # RTL source files (SystemVerilog)
├── TB/                         # Verification environment
│   ├── Do_Files/               # ModelSim simulation scripts
│   └── Ref/                    # Reference vectors for verification
├── Golden-python-model/        # Python golden reference implementation
├── Papers/                     # Research literature collection
├── Docs/                       # Architecture and design documentation
└── README.md                   # Phase 1 landing page
```

## Directory Roles

### `Design/` — RTL Implementation

Contains all SystemVerilog hardware design modules. Each file implements one self-contained module with a well-defined interface, documented pipeline depth, and constant-time arithmetic.

**Modules:**
- `modq.sv` — Conditional addition/subtraction reduction
- `barrett_reduction_kyber.sv` — 24-bit Barrett reduction
- `barrett_reduction_kyber_wide.sv` — 36-bit Barrett reduction
- `ct_butterfly.sv` — Cooley-Tukey butterfly (NTT)
- `gs_butterfly.sv` — Gentleman-Sande butterfly (INTT)
- `basemul_kyber_v2.sv` — Basecase polynomial multiplication
- `kyber_final_mult.sv` — Final scaling after INTT

See [Design/README.md](../Design/README.md) for detailed module documentation.

### `TB/` — Verification Environment

Contains SystemVerilog testbenches at two levels of abstraction:

1. **Simple testbenches** (`tb_<module>_simple.sv`): Validate individual modules in isolation with manually crafted test vectors.

2. **Full integration testbenches** (`tb_ntt_full.sv`, `tb_intt_full.sv`): Drive the full NTT/INTT pipeline and compare against reference vectors.

**Subdirectories:**
- `Do_Files/`: ModelSim `.do` scripts for automated compile-and-run
- `Ref/`: Golden reference vectors (text and hex files)

See [TB/README.md](../TB/README.md) for the complete verification guide.

### `Golden-python-model/` — Reference Algorithm

A Python implementation of the complete Kyber NTT-based polynomial multiplication:

- Forward NTT (Cooley-Tukey, 7 stages)
- Inverse NTT (Gentleman-Sande, 7 stages + final scaling)
- Basecase multiplication (degree-1 polynomial pairs)
- Reference vector generation for RTL verification
- Naive O(n²) multiplication for cross-validation

This is the **ground truth** for all hardware verification. Every RTL output is compared against the Python model's output.

### `Papers/` — Research Literature

A curated collection of academic papers organized by topic:

- Kyber specification and standards
- NTT theory and algorithms
- Hardware accelerator architectures
- FPGA and GPU implementations
- Side-channel security and formal verification

See [Papers/README.md](../Papers/README.md) for the guided reading guide.

### `Docs/` — Technical Documentation

Architecture and design documentation describing the project's organization, decisions, and conventions:

| File | Content |
|------|---------|
| `Architecture.md` | System architecture, NTT pipeline, design philosophy |
| `Module_Interactions.md` | Module dependency graph and data flow |
| `Repository_Structure.md` | This file — directory roles and organization |

## How Directories Interact

```
┌─────────────────────────────────────────────────────────────────┐
│                    Design Flow Diagram                          │
│                                                                 │
│  Golden-python-model/        Papers/                            │
│  ┌──────────────────┐       ┌───────────────────┐               │
│  │ kyber_ntt.py     │───┬─▶│ NTT Theory        │               │
│  │ Golden Reference │   │   │ Hardware Design   │               │
│  │ Test Vectors     │   │   │ Security Analysis │               │
│  └────────┬─────────┘   │   └───────────────────┘               │
│           │             │                                       │
│           ▼             │                                       │
│  ┌─────────────────────────────────────────────────┐            │
│  │  Design/          TB/                           │            │
│  │  ┌────────────┐  ┌────────────────────────┐     │            │
│  │  │ RTL Modules│◄─┤ Testbenches            │     │            │
│  │  │ .sv files  │  │ Simple + Full TBs      │     │            │
│  │  └────────────┘  │ Do_Files/ (sim scripts)│     │            │
│  │                  │ Ref/ (golden vectors)  │     │            │
│  │                  └────────────────────────┘     │            │
│  └─────────────────────────────────────────────────┘            │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────┐                       │
│  │  Docs/                               │                       │
│  │  Architecture and design docs        │                       │
│  └──────────────────────────────────────┘                       │   
└─────────────────────────────────────────────────────────────────┘
```

## File Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| RTL modules | `lowercase_underscore.sv` | `barrett_reduction_kyber.sv` |
| Testbenches | `tb_<module>.sv` | `tb_ntt_full.sv` |
| Simulation scripts | `run_<test>.do` | `run_ntt.do` |
| Reference vectors | `<description>.txt\|.hex` | `a_ntt_output.txt` |
| Python scripts | `lowercase_underscore.py` | `kyber_ntt.py` |
| Documentation | `Title_Case.md` | `Architecture.md` |

## Path Dependencies

Testbenches reference reference vectors using relative paths from the simulation working directory. The typical simulation workflow runs from the `TB/` directory:

```
# From TB/:
vsim -do Do_Files/run_ntt.do
```

This means DO files specify source paths relative to the compile script's working directory, and testbenches reference `Ref/` files as `../Ref/<file>.txt` or `Ref/<file>.txt` depending on the execution context.
