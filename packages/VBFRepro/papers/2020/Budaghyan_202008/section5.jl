# Implements Section V — Isotopic Shifts of Quadratic APN Functions.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: V (Theorem V.1, Proposition V.3)
#
# Pseudocode:
#   Proposition V.3 (count of F_q-linear q-to-1 maps over GF(q^n); here q = 2):
#     1. formula(n) = (2^n − 1) × ∏_{i=0}^{n-2} (2^n − 2^i)
#     2. brute_force(n): iterate all linear maps (determined by images of basis),
#        count those with kernel = {0, z} for some nonzero z.
#   Theorem V.1 (restriction on L when G_{i,L} is APN), with M(x) = L(x) + x:
#     (i)  L is a permutation or 2-to-1, and L is injective on 𝒱(L) = im(L)
#     (ii) M is a permutation or 2-to-1, and M is injective on 𝒱(M)
#     3. Scan *all* 1-term and 2-term linear L; classify every L (permutation /
#        2-to-1 / neither) and check (i)+(ii) on every L whose shift is APN, plus
#        the contrapositive on every L that is neither (its shift must not be APN).
# VBF API used: gold_apn, terms_to_lut, kernel_f2 (via kernel_dimension/is_2to1),
#               is_permutation, SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))
using Dates

"""
    proposition_v3_formula(n) -> Int

Closed-form count of F₂-linear 2-to-1 maps on GF(2^n) (Proposition V.3 at q = 2):
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
    section5_linear_maps(n; modulus) -> Vector{Vector{Int}}

Every 1-term L(x) = u·x^{2^j} and every 2-term L(x) = u·x^{2^j₁} + v·x^{2^j₂}
over GF(2^n) with u, v ≠ 0.  This scan space is what makes the Theorem V.1 check
discriminating: it contains permutations, 2-to-1 maps *and* maps with a larger
kernel (e.g. L(x) = x⁴ + x has kernel F₄ ⊂ GF(2⁶)), so each branch of the
theorem's disjunction is actually exercised.
"""
function section5_linear_maps(n::Int; modulus::Int = primitive_polynomial(n))
    N = 1 << n
    Ls = Vector{Vector{Int}}()
    for j in 0:n-1, u in 1:N-1
        push!(Ls, terms_to_lut([(u, 1 << j)], n, modulus))
    end
    for j1 in 0:n-1, j2 in (j1+1):n-1, u in 1:N-1, v in 1:N-1
        push!(Ls, terms_to_lut([(u, 1 << j1), (v, 1 << j2)], n, modulus))
    end
    Ls
end

"""
    section5_check_theoremV1(; n, i, io) -> NamedTuple

Verify Theorem V.1 for G_i = x^{2^i+1} over GF(2^n), scanning all 1-term and
2-term linear L (see [`section5_linear_maps`](@ref)):

  (i)  every APN shift G_{i,L} has L a permutation or 2-to-1, L injective on im(L);
  (ii) the same for M(x) = L(x) + x;
  plus the contrapositive — no L outside that shape (dim ker L ≥ 2) yields an APN
  shift.

`is_2to1` is evaluated on *every* scanned L, not only inside a short-circuited
guard, and the returned counts pin how often each branch fires.
"""
function section5_check_theoremV1(; n::Int = 6, i::Int = 1, io::IO = devnull)
    mod = primitive_polynomial(n)
    G = gold_apn(n, i; modulus = mod).lut
    N = 1 << n

    scanned = 0
    n_perm = 0            # L a permutation
    n_2to1 = 0            # L 2-to-1
    n_neither = 0         # dim ker L ≥ 2 — forbidden by Thm V.1(i) for APN shifts
    apn_count = 0
    apn_perm_L = 0
    apn_2to1_L = 0
    apn_perm_M = 0
    apn_2to1_M = 0
    violations_i = 0      # APN shift whose L breaks V.1(i)
    violations_ii = 0     # APN shift whose M breaks V.1(ii)
    neither_but_apn = 0   # L with dim ker ≥ 2 whose shift is nonetheless APN

    for L in section5_linear_maps(n; modulus = mod)
        scanned += 1
        M = [L[x+1] ⊻ x for x in 0:N-1]

        # Classify L and M unconditionally — no short-circuit can skip is_2to1.
        perm_L, two_L = is_permutation_map(L), is_2to1(L)
        perm_M, two_M = is_permutation_map(M), is_2to1(M)
        perm_L && (n_perm += 1)
        two_L && (n_2to1 += 1)
        (perm_L || two_L) || (n_neither += 1)

        GL = SBox{n}(isotopic_shift_lut(G, L))
        if differential_uniformity(GL) != 2
            continue
        end
        apn_count += 1
        perm_L && (apn_perm_L += 1)
        two_L && (apn_2to1_L += 1)
        perm_M && (apn_perm_M += 1)
        two_M && (apn_2to1_M += 1)

        ((perm_L || two_L) && injective_on_image(L)) || (violations_i += 1)
        ((perm_M || two_M) && injective_on_image(M)) || (violations_ii += 1)
        (perm_L || two_L) || (neither_but_apn += 1)
    end

    ok_i  = violations_i == 0
    ok_ii = violations_ii == 0
    ok_contra = neither_but_apn == 0
    # Non-vacuity guards: the scan must contain APN shifts *and* maps of each
    # shape, otherwise the checks above are satisfied for free.
    nonvacuous = apn_count > 0 && n_2to1 > 0 && n_neither > 0

    print_section(io, "Section V — Theorem V.1 (G_$i over GF(2^$n), 1-term + 2-term L)")
    print_kv(io, "linear maps scanned", scanned)
    print_kv(io, "  of which permutations", n_perm)
    print_kv(io, "  of which 2-to-1", n_2to1)
    print_kv(io, "  of which neither (dim ker ≥ 2)", n_neither)
    print_kv(io, "APN isotopic shifts found", apn_count)
    print_kv(io, "  with L a permutation", apn_perm_L)
    print_kv(io, "  with L 2-to-1", apn_2to1_L)
    print_kv(io, "  with M=L+x a permutation", apn_perm_M)
    print_kv(io, "  with M=L+x 2-to-1", apn_2to1_M)
    print_check(io, "V.1(i):  L permutation or 2-to-1, injective on im(L)", ok_i)
    print_check(io, "V.1(ii): M=L+x permutation or 2-to-1, injective on im(M)", ok_ii)
    print_check(io, "contrapositive: no L with dim ker ≥ 2 gives an APN shift", ok_contra)
    print_check(io, "scan is non-vacuous (APN shifts, 2-to-1 maps and dim-ker≥2 maps all present)",
        nonvacuous)
    # Honest scope note: Theorem V.1 *permits* a 2-to-1 L, but no such positive
    # case exists in this space — 0 of the APN shifts at n=6 (1-term or 2-term L)
    # have L 2-to-1.  A positive case needs a general linear L (paper, Sec. VII-D).
    print_kv(io, "note",
        "APN shifts with 2-to-1 L: $apn_2to1_L (none exist among 1-/2-term L at " *
        "n=$n; the 2-to-1 branch of V.1(i) is exercised only negatively here)")

    (; scanned, apn_count, n_perm, n_2to1, n_neither,
       apn_perm_L, apn_2to1_L, apn_perm_M, apn_2to1_M,
       violations_i, violations_ii, neither_but_apn,
       ok_i, ok_ii, ok_contra, nonvacuous)
end

"""
    section5_check_propositionV3(; io) -> NamedTuple

Verify the Proposition V.3 count against brute force for n=3 and n=4.
Scope: q = 2 only (the paper states the count for an arbitrary prime power q).
"""
function section5_check_propositionV3(; io::IO = devnull)
    print_section(io, "Section V — Proposition V.3 (count of 2-to-1 linear maps, q=2 only)")

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
