# Implements Theorem 1 — diagonal squaring property of QAM with F₂ coefficients
# Paper: Yu, Li, Ichanska, Kaleyski (2025), "Classification of quadratic APN functions
#        with coefficients in F₂ in dimension 10", Appl. Algebra Eng. Commun. Comput.
# Section: 2 Preliminaries, Theorem 1
#
# Pseudocode:
#   1. Build H = normal_basis_deriv_matrix(F, b) for F with F₂ coefficients.
#   2. Verify H[u+1,v+1] = H[u,v]² (Julia 1-based: H[i+1,j+1] = H[i,j]² mod n)
#      for all i,j ∈ {1,…,n} with indices taken mod n.
# VBF API used: gold_apn, conway_polynomial, gf_pow

include(joinpath(@__DIR__, "helpers.jl"))

# Verify that the normal-basis derivative matrix H satisfies H[i+1 mod n, j+1 mod n] = H[i,j]²
# for all i,j. Returns (passes::Bool, first_failure).
function verify_diagonal_squaring(H::Matrix{Int}, n::Int;
                                  modulus::Int = conway_polynomial(n))
    for i in 1:n, j in 1:n
        r_next = mod1(i + 1, n)
        c_next = mod1(j + 1, n)
        expected = gf_pow(H[i, j], 2, n; modulus = modulus)
        if H[r_next, c_next] != expected
            return false, (i, j, H[i,j], H[r_next,c_next], expected)
        end
    end
    true, nothing
end

function theorem1_report(io::IO = stdout)
    print_section(io, "Theorem 1: diagonal squaring property H[i+1,j+1] = H[i,j]²")

    for (n, k) in [(5, 1), (5, 3), (6, 1), (6, 5)]
        mod = conway_polynomial(n)
        F   = gold_apn(n, k; modulus = mod)
        b   = find_normal_element(n; modulus = mod)
        H   = normal_basis_deriv_matrix(F, b; modulus = mod)
        ok, fail = verify_diagonal_squaring(H, n; modulus = mod)
        print_check(io, "Gold x^{2^$k+1} over GF(2^$n): squaring property", ok)
        ok || print_kv(io, "  first failure", fail)
    end

    print_kv(io, "completeness", "exhaustive (all i,j pairs for each function)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_report()
end
