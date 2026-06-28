# Implements Section IV — The Self-Equivalence Subspace V_A
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: IV — Construction of V_A via F∘A = A∘F
#
# Pseudocode:
#   1. Build A = block_diag(C(q), C(q)) ∈ GL(8, F₂),  q = X⁴+X³+X²+X+1
#   2. Verify A^5 = I and A^k ≠ I for k = 1,2,3,4
#   3. Build M_A (224×224 BitMatrix) from F∘A = A∘F constraint
#   4. Compute RREF of M_A; verify rank = 184, dim(V_A) = 40
#   5. Extract fc22+sol22 parameterization
#   6. Spot-check: verify a random V_A element satisfies F∘A = A∘F
# VBF API used: print_section, print_check, print_kv

include("helpers.jl")

# ─── V_A construction ────────────────────────────────────────────────────────

function section4_run(; seed::Int = 42)
    A       = build_A_matrix()
    A_lut   = build_A_lut(A)
    param   = fc22_sol22(A)

    n_pivot = length(param.pivot_cols)
    n_free  = length(param.free_cols)

    # Spot-check: map b=0 → should give c=0 (zero function; trivially in V_A)
    b_zero = falses(n_free)
    c_zero = apply_fc22_sol22(b_zero, param.pivot_cols, param.free_cols, param.S)
    lut_zero = quadratic_lut(c_zero)
    va_zero = in_va(lut_zero, A_lut, A)

    # Spot-check: random nonzero b
    rng = Random.MersenneTwister(seed)
    b_rand = rand(rng, Bool, n_free)
    c_rand = apply_fc22_sol22(b_rand, param.pivot_cols, param.free_cols, param.S)
    lut_rand = quadratic_lut(c_rand)
    va_rand = in_va(lut_rand, A_lut, A)

    # Verify A^5 = I
    I8 = Matrix{Bool}(LinearAlgebra.I, 8, 8)
    A2 = matmul_f2(A, A)
    A3 = matmul_f2(A2, A)
    A4 = matmul_f2(A3, A)
    A5 = matmul_f2(A4, A)

    (; A, A_lut, param, n_pivot, n_free,
       va_zero, va_rand, b_rand,
       A5_is_I = (A5 == I8),
       A1_not_I = (A != I8),
       A2_not_I = (A2 != I8),
       A3_not_I = (A3 != I8),
       A4_not_I = (A4 != I8))
end

function section4_report(io::IO = stdout; kwargs...)
    r = section4_run(; kwargs...)
    print_section("Section IV — The Self-Equivalence Subspace V_A", io)

    print_kv("automorphism A", "block_diag(C(q), C(q)), q = X⁴+X³+X²+X+1", io)
    print_check("A⁵ = I₈", r.A5_is_I, io)
    print_check("A¹ ≠ I₈", r.A1_not_I, io)
    print_check("A² ≠ I₈", r.A2_not_I, io)
    print_check("A³ ≠ I₈", r.A3_not_I, io)
    print_check("A⁴ ≠ I₈", r.A4_not_I, io)

    print_kv("dim V_A (free variables)", r.n_free, io)
    print_kv("rank M_A (pivot variables)", r.n_pivot, io)
    print_check("dim(V_A) = 40", r.n_free == 40, io)
    print_check("rank(M_A) = 184", r.n_pivot == 184, io)

    print_check("b=0 maps to zero function (in V_A)", r.va_zero, io)
    print_check("random nonzero b maps to V_A member", r.va_rand, io)
end

import Random
import LinearAlgebra

if abspath(PROGRAM_FILE) == @__FILE__
    section4_report()
end
