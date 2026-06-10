# Implements Lemma 4.6, Lemma 4.7, and Theorem 4.9 checks
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 4.1 and 4.2
#
# Pseudocode:
#   1. Apply the differential-uniformity filter from Lemma 4.6.
#   2. Enumerate rank-2 quadratic forms in Comp(F)^perp for small n.
#   3. Exhaustively verify Theorem 4.9 for a small APN base function.
# VBF API used: SBox, anf, rank_f2, gold_apn, differential_uniformity

include(joinpath(@__DIR__, "component_profiles.jl"))

"Lemma 4.6 filter for square SBox examples."
function lemma46_filter(F::SBox{N}; output_bits::Integer = N) where {N}
    m = Int(output_bits)
    threshold = 1 << (N - m + 1)
    du = differential_uniformity(F)
    (;
        n = N,
        output_bits = m,
        differential_uniformity = du,
        threshold,
        eliminated = du > threshold,
    )
end

function component_quadratic_basis(F::SBox{N}) where {N}
    [quadratic_component_vector(F, 1 << i) for i = 0:(N - 1)]
end

is_orthogonal_to_component_space(q::Integer, basis::AbstractVector{UInt64}) =
    all(iszero(count_ones(UInt64(q) & b) & 1) for b in basis)

"Find a rank-2 quadratic form in Comp(F)^perp, if the bounded enumeration sees one."
function rank2_orthogonal_witness(F::SBox{N}; max_forms::Integer = typemax(Int)) where {N}
    qdim = quadratic_dimension(N)
    total = (1 << qdim) - 1
    budget = min(Int(max_forms), total)
    basis = component_quadratic_basis(F)
    rank2_seen = 0
    for q = 1:budget
        quadratic_form_rank(q, N) == 2 || continue
        rank2_seen += 1
        is_orthogonal_to_component_space(q, basis) && return (;
            witness = q,
            rank2_seen,
            exhaustive = budget == total,
            budget,
            total_forms = total,
        )
    end
    (;
        witness = nothing,
        rank2_seen,
        exhaustive = budget == total,
        budget,
        total_forms = total,
    )
end

"Check Lemma 4.7 against VBF's differential-uniformity computation."
function lemma47_check(F::SBox{N}; max_forms::Integer = typemax(Int)) where {N}
    witness = rank2_orthogonal_witness(F; max_forms)
    du = differential_uniformity(F)
    no_rank2 = witness.witness === nothing
    conclusion = witness.exhaustive ? no_rank2 : nothing
    (;
        n = N,
        differential_uniformity = du,
        apn_by_du = du == 2,
        no_rank2_orthogonal = conclusion,
        witness = witness.witness,
        rank2_seen = witness.rank2_seen,
        exhaustive = witness.exhaustive,
        budget = witness.budget,
        total_forms = witness.total_forms,
        agrees = witness.exhaustive ? ((du == 2) == no_rank2) : nothing,
    )
end

"Construct G(x,x_n)=F(x)+x_n L(x) from Theorem 4.9."
function input_extension_lut(F::AbstractVector{<:Integer}, L::AbstractVector{<:Integer}, nbits::Integer)
    n = Int(nbits)
    size = 1 << n
    length(F) == size || throw(ArgumentError("F must have length 2^$n"))
    length(L) == size || throw(ArgumentError("L must have length 2^$n"))
    G = zeros(Int, 1 << (n + 1))
    @inbounds for x = 0:(size - 1)
        G[x + 1] = Int(F[x + 1])
        G[(x | (1 << n)) + 1] = Int(F[x + 1]) ⊻ Int(L[x + 1])
    end
    G
end

"Theorem 4.9 condition for a candidate linear map L."
function theorem49_condition(
    F::AbstractVector{<:Integer},
    L::AbstractVector{<:Integer},
    nbits::Integer,
)
    n = Int(nbits)
    size = 1 << n
    length(F) == size || throw(ArgumentError("F must have length 2^$n"))
    length(L) == size || throw(ArgumentError("L must have length 2^$n"))
    @inbounds for alpha = 1:(size - 1)
        forbidden = Set{Int}()
        for x = 0:(size - 1)
            push!(
                forbidden,
                Int(F[(x ⊻ alpha) + 1]) ⊻ Int(F[x + 1]) ⊻ Int(F[alpha + 1]) ⊻ Int(F[1]),
            )
        end
        Int(L[alpha + 1]) in forbidden && return false
    end
    true
end

"Small base functions used for Theorem 4.9 checks."
function theorem49_base_lut(n::Integer, m::Integer)
    if n == 2 && m == 3
        return [1, 0, 0, 0]
    end
    n == m || throw(ArgumentError("default base LUT is only provided for (2,3) or square Gold examples"))
    Int.(gold_apn(n, 1).lut)
end

"Exhaustively verify Theorem 4.9 for all linear L in a small dimension."
function theorem49_exhaustive_check(; nbits::Integer = 2, output_bits::Integer = 3)
    n = Int(nbits)
    m = Int(output_bits)
    F = theorem49_base_lut(n, m)
    base_du = generic_differential_uniformity(F, n, m)
    total = 0
    condition_true = 0
    extension_apn = 0
    disagreements = 0
    for L in all_linear_luts(n, m)
        total += 1
        cond = theorem49_condition(F, L, n)
        G = input_extension_lut(F, L, n)
        du = generic_differential_uniformity(G, n + 1, m)
        ext = du == 2
        cond && (condition_true += 1)
        ext && (extension_apn += 1)
        cond == ext || (disagreements += 1)
    end
    (;
        nbits = n,
        output_bits = m,
        base_du,
        total_linear_maps = total,
        condition_true,
        extension_apn,
        disagreements,
        agrees = disagreements == 0,
    )
end

"Report bounded construction-criterion checks."
function extension_criteria_report(io::IO = stdout)
    print_section("Extension Criteria", io)

    gold4 = gold_apn(4, 1)
    zero4 = SBox{4}(zeros(Int, 16))
    lemma46_gold = lemma46_filter(gold4)
    lemma46_zero = lemma46_filter(zero4)
    lemma47_gold = lemma47_check(gold4)
    lemma47_zero = lemma47_check(zero4)
    theorem49 = theorem49_exhaustive_check()

    print_check("Lemma 4.6 keeps the APN Gold example", !lemma46_gold.eliminated, io)
    print_check("Lemma 4.6 eliminates the zero function", lemma46_zero.eliminated, io)
    print_check("Lemma 4.7 agrees with differential uniformity for Gold n=4", lemma47_gold.agrees === true, io)
    print_check("Lemma 4.7 agrees with differential uniformity for zero n=4", lemma47_zero.agrees === true, io)
    print_check("Theorem 4.9 condition matches extension DU=2 for all small linear maps", theorem49.agrees, io)
    print_kv("Lemma 4.7 Gold rank-2 forms seen", lemma47_gold.rank2_seen, io)
    print_kv("Theorem 4.9 linear maps checked", theorem49.total_linear_maps, io)
    print_kv("Theorem 4.9 satisfying maps", theorem49.condition_true, io)
    print_kv("completeness", "exact for n=4 Lemma 4.7 and n=2 Theorem 4.9; paper n=8 search is not run", io)

    (; lemma46_gold, lemma46_zero, lemma47_gold, lemma47_zero, theorem49)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    extension_criteria_report()
end
