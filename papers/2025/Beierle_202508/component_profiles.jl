# Implements quadratic component rank and Walsh-moment checks
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 2 and 4.1
#
# Pseudocode:
#   1. Extract the quadratic coefficient vector of each Boolean component.
#   2. Compute the alternating-matrix rank and alpha(f)=2^(n-rank(f)).
#   3. Check Theorem 2.3 on small known quadratic APN examples.
# VBF API used: SBox, anf, rank_f2, gold_apn, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"Number of quadratic monomials in n variables."
quadratic_dimension(n::Integer) = (Int(n) * (Int(n) - 1)) ÷ 2

function _pair_position(i::Integer, j::Integer, n::Integer)
    ii = Int(i)
    jj = Int(j)
    nn = Int(n)
    ii < jj || throw(ArgumentError("need i < j"))
    pos = 0
    for a = 0:(nn - 2), b = (a + 1):(nn - 1)
        a == ii && b == jj && return pos
        pos += 1
    end
    throw(ArgumentError("pair outside dimension"))
end

"Bit-packed quadratic coefficient vector of component b.F."
function quadratic_component_vector(F::SBox{N}, output_mask::Integer) where {N}
    N <= 10 || throw(ArgumentError("quadratic_component_vector: packed helper is intended for small n"))
    coeffs = anf(F)
    bits = UInt64(0)
    pos = 0
    @inbounds for i = 0:(N - 2), j = (i + 1):(N - 1)
        monomial = (1 << i) | (1 << j)
        c = Int(coeffs[monomial + 1])
        if isodd(count_ones(c & Int(output_mask)))
            bits |= UInt64(1) << pos
        end
        pos += 1
    end
    bits
end

"Rank over F2 of the alternating matrix associated with a quadratic form."
function quadratic_form_rank(q::Integer, n::Integer)
    nn = Int(n)
    rows = zeros(UInt64, nn)
    bits = UInt64(q)
    pos = 0
    for i = 0:(nn - 2), j = (i + 1):(nn - 1)
        if ((bits >> pos) & 0x01) == 0x01
            rows[i + 1] |= UInt64(1) << j
            rows[j + 1] |= UInt64(1) << i
        end
        pos += 1
    end
    rank_f2(rows; nbits = nn)
end

"The quadratic rank of a Boolean component b.F."
component_quadratic_rank(F::SBox{N}, output_mask::Integer) where {N} =
    quadratic_form_rank(quadratic_component_vector(F, output_mask), N)

"Profile pair BS(V)=(number of bent forms, sum alpha) for a component-mask set."
function component_bs(F::SBox{N}, masks) where {N}
    bent = 0
    alpha_sum = 0
    ranks = Int[]
    for b in masks
        bi = Int(b)
        bi == 0 && continue
        r = component_quadratic_rank(F, bi)
        push!(ranks, r)
        r == N && (bent += 1)
        alpha_sum += 1 << (N - r)
    end
    (; bent_count = bent, alpha_sum, ranks)
end

"Check the component-moment APN criterion on a known Gold APN."
function apn_component_moment_check(n::Integer = 4)
    nn = Int(n)
    F = gold_apn(nn, 1)
    masks = 1:((1 << nn) - 1)
    bs = component_bs(F, masks)
    expected = (1 << (nn + 1)) - 2
    (;
        n = nn,
        differential_uniformity = differential_uniformity(F),
        algebraic_degree = algebraic_degree(F),
        alpha_sum = bs.alpha_sum,
        expected,
        matches = bs.alpha_sum == expected,
        bent_components = bs.bent_count,
        component_count = length(masks),
    )
end

"Report small exact component-profile and Walsh-moment checks."
function component_profiles_report(io::IO = stdout; n::Integer = 4)
    print_section("Component Profiles And Moments", io)
    r = apn_component_moment_check(n)
    print_check("Gold x^3 has differential uniformity 2", r.differential_uniformity == 2, io)
    print_check("Gold x^3 is quadratic", r.algebraic_degree == 2, io)
    print_check("component alpha sum matches Theorem 2.3", r.matches, io)
    print_kv("n", r.n, io)
    print_kv("non-zero components", r.component_count, io)
    print_kv("bent components among all components", r.bent_components, io)
    print_kv("alpha sum", r.alpha_sum, io)
    print_kv("expected alpha sum", r.expected, io)
    print_kv("completeness", "exact for n=$(r.n) Gold example; paper-scale profile table checked by counts", io)
    r
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    component_profiles_report()
end
