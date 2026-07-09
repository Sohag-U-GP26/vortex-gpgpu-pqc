# Papers — Curated Research Literature Guide (Phase 1)

> Part of [Phase 1: Standalone RTL Architecture](../README.md) — research literature that informed the accelerator design.

## Purpose

This directory contains a curated collection of academic papers that informed the design and implementation of this hardware accelerator. Rather than a simple file listing, this guide organizes the literature by topic, explains why each paper matters, and recommends a reading order.

## How to Use This Guide

- **New to NTT hardware?** Start with Category A (Kyber Specification), then Category B (NTT Theory)
- **Implementing an NTT accelerator?** Focus on Categories C, D, and E
- **Concerned about security?** Read Category G before finalizing your design
- **Want formal guarantees?** See Category H

---

## A. Kyber Specification

These papers define the algorithm that this hardware implements.

### 1. CRYSTALS-Kyber, Algorithm Specifications And Supporting Documentation (version 3.02)

- **Why it matters**: This is the authoritative specification of the CRYSTALS-Kyber KEM. It defines all parameters (n=256, q=3329, ζ=17), the NTT algorithm, encoding/decoding, and security levels.
- **Major contribution**: Complete algorithmic specification that became the basis for NIST FIPS-203.
- **Influence on this project**: **Primary reference** — all RTL modules implement operations defined in this document.
- **Read first**: Yes — start here before any other paper.

### 2. CRYSTALS - Kyber, a CCA-secure module-lattice-based KEM

- **Why it matters**: The original academic paper introducing Kyber. Provides the theoretical foundation and security proofs.
- **Major contribution**: Defined the module-LWE problem variant, CCA-secure transformation, and parameter selection.
- **Influence on this project**: Provided the theoretical motivation for why polynomial multiplication is the critical operation to accelerate.
- **Read first**: After the specification document.

### 3. CRYSTALS-Kyber, Algorithm Specifications And Supporting Documentation (version 3.01)

- **Why it matters**: Earlier version of the specification. Useful for understanding how the algorithm evolved.
- **Major contribution**: Shows the development trajectory and parameter tuning.
- **Influence on this project**: Referenced for historical context; the v3.02 specification is the definitive reference.

---

## B. NTT Theory

These papers cover the mathematical foundations of the Number Theoretic Transform and its variants.

### 4. Number Theoretic Transform and Its Applications in Lattice-based Cryptosystems

- **Why it matters**: Comprehensive introduction to NTT in the context of lattice-based cryptography. Covers the relationship between NTT and FFT, choice of modulus, and root selection.
- **Major contribution**: Explains why NTT reduces O(n²) polynomial multiplication to O(n log n) and how to choose parameters for cryptographic security.
- **Influence on this project**: Guided the decision to use the Cooley-Tukey butterfly for forward NTT and Gentleman-Sande for inverse NTT.

### 5. Speeding up the Number Theoretic Transform for Faster Ideal Lattice-Based Cryptography

- **Why it matters**: Classic paper on practical NTT optimization. Introduces techniques like layer merging and twiddle factor precomputation.
- **Major contribution**: Demonstrated that careful NTT implementation can make lattice-based cryptography practical for real-world use.
- **Influence on this project**: Influenced the pipeline design and twiddle factor ROM organization.

### 6. Incompleteness in Number-Theoretic Transforms: New Tradeoffs and Faster Lattice-Based Cryptographic Applications

- **Why it matters**: Explores the concept of "incomplete NTT" where the transform stops at degree-2 polynomials rather than degree-1 — exactly what Kyber uses.
- **Major contribution**: Formal analysis of the incomplete NTT trade-off between transform depth and post-transform multiplication complexity.
- **Influence on this project**: Justifies why Kyber stops at degree-2 pairs (128 pairs of 2) and requires basecase multiplication.

### 7. Explicit cost analysis of Toom-4 multiplication for incomplete NTT in lattice-based cryptography

- **Why it matters**: Compares Toom-Cook and NTT-based multiplication strategies for incomplete NTT settings.
- **Major contribution**: Quantifies the crossover point where one method becomes more efficient than the other.
- **Influence on this project**: Confirmed that NTT is the right choice for Kyber's parameter set.

---

## C. Hardware Accelerators

These papers describe dedicated ASIC/FPGA NTT accelerator designs.

### 8. High-Speed NTT-based Polynomial Multiplication Accelerator for CRYSTALS-Kyber Post-Quantum Cryptography

- **Why it matters**: Directly addresses the same problem as this project — hardware acceleration of Kyber polynomial multiplication.
- **Major contribution**: Complete accelerator architecture with detailed area, timing, and throughput results on FPGA.
- **Influence on this project**: **Primary hardware reference** — influenced the pipelining strategy, Barrett reduction approach, and module partitioning.

### 9. Area-time efficient pipelined number theoretic transform for CRYSTALS-Kyber

- **Why it matters**: Focuses on the area-time tradeoff, which is critical for embedded deployments.
- **Major contribution**: Achieves high throughput with minimal area by reusing butterfly units across NTT stages.
- **Influence on this project**: The iterative butterfly approach (single ct_butterfly reused 127 times) is inspired by this work.

### 10. Designing Efficient and Flexible NTT Accelerators

- **Why it matters**: Explores flexible NTT architectures that can support multiple parameter sets (different n, q).
- **Major contribution**: Parameterized datapath design that can be configured at compile time.
- **Influence on this project**: Motivated the use of `parameter` and `localparam` in RTL for configurability.

### 11. Efficient Accelerator for NTT-based Polynomial Multiplication

- **Why it matters**: Proposes a high-efficiency architecture with particular attention to the basecase multiplication step.
- **Major contribution**: Novel basecase multiplier architecture that reduces DSP usage.
- **Influence on this project**: The shift-add-subtract approach in `basemul_kyber_v2` was influenced by this work's multiplier-free philosophy.

---

## D. FPGA Implementations

These papers focus on FPGA-specific optimizations.

### 12. Optimized Quantum-Resistant Cryptosystem: Integrating Kyber-KEM with Hardware TRNG on Zynq Platform

- **Why it matters**: Complete Kyber KEM on a Zynq FPGA, including integration with a true random number generator.
- **Major contribution**: Demonstrates a full-system Kyber implementation (not just polynomial multiplication) on a real FPGA platform.
- **Influence on this project**: Shows the broader system context — how the polynomial multiply accelerator fits into a complete Kyber KEM.

### 13. Fully Homomorphic Encryption Accelerators

- **Why it matters**: While focused on FHE (not Kyber), this paper covers large-word NTT architectures applicable to all lattice-based cryptography.
- **Major contribution**: Novel memory hierarchy and data reuse strategies for NTT operations.
- **Influence on this project**: Memory organization concepts can be applied when building the full Kyber KEM FSM.

---

## E. GPU Implementations

These papers demonstrate NTT acceleration on GPU platforms.

### 14. Accelerating Number Theoretic Transformations for Bootstrappable Homomorphic Encryption on GPUs

- **Why it matters**: Shows that NTT can be massively parallelized on GPU hardware.
- **Major contribution**: GPU-optimized NTT with batched processing for throughput-oriented applications.
- **Influence on this project**: While this project targets FPGA/ASIC, the parallelization strategies inform the pipeline architecture.

### 15. Two Algorithms for Fast GPU Implementation of NTT

- **Why it matters**: Compares different GPU NTT algorithms and identifies optimal strategies for different problem sizes.
- **Major contribution**: Systematic performance model for GPU NTT execution.
- **Influence on this project**: Useful for understanding memory bandwidth and compute utilization tradeoffs.

### 16. Faster AVX2 optimized NTT multiplication for Ring-LWE lattice cryptography

- **Why it matters**: CPU-optimized NTT using AVX2 SIMD instructions — the state of the art in software implementations.
- **Major contribution**: Demonstrates that careful vectorization achieves near-optimal software performance.
- **Influence on this project**: Establishes the software baseline that the hardware accelerator must outperform.

---

## F. Optimization

### 17. NTT Multiplication for NTT-unfriendly Rings

- **Why it matters**: Addresses NTT when the modulus does not have a primitive n-th root of unity (requires NTT-unfriendly techniques).
- **Major contribution**: Algorithms for handling rings where standard NTT is not directly applicable.
- **Influence on this project**: Kyber's modulus (3329) is NTT-friendly, so this paper is context rather than direct reference.

---

## G. Security

These papers address side-channel attacks and countermeasures for NTT-based implementations.

### 18. Breaking DPA-protected Kyber via the pair-pointwise multiplication

- **Why it matters**: Demonstrates a differential power analysis (DPA) attack specifically targeting the basecase multiplication step — a module this project implements.
- **Major contribution**: Shows that even masked implementations can leak through the basecase multiplication structure.
- **Influence on this project**: **Critical reading** — motivated the constant-time design of `basemul_kyber_v2` and the mask-based selection in all reduction modules.
- **Read before finalizing design**: Yes — understand the attack surface before signing off on the architecture.

### 19. Zero-Value Filtering for Accelerating Non-Profiled Side-Channel Attack on Incomplete NTT based Implementations of Lattice-based Cryptography

- **Why it matters**: Exploits zero coefficients in the NTT domain to accelerate side-channel attacks.
- **Major contribution**: Attack vector that leverages the sparse structure of NTT-domain polynomials.
- **Influence on this project**: Highlights the need for uniform processing regardless of coefficient values — supports the constant-time design approach.

---

## H. Formal Verification

### 20. Formally Verified Number-Theoretic Transform

- **Why it matters**: Uses formal methods (theorem proving) to mathematically verify NTT correctness.
- **Major contribution**: Complete formal verification of an NTT implementation against its specification.
- **Influence on this project**: Demonstrates that NTT correctness can be proven mathematically, not just tested. Inspires future formal verification of this project's RTL.

---

## Reading Order Summary

| Order | Paper | Focus | Estimated Time |
|-------|-------|-------|----------------|
| 1 | #1 — Kyber Spec v3.02 | Algorithm specification | Essential |
| 2 | #2 — Original Kyber paper | Theoretical foundations | Essential |
| 3 | #4 — NTT in lattice crypto | NTT fundamentals | Essential |
| 4 | #6 — Incomplete NTT | Kyber-specific NTT | Essential |
| 5 | #8 — High-Speed NTT Accelerator | Hardware architecture | Essential |
| 6 | #9 — Area-time pipelined NTT | Hardware optimization | Recommended |
| 7 | #18 — DPA on Kyber basecase | Security | Critical |
| 8 | #12 — Kyber on Zynq | FPGA integration | Recommended |
| 9 | #5 — Speeding up NTT | Algorithm optimization | Reference |
| 10 | #20 — Formal NTT verification | Formal methods | Advanced |

## File Index

| File | Category |
|------|----------|
| `CRYSTALS - Kyber, a CCA-secure module-lattice-based KEM.pdf` | A — Specification |
| `CRYSTALS-Kyber, Algorithm Specifications And Supporting Documentation (version 3.02).pdf` | A — Specification |
| `CRYSTALS-Kyber, Algorithm Specifications And Supporting Documentation(version 3.01).pdf` | A — Specification |
| `Number Theoretic Transform and Its Applications in Lattice-based Cryptosystems.pdf` | B — NTT Theory |
| `Speeding up the Number Theoretic Transform for Faster Ideal Lattice-Based Cryptography.pdf` | B — NTT Theory |
| `Incompleteness in Number-Theoretic Transforms, New Tradeoffs and Faster Lattice-Based Cryptographic Applications.pdf` | B — NTT Theory |
| `Explicit cost analysis of Toom-4 multiplication for incomplete NTT in lattice-based cryptography.pdf` | B — NTT Theory |
| `High-Speed NTT-based Polynomial Multiplication Accelerator for CRYSTALS-Kyber Post-Quantum Cryptography.pdf` | C — Hardware Accelerators |
| `Area-time efficient pipelined number theoretic transform for CRYSTALS-Kyber.pdf` | C — Hardware Accelerators |
| `Designing Efficient and Flexible NTT Accelerators.pdf` | C — Hardware Accelerators |
| `Efficient Accelerator for NTT-based Polynomial Multiplication.pdf` | C — Hardware Accelerators |
| `Optimized Quantum-Resistant Cryptosystem, Integrating Kyber-KEM with Hardware TRNG on Zynq Platform.pdf` | D — FPGA Implementations |
| `Fully Homomorphic Encryption Accelerators.pdf` | D — FPGA Implementations |
| `Accelerating Number Theoretic Transformations for Bootstrappable Homomorphic Encryption on GPUs.pdf` | E — GPU Implementations |
| `Two Algorithms for Fast GPU Implementation of NTT.pdf` | E — GPU Implementations |
| `Faster AVX2 optimized NTT multiplication for Ring-LWE lattice cryptography.pdf` | E — GPU Implementations |
| `NTT Multiplication for NTT-unfriendly Rings.pdf` | F — Optimization |
| `Breaking DPA-protected Kyber via the pair-pointwise multiplication.pdf` | G — Security |
| `Zero-Value Filtering for Accelerating Non-Profiled Side-Channel Attack on Incomplete NTT based Implementations of Lattice-based Cryptography.pdf` | G — Security |
| `Formally Verified Number-Theoretic Transform.pdf` | H — Formal Verification |
| `Kyber - Resources.html` | — Links and additional resources |
