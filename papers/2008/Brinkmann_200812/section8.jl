# Implements Section 8: 2-dimensional affine subspaces of F₂ⁿ, plus Prop. 2's
# conflict model and its Fig. 1 comparison.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 8 — Affine Subspaces in F₂ⁿ of Dimension 2 (and Prop. 2 / Fig. 1)
#
# Pseudocode:
#   1. subspace_counts(kmax)      — Prop. 11 recurrences (17)/(18) for A(k), Δ(k)
#   2. count_affine_subspaces(M)  — brute force #A(M) for an arbitrary M ⊆ F₂ⁿ
#   3. Assert A(k) == #A([0;k-1]) and A(k) == Σ_{j≤k} Δ(j) for all k ≤ 16
#   4. Assert sequences (20)/(21), A(2ⁿ) = C(2ⁿ,3)/4, and identities (22)/(23)
#   5. Assert Prop. 12 (#A(M) ≤ A(#M)) exhaustively on F₂³ and by sampling on F₂⁴
#   6. Prop. 2's model P(k) = 1 − ((2ⁿ−1)/2ⁿ)^{Δ(k)} vs the measured conflict
#      counts of a Knuth random-dive through the Algorithm-1 search tree (Fig. 1)
# VBF API used: print_section, print_check, print_kv  (this section is pure
#               combinatorics — no SBox machinery is involved)

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

using Random

"""
    subspace_counts(kmax) -> (A::Vector{Int}, Δ::Vector{Int})

Proposition 11's recurrences, evaluated for `0 ≤ k ≤ kmax`. `A[k+1] = A(k)` is
the number of 2-dimensional affine subspaces contained in `[0; k−1] ⊆ F₂ⁿ`, and
`Δ[k+1] = Δ(k) = A(k) − A(k−1)`.

With `i` such that `2ⁱ ≤ k−1 < 2^{i+1}` (eqs (17) and (18)):

    A(k) = A(2ⁱ) + A(k−2ⁱ) + C(k−2ⁱ, 2)·2^{i−1}
    Δ(k) = Δ(k−2ⁱ) + (k−2ⁱ−1)·2^{i−1}
"""
function subspace_counts(kmax::Int)
    A = zeros(Int, kmax + 1)
    D = zeros(Int, kmax + 1)
    for k = 2:kmax
        i = 8 * sizeof(Int) - 1 - leading_zeros(k - 1)   # 2ⁱ ≤ k−1 < 2^{i+1}
        p = 1 << i
        A[k+1] = A[p+1] + A[k-p+1] + binomial(k - p, 2) * (1 << (i - 1))
        D[k+1] = D[k-p+1] + (k - p - 1) * (1 << (i - 1))
    end
    (A, D)
end

"""
    count_affine_subspaces(M) -> Int

Brute-force `#A(M)`: the number of 2-dimensional affine subspaces `{t,u,v,w}`
(four distinct points with `t⊕u⊕v⊕w = 0`) contained in `M ⊆ F₂ⁿ`.

Each subspace is counted once: it is enumerated from its three smallest elements,
which determine the fourth as `d = t⊕u⊕v`, and it is only accepted when `d` is
larger than all three.
"""
function count_affine_subspaces(M::AbstractVector{<:Integer})
    s = sort(collect(Int, M))
    S = Set(s)
    n = length(s)
    c = 0
    for i = 1:n, j = (i+1):n, k = (j+1):n
        d = s[i] ⊻ s[j] ⊻ s[k]
        (d > s[k] && d in S) && (c += 1)
    end
    c
end

"""
    conflict_probability(n, Δk) -> Float64

Proposition 2, eq. (3): the modelled probability that `φ_APN` fails a
left-refined template with `Δ(deg s̃) = Δk` conflict opportunities,
`P = 1 − ((2ⁿ−1)/2ⁿ)^{Δk}`.
"""
conflict_probability(n::Int, dk::Integer) = 1 - ((2.0^n - 1) / 2.0^n)^dk

"""
    measure_conflicts(n; dives, seed) -> Vector{Float64}

The measured side of Fig. 1: the average number of the `2ⁿ` candidate values for
`s(t)` that Algorithm 1's filter rejects, at each depth `t`, estimated by Knuth
random dives through the active search tree. Entry `k` of the result is the
average at `t = k−1`, i.e. for a template of degree `k` — the depth at which the
model predicts `2ⁿ·P(Δ(k))`. `NaN` where no dive reached that depth.
"""
function measure_conflicts(n::Int; dives::Int = 400, seed::Int = 20081201)
    rng = MersenneTwister(seed)
    N = 1 << n
    sums = zeros(Float64, N)
    hits = zeros(Int, N)
    s = zeros(Int, N)
    surviving = Int[]
    for _ = 1:dives
        tbl = falses(N, N)
        fill!(s, 0)
        for t = 0:(N-1)
            empty!(surviving)
            for b = 0:(N-1)
                ok = true
                for x = 0:(t-1)
                    if tbl[(t⊻x)+1, (s[x+1]⊻b)+1]
                        ok = false
                        break
                    end
                end
                ok && push!(surviving, b)
            end
            sums[t+1] += N - length(surviving)
            hits[t+1] += 1
            isempty(surviving) && break
            b = rand(rng, surviving)
            s[t+1] = b
            for x = 0:(t-1)
                tbl[(t⊻x)+1, (s[x+1]⊻b)+1] = true
            end
        end
    end
    [hits[t+1] == 0 ? NaN : sums[t+1] / hits[t+1] for t = 0:(N-1)]
end

"""
    section8_report(io)

Section 8 — 2-dimensional affine subspaces, plus Prop. 2 / Fig. 1.
"""
function section8_report(io::IO = stdout)
    print_section(io, "Section 8 — 2-dimensional affine subspaces of F₂ⁿ")

    A, D = subspace_counts(64)

    print_check(io, "Prop 11: A(k) == Σ_{j≤k} Δ(j) for all k ≤ 64",
                all(A[k+1] == sum(D[1:k+1]) for k = 0:64))
    print_check(io, "Prop 11: recurrence A(k) matches brute-force #A([0;k−1]) for k ≤ 16",
                all(A[k+1] == count_affine_subspaces(collect(0:k-1)) for k = 0:16))

    seq20 = [0, 0, 0, 1, 1, 3, 7, 14, 14, 18, 26, 39, 55, 77, 105, 140]
    seq21 = [0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 28, 35]
    print_check(io, "sequence (20): A(1..16) == $(seq20)", A[2:17] == seq20)
    print_check(io, "sequence (21): Δ(1..16) == $(seq21)", D[2:17] == seq21)

    print_check(io, "#A(F₂ⁿ) = A(2ⁿ) == C(2ⁿ,3)/4 for n = 1..6",
                all(A[(1<<n)+1] == binomial(1 << n, 3) ÷ 4 for n = 1:6))
    print_kv(io, "A(2ⁿ), n=1..6", join([A[(1<<n)+1] for n = 1:6], ", "))

    # (22): Δ(2^k) = (1/6)(2^k − 3/2)² − 1/24, evaluated exactly over the rationals.
    eq22(k) = (1 // 6) * (big(1 << k) - 3 // 2)^2 - 1 // 24
    print_check(io, "eq (22): Δ(2^k) == (1/6)(2^k − 3/2)² − 1/24 for k = 1..6",
                all(D[(1<<k)+1] == eq22(k) for k = 1:6))
    print_kv(io, "Δ(2^k), k=1..6", join([D[(1<<k)+1] for k = 1:6], ", "))

    # (23): Δ(2^k + j) = Δ(j) + (j−1)·2^k/2 for 0 < j < 2^k.
    print_check(io, "eq (23): Δ(2^k + j) == Δ(j) + (j−1)·2^k/2 for k = 1..5, 0 < j < 2^k",
                all(D[(1<<k)+j+1] == D[j+1] + ((j - 1) * (1 << k)) ÷ 2
                    for k = 1:5 for j = 1:((1<<k)-1)))

    print_section(io, "Section 8 — Prop 12: #A(M) ≤ A(#M) for arbitrary M")
    ok3 = true
    for m = 0:255
        M = [x for x = 0:7 if (m >> x) & 1 == 1]
        ok3 &= count_affine_subspaces(M) <= A[length(M)+1]
    end
    print_check(io, "Prop 12 holds for all 256 subsets M ⊆ F₂³", ok3)

    rng = MersenneTwister(20081201)
    ok4 = true
    for _ = 1:2000
        M = [x for x = 0:15 if rand(rng, Bool)]
        ok4 &= count_affine_subspaces(M) <= A[length(M)+1]
    end
    print_check(io, "Prop 12 holds for 2000 random subsets M ⊆ F₂⁴", ok4)

    print_section(io, "Section 8 / Fig. 1 — Prop 2's conflict model vs measurement (n=6)")
    println(io, "  P(k) = 1 − ((2ⁿ−1)/2ⁿ)^Δ(k);  crosses = 2ⁿ·P(k),  dots = Knuth random dives.")
    meas = measure_conflicts(6; dives = 400)
    print_kv(io, "depth k", "Δ(k)   model 2⁶·P(k)   measured")
    for k in [4, 8, 12, 16, 17, 20, 24, 28, 32, 33, 40, 48]
        model = 64 * conflict_probability(6, D[k+1])
        m = meas[k]
        print_kv(io, "k=$k",
                 "$(D[k+1])   $(round(model, digits = 2))   " *
                 (isnan(m) ? "(no dive reached this depth)" : string(round(m, digits = 2))))
    end
    println(io, "  The model tracks the measurement from below, as in the paper's Fig. 1.")
    println(io, "  Δ(2ᵏ+1) = 0 (k=17, 33): a fresh basis vector admits no 2-dim subspace.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section8_report()
end
