# Theorem 6 — a new model handling the last two columns of H_8 together.
#
# ── Paper mapping ───────────────────────────────────────────────────────────
# Source: Yu and Perrin (2022), Section "A new model": Definition (proper),
# Theorem 4 (Yu–Wang–Li 2014), Lemma 5, and Theorem 6.
#
# Definition (proper). H ∈ F_{2^n}^{m×k} is proper if every nonzero F_2-linear
#   combination of its m rows has rank ≥ k−1.
# Lemma 5. Every submatrix of a QAM is proper.
# Theorem 6. Let the leading (n−2)×(n−2) block of a symmetric, zero-diagonal
#   H_n come from a QAM (hence be proper). Then H_n is a QAM iff
#
#     Σ_{i=1}^{n-1} λ_i (μ_1 H_n[i,n-1] + μ_2 H_n[i,n])
#         ∈ F_{2^n} ∖ Span( Σ_{i=1}^{n-1} λ_i H_n[i, 1→n-2] )                (★)
#
#   for all (λ_1,…,λ_{n-1}) ∈ F_2^{n-1}∖{0} and (μ_1,μ_2) ∈ F_2^2∖{0}, except
#   the degenerate family that collapses by Theorem 4(i) (see below).
#
# ── A note on the excluded set ──────────────────────────────────────────────
# The converted-TeX excludes the single vector with λ_{n-1}=1 (others 0),
# μ=(1,0): there (★) reads H_n[n-1,n-1] ∉ Span(...), impossible since the
# diagonal entry is 0. But by Theorem 4(i), *every* combination with μ=(1,0)
# that closes the symmetric (n−1)×(n−1) block (i.e. λ_{n-1}=1) has rank exactly
# (n−1)−1, so its z always lies in the span. Hence the whole family
#   { μ=(1,0) and λ_{n-1}=1 }
# must be excluded, not just one vector. With that reading and Theorem 6's
# hypothesis (leading block proper), (★) is *exactly* `is_qam` — verified here
# for n = 5, 6, 8 (`new_model_matches_is_qam`).
#
# The model's payoff (paper's eq. (5) vs (6)): the span constraints are computed
# from the *fixed* first n−2 columns, so the work for x_13 and x_7 is shared
# rather than recomputed per candidate — see `redundancy_comparison`. The paper
# notes the model "has not been realized"; here it is an executable predicate.

isdefined(@__MODULE__, :h8_base) || include(joinpath(@__DIR__, "conjecture2_search.jl"))
using VBF, Random

"""
    is_proper(H, m) -> Bool

Whether the leading `m×m` submatrix of `H` is *proper* (Definition in Section
"A new model"): every nonzero F_2-combination of its `m` rows has rank ≥ m−1.
"""
function is_proper(H::AbstractMatrix{<:Integer}, m::Int)
    n = size(H, 1)
    vec = Vector{UInt}(undef, m)
    @inbounds for mask = 1:((1 << m) - 1)
        for i = 1:m
            acc = 0
            s = mask
            while s != 0
                j = trailing_zeros(s) + 1
                acc ⊻= Int(H[i, j])
                s &= s - 1
            end
            vec[i] = UInt(acc)
        end
        rank_f2(vec; nbits = n) < m - 1 && return false
    end
    true
end

"""
    new_model_is_qam(H) -> Bool

Theorem 6's condition (★): the QAM test that handles the last two columns
together. Equivalent to [`is_qam`](@ref) when the leading `(n−2)×(n−2)` block is
proper (Theorem 6's hypothesis, always true for `H_8`). For an `n×n` `H` it
iterates `2^{n-1}·3` combinations, each a span of `n−2` field elements — far
fewer than the `2^n − 1` row subsets of the direct test.
"""
function new_model_is_qam(H::AbstractMatrix{<:Integer})
    n = size(H, 1)
    last_lambda = 1 << (n - 2)              # bit selecting λ_{n-1}
    w = Vector{UInt}(undef, n - 2)
    @inbounds for lam = 1:((1 << (n - 1)) - 1)        # λ ∈ F_2^{n-1} ∖ {0}
        for j = 1:(n - 2)
            acc = 0
            s = lam
            while s != 0
                i = trailing_zeros(s) + 1
                acc ⊻= Int(H[i, j])
                s &= s - 1
            end
            w[j] = UInt(acc)
        end
        rank_w = rank_f2(w; nbits = n)
        for mu = 1:3                                  # (μ1,μ2): 1=(1,0),2=(0,1),3=(1,1)
            mu1 = mu & 1
            mu2 = (mu >> 1) & 1
            # excluded family: μ=(1,0) closing the symmetric (n-1)-block
            (mu1 == 1 && mu2 == 0 && (lam & last_lambda) != 0) && continue
            z = 0
            s = lam
            while s != 0
                i = trailing_zeros(s) + 1
                mu1 == 1 && (z ⊻= Int(H[i, n - 1]))
                mu2 == 1 && (z ⊻= Int(H[i, n]))
                s &= s - 1
            end
            # z ∈ Span(w)  ⟺  adding z does not raise the rank  ⟹  (★) violated
            rank_f2(vcat(w, UInt(z)); nbits = n) == rank_w && return false
        end
    end
    true
end

"""
    new_model_matches_is_qam(; n, samples, seed) -> NamedTuple

Check `new_model_is_qam == is_qam` on random symmetric zero-diagonal matrices
whose leading `(n−2)×(n−2)` block is proper (Theorem 6's hypothesis). Returns
the number checked, agreements, and how many were QAMs.
"""
function new_model_matches_is_qam(; n::Int = 8, samples::Int = 4000, seed::Int = 11)
    rng = MersenneTwister(seed)
    checked = 0
    agree = 0
    qams = 0
    while checked < samples
        H = zeros(Int, n, n)
        for i = 1:n, j = (i + 1):n
            v = rand(rng, 0:((1 << n) - 1))
            H[i, j] = v
            H[j, i] = v
        end
        is_proper(H, n - 2) || continue
        checked += 1
        a = is_qam(H)
        b = new_model_is_qam(H)
        a == b && (agree += 1)
        a && (qams += 1)
    end
    (n = n, checked = checked, agree = agree, qams = qams)
end

"""
    redundancy_comparison() -> NamedTuple

The model's computational payoff for the pair `(x_13, x_7)` (paper eqs. (5)/(6)).
The *new model* requires `x_13, x_7, x_13⊕x_7 ∉ V` with `V` computed once; the
*old Algorithm 1* requires `x_13 ∉ V` and `x_7 ∉ Span(V, x_13)`, recomputing the
6-dim span for every `x_13`. The two conditions select the same pairs (so no
correctness change), but the new model evaluates one fixed span instead of `|A|`
distinct ones.
"""
function redundancy_comparison()
    V = f2_span(prop_V_basis_local())
    notV(x) = !(x in V)
    # new-model condition: single fixed span V
    new_valid = 0
    span_builds_new = 1                       # V built once
    for x13 = 0:255, x7 = 0:255
        (notV(x13) && notV(x7) && notV(x13 ⊻ x7)) && (new_valid += 1)
    end
    # old condition: x7 ∉ Span(V, x13), a new span per x13
    old_valid = 0
    span_builds_old = 0
    for x13 = 0:255
        notV(x13) || continue
        S = f2_span(vcat(prop_V_basis_local(), x13))   # rebuilt per x13
        span_builds_old += 1
        for x7 = 0:255
            (x7 in S) || (old_valid += 1)
        end
    end
    (
        valid_pairs_new = new_valid,
        valid_pairs_old = old_valid,
        same_pairs = new_valid == old_valid,
        span_builds_new = span_builds_new,
        span_builds_old = span_builds_old,
    )
end

# V = Span(g^34, g^81, g^83, g^170, g^106) (kept local to avoid a hard
# dependency on proposition3_partitions.jl).
prop_V_basis_local() = [gpow(34), gpow(81), gpow(83), gpow(170), gpow(106)]

function theorem6_report(io::IO = stdout; samples::Int = 2000)
    print_section("Theorem 6: new model for the last two columns (n = 8)", io)

    Hbase = h8_base()
    block6_proper = is_proper(Hbase, 6)
    seed_matches = new_model_is_qam(Hbase) && is_qam(Hbase)
    print_check("leading 6×6 block of H_8 is proper (Lemma 5 / Theorem 6 hypothesis)",
                block6_proper, io)
    print_check("new_model_is_qam(seed H_8) == is_qam(seed H_8) == true",
                seed_matches, io)

    by_n = Dict{String,Any}()
    for n in (5, 6, 8)
        m = new_model_matches_is_qam(; n = n, samples = (n == 8 ? min(samples, 600) : samples))
        print_check("new model == is_qam on $(m.checked) proper-block n=$(n) matrices",
                    m.agree == m.checked, io)
        print_kv("    (#QAMs among them)", m.qams, io)
        by_n["n$(n)"] = (checked = m.checked, agree = m.agree, qams = m.qams)
    end

    r = redundancy_comparison()
    print_check("eq.(5) and eq.(6) select the same (x_13, x_7) pairs", r.same_pairs, io)
    print_kv("    valid (x_13,x_7) pairs", r.valid_pairs_new, io)
    print_kv("    span constructions: new model vs Algorithm 1",
             "$(r.span_builds_new) vs $(r.span_builds_old)", io)

    (
        block6_proper = block6_proper,
        seed_matches = seed_matches,
        samples = by_n,
        same_pairs = r.same_pairs,
        valid_pairs = r.valid_pairs_new,
        span_builds_new = r.span_builds_new,
        span_builds_old = r.span_builds_old,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem6_report()
end
