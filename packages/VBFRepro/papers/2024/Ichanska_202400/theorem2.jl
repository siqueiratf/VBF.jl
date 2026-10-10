# Implements Section 3.4 — Theorem 2 (Submatrix test / Cyclic shift invariance)
# Paper: Ichanska, Berg, Kaleyski, Yu (2024/2025), "Pushing the QAM method for finding APN functions further"
# Section: 3.4 — Submatrix test, Theorem 2
#
# Pseudocode:
#   1. Fix normal basis B = {b, b², ..., b^{2^{n-1}}} for F₂ⁿ over F₂
#   2. Compute M_F (derivative matrix of F in basis B)
#   3. For s ∈ {1,...,n-1} and α ∈ F₂ᵐ, define F'(x) = F(α x^{2^s})
#   4. Compute M_{F'} directly
#   5. Verify M_{F'} = cyclic_shift(M_F, s)  [Theorem 2]
# VBF API used: gf_pow, gf_mul, conway_polynomial, SBox, quadratic_apn_matrix

include(joinpath(@__DIR__, "helpers.jl"))

"""
    verify_theorem2(; n=4, modulus=conway_polynomial(4)) -> Bool

Theorem 2 (Ichanska et al. 2024): Let F be a quadratic function over F₂ⁿ with derivative
matrix M_F in the normal basis {b^{2^i}}. The derivative matrix of F' = F ∘ αx^{2^s}
is the cyclic index-shift of M_F by s: M_{F'}[i,j] = M_F[(i+s-1 mod n)+1, (j+s-1 mod n)+1].

Verified for n=4, F = Gold x^3, shifts s=1,2,3.
"""
function verify_theorem2(; n::Int = 4, modulus::Int = conway_polynomial(n))
    b = find_normal_element(n; modulus = modulus)
    F = SBox{n}([gf_pow(x, 3, n; modulus = modulus) for x in 0:(1<<n)-1])
    MF = normal_basis_deriv_matrix(F, b; modulus = modulus)

    all_pass = true
    for s in 1:n-1
        # F'(x) = F(x^{2^s}) = (x^{2^s})^3 = x^{3·2^s}
        exp_prime = 3 * (1 << s)
        Fprime = SBox{n}([gf_pow(x, exp_prime, n; modulus = modulus) for x in 0:(1<<n)-1])
        MFprime = normal_basis_deriv_matrix(Fprime, b; modulus = modulus)
        shifted = cyclic_shift_matrix(MF, s)
        if MFprime != shifted
            all_pass = false
        end
    end
    all_pass
end

function theorem2_report(io::IO = stdout)
    print_section(io, "Theorem 2: Cyclic shift invariance of derivative matrix (Section 3.4)")
    n = 4; mod = conway_polynomial(n)
    b = find_normal_element(n; modulus = mod)
    print_kv(io, "n", n)
    print_kv(io, "modulus (Conway)", mod)
    print_kv(io, "normal element b", b)

    F = SBox{n}([gf_pow(x, 3, n; modulus = mod) for x in 0:(1<<n)-1])
    MF = normal_basis_deriv_matrix(F, b; modulus = mod)
    print_kv(io, "F", "Gold x^3 over F₂⁴")

    for s in 1:n-1
        exp_prime = 3 * (1 << s)
        Fprime = SBox{n}([gf_pow(x, exp_prime, n; modulus = mod) for x in 0:(1<<n)-1])
        MFprime = normal_basis_deriv_matrix(Fprime, b; modulus = mod)
        shifted = cyclic_shift_matrix(MF, s)
        pass = MFprime == shifted
        print_check(io, "M_{F'=x^$(exp_prime)} = cyclic_shift(M_F, $s)", pass)
    end
    print_kv(io, "completeness", "exact (n=4, Gold x^3, shifts s=1,2,3)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem2_report()
end
