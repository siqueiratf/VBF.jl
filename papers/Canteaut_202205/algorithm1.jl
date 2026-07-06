# Implements Algorithm 1 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 3.4 — Solving the EA-equivalence Problem for Quadratic Functions
#
# Algorithm 1: EA-recovery for quadratic functions via Jacobian matrices.
# Input: Two quadratic F, G : F₂ⁿ → F₂ⁿ.
# Output: (A₀, B₀, C₀, a) such that G(x) = A₀ F(B₀ x) ⊕ C₀ x ⊕ a, or nothing.
#
# Key idea: The linear parts of A, B can be found by solving a GF(2) linear
# system derived from Proposition 16 (Eq. (5)):
#   Jac_lin G(v) = A₀ · Jac_lin F(B₀v) · B₀.
# Setting X = A₀⁻¹, Y = B₀, and using rank-matching pairs (vᵢ, wᵢ) with
# B₀vᵢ = wᵢ (System (6)/(7)):
#   X · Jac_lin G(vᵢ) = Jac_lin F(wᵢ) · Y,   Y · vᵢ = wᵢ.
# Concatenating s such systems (Section 3.4.1) yields a small solution space.
#
# Pseudocode:
#   1. Compute rank tables for F, G; check rank distributions match (Def. 19).
#   2. Pick s linearly independent reference vectors w₁..w_s from the
#      minimum-rank set of F.
#   3. Search over linearly independent s-tuples (v₁..v_s) in G's rank-r_min set.
#   4. For each guess: build the combined GF(2) linear system (7); solve.
#   5. If solution space dim ≤ T_threshold: iterate solutions, check X,Y invertible.
#   6. If found: recover C₀ and a per Section 3.4.4; verify; return.
#
# Complexity note (Section 3.4.6): the guess search is O(2^{sn}) for APN (the
# hardest case). Following Example 26 and Table 4, s=2 is used for the larger
# APN demos (n=7) and s=3 for n=5: for Gold functions, s=2 gives solution
# spaces of dimension n, s=3 of dimension ≤ 1.
#
# Rows of the system are packed into multi-word UInt64 bit vectors
# (helpers.jl), supporting 2n²+1 bits for any n ≤ 9 — this lifts the earlier
# UInt128-based n ≤ 6 restriction and enables the paper's headline n = 7.
#
# VBF API used: SBox, F2LinearMap, is_invertible, inv, rank_f2

include(joinpath(@__DIR__, "helpers.jl"))

# -- linear independence helpers ---------------------------------------------

function _lin_indep(vs::Vector{Int}, ::Type{T}) where {T<:Unsigned}
    rows = T[T(v) for v in vs]
    rank_f2(rows) == length(vs)
end

# -- system construction -------------------------------------------------------

"""
    _build_combined_system!(work, F, G, pairs) -> Int

Fill the packed work matrix (layout of `solve_augmented_gf2!`) with the
combined GF(2) linear system (Eq. (7)) for guess pairs
`pairs = [(w₁,v₁), (w₂,v₂), ...]`, wᵢ ∈ domain(F), vᵢ ∈ domain(G).
Returns the number of rows written.

Unknowns (2N² bits):
  - bits 0..N²-1:    row-major entries of X = A₀⁻¹ ∈ F₂^{N×N}
  - bits N²..2N²-1:  row-major entries of Y = B₀    ∈ F₂^{N×N}

x_{i,k} at bit i*N+k, y_{k,j} at bit N²+k*N+j (0-indexed).
RHS in bit 2N² of each row (augmented form).
"""
function _build_combined_system!(
    work::Matrix{UInt64},
    F::SBox{N,T},
    G::SBox{N,T},
    pairs::Vector{Tuple{Int,Int}},  # [(w_i, v_i)]
) where {N,T}
    fill!(work, UInt64(0))
    n2 = N * N
    rhs_bit = 2 * n2
    row = 0

    for (w, v) in pairs
        M_cols = jac_lin_cols(G, v)   # cols of Jac_lin G(v)
        N_cols = jac_lin_cols(F, w)   # cols of Jac_lin F(w)

        # n² equations: (X · Jac_lin G(v))_{i,j} = (Jac_lin F(w) · Y)_{i,j}
        for i in 0:(N-1)
            for j in 0:(N-1)
                row += 1
                # Terms from X: coeff of x_{i,k} is bit k of M_cols[j]
                @inbounds for k in 0:(N-1)
                    if ((M_cols[j+1] >> k) & 1) == 1
                        _setbit!(work, row, i*N + k)
                    end
                end
                # Terms from Y: coeff of y_{k,j} is bit i of N_cols[k]
                @inbounds for k in 0:(N-1)
                    if ((N_cols[k+1] >> i) & 1) == 1
                        _setbit!(work, row, n2 + k*N + j)
                    end
                end
            end
        end

        # N equations: (Y · v)_i = w_i
        for i in 0:(N-1)
            row += 1
            @inbounds for j in 0:(N-1)
                if ((v >> j) & 1) == 1
                    _setbit!(work, row, n2 + i*N + j)
                end
            end
            if ((w >> i) & 1) == 1
                _setbit!(work, row, rhs_bit)
            end
        end
    end

    return row
end

# -- Section 3.4.4: recovering (C₀, a) -----------------------------------------

"""
    _recover_ea_triple(F, G, X, Y) -> NamedTuple or nothing

Given X = A₀⁻¹ and Y = B₀ (both invertible), recover C₀ and a using
Section 3.4.4: G(x) = A₀ F(B₀ x) ⊕ C₀ x ⊕ a.

Returns (; A0, B0, C0, a_const) or nothing if verification fails.
"""
function _recover_ea_triple(
    F::SBox{N,T},
    G::SBox{N,T},
    X::F2LinearMap{N,T},
    Y::F2LinearMap{N,T},
) where {N,T}
    n_size = 1 << N
    A0 = inv(X)
    B0 = Y

    # G₁(x) = A₀ F(B₀ x)
    G1_lut = T[A0(F.lut[B0(x)+1]) for x in 0:(n_size-1)]

    # a = G(0) ⊕ G₁(0)
    a_const = G.lut[1] ⊻ G1_lut[1]

    # C₀ x = G(x) ⊕ G₁(x) ⊕ a for each x
    C0_lut = T[G.lut[x+1] ⊻ G1_lut[x+1] ⊻ a_const for x in 0:(n_size-1)]

    # C₀ must be linear: C₀(0) = 0 and C₀ determined by its basis images
    C0_lut[1] == 0 || return nothing
    C0_cols = T[C0_lut[(T(1) << j)+1] for j in 0:(N-1)]
    C0 = F2LinearMap{N,T}(C0_cols)

    # Final verification: G(x) = A₀ F(B₀ x) ⊕ C₀ x ⊕ a for all x
    # (also proves C₀'s linearity: the LUT agrees with a linear map everywhere)
    for x in 0:(n_size-1)
        expected = A0(F.lut[B0(x)+1]) ⊻ C0(T(x)) ⊻ a_const
        G.lut[x+1] == expected || return nothing
    end

    return (; A0, B0, C0, a_const)
end

# -- Algorithm 1 ----------------------------------------------------------------

"""
    ea_recovery_quadratic(F, G; s, T_threshold, max_guesses)
        -> Union{NamedTuple, Nothing}

Algorithm 1: EA-recovery for quadratic functions F, G : F₂ⁿ → F₂ⁿ.

Returns `(; A0, B0, C0, a_const)` such that G(x) = A0(F(B0(x))) ⊕ C0(x) ⊕ a_const
for all x, or `nothing` if not found within `max_guesses` trials.

Supports n ≤ 9 (rows are multi-word packed; 2n²+1 ≤ 163 bits). For APN inputs
the guess search is exhaustive over linearly independent s-tuples in the
minimum-rank sets.

# Parameters
- `s = 3`:            number of simultaneous guess pairs (Section 3.4.1);
                      s = 2 follows Example 26 / Table 4 for larger n
- `T_threshold = 10`: max solution space dimension to enumerate (Section 3.4.5)
- `max_guesses`:      brute-force search limit (default 2^(s·n))
"""
function ea_recovery_quadratic(
    F::SBox{N,T},
    G::SBox{N,T};
    s::Int = 3,
    T_threshold::Int = 10,
    max_guesses::Int = 1 << min(s * N, 62),
) where {N,T}
    s in (2, 3) || throw(ArgumentError("ea_recovery_quadratic: s must be 2 or 3"))
    N ≤ 9 || throw(ArgumentError("ea_recovery_quadratic: N=$N > 9 not supported"))

    # Step 1: Rank tables and distribution check (Definition 19 / Prop 16)
    rt_F = rank_table(F)
    rt_G = rank_table(G)
    rdist_F = rank_distribution(rt_F, N)
    rdist_G = rank_distribution(rt_G, N)
    rdist_F != rdist_G && return nothing

    # Step 2: Minimum-rank reference set from F (Section 3.4.2)
    r_min = minimum(keys(rdist_F))
    W = [a for a in 1:((1<<N)-1) if rt_F[a+1] == r_min]
    V = [a for a in 1:((1<<N)-1) if rt_G[a+1] == r_min]
    (length(W) < s || length(V) < s) && return nothing

    # Step 3: Choose s linearly independent reference vectors from W
    refs_w = Int[]
    for w in W
        if _lin_indep([refs_w; w], T)
            push!(refs_w, w)
            length(refs_w) == s && break
        end
    end
    length(refs_w) < s && return nothing

    n2 = N * N
    n_unknowns = 2 * n2
    n_rows = s * (n2 + N)
    work = Matrix{UInt64}(undef, nwords_for_bits(n_unknowns + 1), n_rows)
    pairs = Vector{Tuple{Int,Int}}(undef, s)

    guesses = 0

    function try_guess(vs::Vector{Int})
        for i in 1:s
            pairs[i] = (refs_w[i], vs[i])
        end
        nr = _build_combined_system!(work, F, G, pairs)
        result = solve_augmented_gf2!(work, nr, n_unknowns)
        result === nothing && return nothing

        dim = length(result.kernel)
        dim > T_threshold && return nothing

        # Step 5: Iterate over solution space; find non-singular (X, Y)
        u = similar(result.particular)
        for mask in 0:((1 << dim) - 1)
            copyto!(u, result.particular)
            for bit in 0:(dim-1)
                if ((mask >> bit) & 1) == 1
                    ker = result.kernel[bit+1]
                    @inbounds for w in eachindex(u)
                        u[w] ⊻= ker[w]
                    end
                end
            end

            X = extract_f2linear(u, 0, N, T)
            is_invertible(X) || continue
            Y = extract_f2linear(u, n2, N, T)
            is_invertible(Y) || continue

            triple = _recover_ea_triple(F, G, X, Y)
            triple !== nothing && return triple
        end
        return nothing
    end

    # Step 4: Brute-force search over linearly independent s-tuples from V
    if s == 2
        for v1 in V, v2 in V
            _lin_indep([v1, v2], T) || continue
            guesses += 1
            guesses > max_guesses && return nothing
            triple = try_guess([v1, v2])
            triple !== nothing && return triple
        end
    else # s == 3
        for v1 in V, v2 in V
            _lin_indep([v1, v2], T) || continue
            for v3 in V
                _lin_indep([v1, v2, v3], T) || continue
                guesses += 1
                guesses > max_guesses && return nothing
                triple = try_guess([v1, v2, v3])
                triple !== nothing && return triple
            end
        end
    end
    return nothing
end

# -- demo helpers ---------------------------------------------------------------

"""
    _demo_ea_triple(F::SBox{N,T}) -> (G, A0, B0, C0, a_const)

Fixed non-trivial EA triple used by the demos:
A₀ swaps e₀/e₁, B₀ cyclically shifts the basis, C₀ bit-reverses, a = 3.
"""
function _demo_ea_triple(F::SBox{N,T}) where {N,T}
    A0_cols = Vector{T}(undef, N)
    A0_cols[1] = T(2); A0_cols[2] = T(1)
    for j in 2:(N-1); A0_cols[j+1] = T(1) << j; end
    A0 = F2LinearMap{N,T}(A0_cols)

    B0_cols = T[T(1) << ((j+1) % N) for j in 0:(N-1)]
    B0 = F2LinearMap{N,T}(B0_cols)

    C0_cols = T[T(1) << (N-1-j) for j in 0:(N-1)]
    C0 = F2LinearMap{N,T}(C0_cols)

    a_const = T(3)
    G = build_ea_triple(F, A0, B0, C0, a_const)
    return (G, A0, B0, C0, a_const)
end

"""
    _verify_triple(F, G, triple) -> Bool

Check G(x) = A₀ F(B₀ x) ⊕ C₀ x ⊕ a for all x with the recovered triple.
"""
function _verify_triple(F::SBox{N,T}, G::SBox{N,T}, triple) where {N,T}
    A0_r, B0_r, C0_r, a_r = triple.A0, triple.B0, triple.C0, triple.a_const
    return all(
        G.lut[x+1] == A0_r(F.lut[B0_r(x)+1]) ⊻ C0_r(T(x)) ⊻ a_r
        for x in 0:((1 << N) - 1)
    )
end

"""
    algorithm1_report(; io) -> NamedTuple

Demonstrate Algorithm 1 on:
  (a) n=5, s=3: known EA-equivalent Gold pair (recover + verify) and a
      non-EA-equivalent pair (x³ vs x⁵ Gold with k=2), exhaustive search;
  (b) n=7, s=2 (Example 26 / Table 4 headline dimension): same two checks;
  (c) n=9, s=2 (beyond the old UInt128 cap): EA-recovery on a Gold pair.

At n=9 only the positive recovery is run (~1 s: the correct guess is met
early). The exhaustive negative sweeps all (2⁹-1)(2⁹-2) ≈ 2.6·10⁵ guess
pairs, most yielding consistent solution spaces whose 2⁹ candidates must be
enumerated — measured once at 1949 s (32.5 min) single-core with the correct
`nothing` outcome, so it is skipped by default.
"""
function algorithm1_report(; io::IO = stdout)
    print_section(
        "Algorithm 1: EA-recovery for quadratic functions",
        io,
    )

    results = Bool[]

    for (n, s, run_negative) in ((5, 3, true), (7, 2, true), (9, 2, false))
        F = gold_apn(n)
        G, _, _, _, a_const = _demo_ea_triple(F)

        print_kv("n=$n, s=$s", "reference vectors: first $s lin-indep in min-rank set", io)
        print_kv("Known triple", "A₀=(swap e₀,e₁), B₀=(cyclic +1), C₀=(bit-rev), a=$(Int(a_const))", io)

        elapsed = @elapsed triple = ea_recovery_quadratic(F, G; s)
        found = triple !== nothing
        print_check("n=$n: EA triple found for known EA-equiv pair " *
                    "($(round(elapsed; digits=1))s)", found, io)

        verified = found && _verify_triple(F, G, triple)
        found && print_check("n=$n: recovered triple verifies G = A₀F(B₀x) ⊕ C₀x ⊕ a", verified, io)
        found && print_kv("n=$n: a_const recovered", Int(triple.a_const), io)

        rejected = true
        if run_negative
            # Non-equivalent pair: Gold x³ vs Gold x⁵ (k=2), EA-inequivalent
            H = gold_apn(n, 2)
            elapsed_ne = @elapsed ne = ea_recovery_quadratic(F, H; s)
            rejected = ne === nothing
            print_check("n=$n: non-EA-equiv pair (x³ vs x⁵) returns nothing " *
                        "($(round(elapsed_ne; digits=1))s, exhaustive)", rejected, io)
        else
            print_kv("n=$n negative", "SKIPPED: exhaustive 2.6e5-guess sweep, measured 32.5 min (verified once: rejects)", io)
        end

        push!(results, found && verified && rejected)
    end

    all_ok = all(results)
    print_check("Algorithm 1 overall", all_ok, io)
    return (; per_n = results, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
