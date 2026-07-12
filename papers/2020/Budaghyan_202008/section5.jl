# Implements Section V — Isotopic Shifts of Quadratic APN Functions.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: V (Theorem V.1, Proposition V.3)
#
# Pseudocode:
#   Proposition V.3 (count of F_2-linear 2-to-1 maps over GF(2^n)):
#     1. formula(n) = (2^n − 1) × ∏_{i=0}^{n-2} (2^n − 2^i)
#     2. brute_force(n): iterate all linear maps (determined by images of basis),
#        count those with kernel = {0, z} for some nonzero z.
#   Theorem V.1 (restriction on L when G_{i,L} is APN):
#     3. For each APN isotopic shift found, check L is permutation or 2-to-1.
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))
using Dates

"""
    proposition_v3_formula(n) -> Int

Closed-form count of F₂-linear 2-to-1 maps on GF(2^n) (Proposition V.3):
(2^n − 1) × ∏_{i=0}^{n-2} (2^n − 2^i).
"""
function proposition_v3_formula(n::Int)
    N = 1 << n
    result = N - 1
    for i in 0:n-2
        result *= (N - (1 << i))
    end
    result
end

"""
    proposition_v3_brute(n) -> Int

Count F₂-linear 2-to-1 maps on GF(2^n) by exhaustive enumeration.
A linear map is encoded by (L(1), L(2), L(4), ..., L(2^{n-1})).
Only feasible for small n (n ≤ 4).
"""
function proposition_v3_brute(n::Int)
    N = 1 << n
    basis_images = zeros(Int, n)
    count = 0
    for encoding in 0:(N^n - 1)
        # Decode images of basis elements
        tmp = encoding
        for k in 0:n-1
            basis_images[k+1] = tmp & (N - 1)
            tmp >>= n
        end
        # Compute kernel size: |{x : L(x) = 0}|
        ksz = 0
        for x in 0:N-1
            lx = 0
            for k in 0:n-1
                (x >> k) & 1 == 1 && (lx ⊻= basis_images[k+1])
            end
            lx == 0 && (ksz += 1)
        end
        ksz == 2 && (count += 1)
    end
    count
end

"""
    section5_check_theoremV1(; n, i, io) -> NamedTuple

Verify Theorem V.1: for each APN isotopic shift G_{i,L} found by scanning
all 1-term linear maps L(x) = u·x^{2^j}, check that L is permutation or 2-to-1.
Tested on G_i = x^{2^i+1} over GF(2^n).
"""
function section5_check_theoremV1(; n::Int = 6, i::Int = 1, io::IO = devnull)
    mod = primitive_polynomial(n)
    G = gold_lut(n, i; modulus = mod)

    violations = 0
    apn_count  = 0
    for j in 0:n-1
        gcd(j, n) == 0 && continue  # skip trivial
        for log_u in 1:(1<<n)-2
            u = gf_pow(2, log_u, n; modulus = mod)
            L  = linear_monomial_lut(n, j, u; modulus = mod)
            GL = SBox{n}(isotopic_shift_lut(G, L))
            differential_uniformity(GL) == 2 || continue
            apn_count += 1
            if kernel_size(L) != 1 && !is_2to1(L)
                violations += 1
            end
        end
    end

    ok = violations == 0
    print_section(io, "Section V — Theorem V.1 (G_$i over GF(2^$n), 1-term L)")
    print_kv(io, "APN isotopic shifts found", apn_count)
    print_check(io, "all producing L permutation or 2-to-1", ok)
    (; apn_count, violations)
end

"""
    section5_check_propositionV3(; io) -> NamedTuple

Verify Proposition V.3 formula against brute-force count for n=3 and n=4.
"""
function section5_check_propositionV3(; io::IO = devnull)
    print_section(io, "Section V — Proposition V.3 (count of 2-to-1 linear maps)")

    results = NamedTuple[]
    for n in (3, 4)
        formula = proposition_v3_formula(n)
        brute   = proposition_v3_brute(n)
        ok = formula == brute
        print_check(io, "n=$n: formula=$formula == brute=$brute", ok)
        push!(results, (; n, formula, brute, ok))
    end
    results
end

function section5_report(io::IO = stdout)
    print_section(io, "Section V: Isotopic Shifts of Quadratic APN Functions")
    section5_check_propositionV3(; io)
    section5_check_theoremV1(; io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    section5_report()
end
