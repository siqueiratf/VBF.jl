# Implements Section 5, Remark 4 — computer check: no linear L on GF(2^5)
# makes F' + L a permutation, confirming F' is EA-inequivalent to any permutation.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5, Remark 4
#
# Pseudocode:
#   m=5, i=1: F'(x) = x^3 + (x^2+x)·tr(x^3+x)
#   Linear map L on GF(2^5) determined by (L(1),L(2),L(4),L(8),L(16)) ∈ GF(2^5)^5.
#   Total: 32^5 = 2^{25} ≈ 33M maps.  Default: random sample.
#   Expected: no F'+L is a permutation.
# VBF API used: primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))

function _apply_linear(basis::NTuple{N,Int}, x::Int) where {N}
    acc = 0
    xi = x
    for k in 1:N
        (xi & 1) == 1 && (acc ⊻= basis[k])
        xi >>= 1
    end
    acc
end

"""
    remark4_check(; sample_size, full_search, seed, io) -> NamedTuple

Verify Remark 4: no linear L on GF(2^5) makes F' + L a permutation (m=5, i=1).

`full_search=false` (default): test `sample_size` random linear maps.
`full_search=true`: exhaustive search over all 2^{25} linear maps (a few minutes).
"""
function remark4_check(;
    sample_size::Int = 200,
    full_search::Bool = false,
    seed::Int = 42,
    io::IO = devnull,
)
    m = 5
    N = 1 << m
    F_lut = theorem1_lut(m, 1)
    # `combined` is the live buffer; `sbox` aliases it (the SBox{N,T} constructor
    # stores the vector by reference), so we mutate in place and call core
    # `is_permutation` without reallocating an SBox each iteration.
    combined = zeros(UInt8, N)
    sbox = SBox{5,UInt8}(combined)
    tested = 0
    violations = 0

    if full_search
        for v0 in 0:N-1, v1 in 0:N-1, v2 in 0:N-1, v3 in 0:N-1, v4 in 0:N-1
            basis = (v0, v1, v2, v3, v4)
            for x in 0:N-1
                combined[x+1] = UInt8(F_lut[x+1] ⊻ _apply_linear(basis, x))
            end
            is_permutation(sbox) && (violations += 1)
            tested += 1
        end
    else
        s = seed
        rng() = (s = s * 6364136223846793005 + 1442695040888963407; (s >>> 33) % N)
        for _ in 1:sample_size
            basis = ntuple(_ -> rng(), 5)
            for x in 0:N-1
                combined[x+1] = UInt8(F_lut[x+1] ⊻ _apply_linear(basis, x))
            end
            is_permutation(sbox) && (violations += 1)
            tested += 1
        end
    end

    ok = violations == 0
    print_section("Remark 4 — F'+L not a permutation (m=5, i=1)", io)
    print_kv("search", full_search ? "exhaustive (all 2^25 maps)" : "sampled ($tested maps, seed=$seed)", io)
    print_check("no F'+L is a permutation (violations=$violations / $tested)", ok, io)
    print_kv("completeness", full_search ? "exhaustive" : "budget-limited ($tested / $(N^m))", io)
    (; violations, tested, exhaustive = full_search)
end

function remark4_report(io::IO = stdout)
    print_section("Section 5 — Remark 4: EA-inequivalence to permutations", io)
    remark4_check(; sample_size = 500, io = io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    remark4_report()
end
