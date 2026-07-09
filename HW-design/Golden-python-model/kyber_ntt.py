"""
Kyber NTT/INTT Implementation with Precomputed Twiddle Factor Arrays
=====================================================================

This module implements the Number Theoretic Transform (NTT) for CRYSTALS-Kyber.

Parameters:
    n = 256 (polynomial degree)
    q = 3329 (prime modulus)
    
Kyber uses a "negative wrapped convolution" NTT that stops at degree-2 polynomials,
requiring a basecase multiplication step.

Algorithm:
    - Forward NTT: Cooley-Tukey (CT) butterfly, in-place, 7 stages
    - Inverse NTT: Gentleman-Sande (GS) butterfly, in-place, 7 stages
"""

import random
import json

# ============================================================================
# KYBER PARAMETERS
# ============================================================================

N = 256              # Polynomial degree
Q = 3329             # Prime modulus
N_INV = 3303         # Inverse of N: 256^(-1) mod 3329
ROOT = 17            # Primitive 256th root of unity mod 3329

# ============================================================================
# PRECOMPUTED TWIDDLE FACTORS
# ============================================================================

def bit_reverse(x, bits):
    """Bit-reverse an integer."""
    result = 0
    for _ in range(bits):
        result = (result << 1) | (x & 1)
        x >>= 1
    return result

def compute_zetas():
    """Compute all 128 twiddle factors for Kyber NTT."""
    zetas = [0] * 128
    for i in range(128):
        br = bit_reverse(i, 7)
        zetas[i] = pow(ROOT, br, Q)
    return zetas

# Generate zetas at module load
ZETAS = compute_zetas()

# ============================================================================
# MODULAR ARITHMETIC HELPERS
# ============================================================================

def mod_q(a):
    """Reduce a modulo q to range [0, q-1]"""
    return a % Q

# ============================================================================
# FORWARD NTT (Cooley-Tukey) WITH STAGE TRACKING
# ============================================================================

def ntt_with_stages(poly):
    """
    Compute the forward NTT with stage-by-stage tracking.
    Returns the final result and a list of all intermediate stages.
    """
    r = [mod_q(c) for c in poly]
    stages = [r.copy()]  # Stage 0: input
    
    k = 1
    length = 128
    stage_num = 1
    
    while length >= 2:
        start = 0
        while start < N:
            zeta = ZETAS[k]
            k += 1
            for j in range(start, start + length):
                t = mod_q(zeta * r[j + length])
                r[j + length] = mod_q(r[j] - t)
                r[j] = mod_q(r[j] + t)
            start += 2 * length
        stages.append(r.copy())
        length //= 2
        stage_num += 1
    
    return r, stages

def ntt(poly):
    """Compute forward NTT (wrapper)."""
    result, _ = ntt_with_stages(poly)
    return result

# ============================================================================
# INVERSE NTT (Gentleman-Sande) WITH STAGE TRACKING
# ============================================================================

def intt_with_stages(poly):
    """
    Compute the inverse NTT with stage-by-stage tracking.
    Returns the final result and a list of all intermediate stages.
    """
    r = [mod_q(c) for c in poly]
    stages = [r.copy()]  # Stage 0: input
    
    k = 127
    length = 2
    
    while length <= 128:
        start = 0
        while start < N:
            zeta = ZETAS[k]
            k -= 1
            for j in range(start, start + length):
                t = r[j]
                r[j] = mod_q(t + r[j + length])
                r[j + length] = mod_q(zeta * (r[j + length] - t))
            start += 2 * length
        stages.append(r.copy())
        length *= 2
    
    # Scale by N^(-1)
    for i in range(N):
        r[i] = mod_q(r[i] * N_INV)
    stages.append(r.copy())  # Final scaled result
    
    return r, stages

def intt(poly):
    """Compute inverse NTT (wrapper)."""
    result, _ = intt_with_stages(poly)
    return result

# ============================================================================
# BASECASE MULTIPLICATION
# ============================================================================

def basemul(a0, a1, b0, b1, zeta):
    """
    Kyber basecase multiplication for degree-1 polynomials.
    Computes (a0 + a1*X) * (b0 + b1*X) mod (X^2 - zeta)
    """
    r0 = mod_q(a0 * b0 + a1 * b1 * zeta)
    r1 = mod_q(a0 * b1 + a1 * b0)
    return r0, r1

def poly_basemul(a_ntt, b_ntt):
    """Basecase multiplication for full polynomials in NTT domain."""
    c_ntt = [0] * N
    for i in range(64):
        zeta = ZETAS[64 + i]
        idx = 4 * i
        c_ntt[idx], c_ntt[idx + 1] = basemul(
            a_ntt[idx], a_ntt[idx + 1],
            b_ntt[idx], b_ntt[idx + 1],
            zeta
        )
        c_ntt[idx + 2], c_ntt[idx + 3] = basemul(
            a_ntt[idx + 2], a_ntt[idx + 3],
            b_ntt[idx + 2], b_ntt[idx + 3],
            mod_q(Q - zeta)
        )
    return c_ntt

# ============================================================================
# FULL POLYNOMIAL MULTIPLICATION
# ============================================================================

def poly_mul(a, b):
    """Multiply two polynomials using NTT."""
    a_ntt = ntt(a)
    b_ntt = ntt(b)
    c_ntt = poly_basemul(a_ntt, b_ntt)
    c = intt(c_ntt)
    return c

def poly_mul_naive(a, b):
    """Naive O(n^2) polynomial multiplication for verification."""
    c = [0] * N
    for i in range(N):
        for j in range(N):
            k = (i + j) % N
            if i + j >= N:
                c[k] = mod_q(c[k] - a[i] * b[j])
            else:
                c[k] = mod_q(c[k] + a[i] * b[j])
    return c

# ============================================================================
# HELPER: FORMAT ARRAY AS MATRIX
# ============================================================================

def format_as_matrix(arr, cols=16):
    """Format array as matrix string."""
    rows = []
    for i in range(0, len(arr), cols):
        row = arr[i:i+cols]
        rows.append("  [" + ", ".join(f"{v:4d}" for v in row) + "]")
    return "[\n" + ",\n".join(rows) + "\n]"

# ============================================================================
# DEMONSTRATION & TESTING
# ============================================================================

if __name__ == "__main__":
    print("=" * 80)
    print("KYBER NTT/INTT Implementation - Complete 256-Element Output")
    print("=" * 80)
    print(f"\nParameters: N={N}, Q={Q}, NTT Stages=7")
    
    # ========================================
    # ZETAS ARRAY (all 128 values)
    # ========================================
    print("\n" + "=" * 80)
    print("ZETAS ARRAY (128 twiddle factors)")
    print("=" * 80)
    print(format_as_matrix(ZETAS, 16))
    
    # ========================================
    # Input Polynomial A
    # ========================================
    random.seed(42)
    poly_a = [random.randint(0, Q - 1) for _ in range(N)]
    
    print("\n" + "=" * 80)
    print("INPUT POLYNOMIAL A (256 coefficients)")
    print("=" * 80)
    print(format_as_matrix(poly_a, 16))
    
    # ========================================
    # Forward NTT with all stages
    # ========================================
    print("\n" + "=" * 80)
    print("FORWARD NTT STAGES")
    print("=" * 80)
    
    ntt_result, ntt_stages = ntt_with_stages(poly_a)
    
    print("\n--- Stage 0: Input ---")
    print(format_as_matrix(ntt_stages[0], 16))
    
    for i in range(1, len(ntt_stages)):
        length = 128 // (2 ** (i - 1))
        print(f"\n--- Stage {i}: After length={length} butterflies ---")
        print(format_as_matrix(ntt_stages[i], 16))
    
    # ========================================
    # Inverse NTT with all stages
    # ========================================
    print("\n" + "=" * 80)
    print("INVERSE NTT STAGES")
    print("=" * 80)
    
    intt_result, intt_stages = intt_with_stages(ntt_result)
    
    print("\n--- Stage 0: Input (NTT domain) ---")
    print(format_as_matrix(intt_stages[0], 16))
    
    for i in range(1, len(intt_stages) - 1):
        length = 2 ** i
        print(f"\n--- Stage {i}: After length={length} butterflies ---")
        print(format_as_matrix(intt_stages[i], 16))
    
    print(f"\n--- Final: After N^-1 scaling ---")
    print(format_as_matrix(intt_stages[-1], 16))
    
    # ========================================
    # Verify roundtrip
    # ========================================
    print("\n" + "=" * 80)
    print("ROUNDTRIP VERIFICATION")
    print("=" * 80)
    roundtrip_ok = all(poly_a[i] == intt_result[i] for i in range(N))
    print(f"INTT(NTT(A)) == A: {roundtrip_ok}")
    
    # ========================================
    # Polynomial Multiplication
    # ========================================
    print("\n" + "=" * 80)
    print("POLYNOMIAL MULTIPLICATION")
    print("=" * 80)
    
    poly_b = [random.randint(0, Q - 1) for _ in range(N)]
    
    print("\n--- Input Polynomial B ---")
    print(format_as_matrix(poly_b, 16))
    
    # NTT of A and B
    a_ntt = ntt(poly_a)
    b_ntt = ntt(poly_b)
    
    print("\n--- NTT(A) ---")
    print(format_as_matrix(a_ntt, 16))
    
    print("\n--- NTT(B) ---")
    print(format_as_matrix(b_ntt, 16))
    
    # Basecase multiplication
    c_ntt = poly_basemul(a_ntt, b_ntt)
    
    print("\n--- Basecase Multiplication Result (NTT domain) ---")
    print(format_as_matrix(c_ntt, 16))
    
    # INTT with stages for c_ntt
    c_result, c_intt_stages = intt_with_stages(c_ntt)
    
    print("\n--- Final Result C = A * B ---")
    print(format_as_matrix(c_result, 16))
    
    # Verify with naive
    c_naive = poly_mul_naive(poly_a, poly_b)
    mul_ok = all(c_result[i] == c_naive[i] for i in range(N))
    print(f"\nNTT multiplication == Naive multiplication: {mul_ok}")
    
    # ========================================
    # Export to JSON for HTML
    # ========================================
    data = {
        "params": {"N": N, "Q": Q, "stages": 7},
        "zetas": ZETAS,
        "poly_a": poly_a,
        "poly_b": poly_b,
        "ntt_stages": ntt_stages,
        "ntt_a": a_ntt,
        "ntt_b": b_ntt,
        "c_ntt": c_ntt,
        "intt_stages": c_intt_stages,
        "result_c": c_result,
        "roundtrip_ok": roundtrip_ok,
        "mul_ok": mul_ok
    }
    
    with open("kyber_ntt_data.json", "w") as f:
        json.dump(data, f, indent=2)
        
    with open("kyber_ntt_data.js", "w") as f:
        f.write("const kyberData = " + json.dumps(data, indent=2) + ";\n")
    
    print("\n" + "=" * 80)
    print("Data exported to kyber_ntt_data.json")
    print("=" * 80)
