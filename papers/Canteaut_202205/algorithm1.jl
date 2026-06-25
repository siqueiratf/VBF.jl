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
# system derived from Section 3.2: Jac_lin G(v) = A₀ · Jac_lin F(B₀v) · B₀.
# Setting X = A₀⁻¹, Y = B₀, and using rank-matching pairs (v_i, w_i) with B₀v_i = w_i:
#   X · Jac_lin G(v_i) = Jac_lin F(w_i) · Y,   Y · v_i = w_i.
# Concatenating s=3 such systems yields (generically) a unique solution.
#
# Pseudocode:
#   1. Compute rank tables for F, G; check rank distributions match.
#   2. Pick s=3 linearly independent reference vectors w₁,w₂,w₃ from the
#      minimum-rank set of F.
#   3. Search over linearly independent triples (v₁,v₂,v₃) in G's rank-r_min set.
#   4. For each guess: build the combined GF(2) linear system; solve.
#   5. If solution space dim ≤ T_threshold: iterate solutions, check X,Y invertible.
#   6. If found: recover C₀ and a from Section 3.4.4; verify; return.
#
# Complexity note (Section 3.4.6): O(n^{2ω} 2^{2n}) for APN (hardest case).
# For n=5, brute-force over 31³ ≈ 30k triples is fast in practice.
# Supported range: n ≤ 6 (requires 2n² ≤ 72 bits, fitting in UInt128).
#
# VBF API used: SBox, F2LinearMap, is_invertible, inv, compose, rank_f2

include(joinpath(@__DIR__, "helpers.jl"))

# ── Linear-independence helpers ────────────────────────────────────────────────

function _lin_indep_2(a::Int, b::Int, ::Type{T}) where {T<:Unsigned}
    rows = T[T(a), T(b)]
    rank_f2(rows) == 2
end

function _lin_indep_3(a::Int, b::Int, c::Int, ::Type{T}) where {T<:Unsigned}
    rows = T[T(a), T(b), T(c)]
    rank_f2(rows) == 3
end

# ── GF(2) system construction ─────────────────────────────────────────────────

"""
    _build_combined_system(F, G, pairs, N, T) -> Vector{UInt128}

Build the combined GF(2) linear system (equation 7) for guess pairs
`pairs = [(w₁,v₁), (w₂,v₂), ...]`, where wᵢ ∈ domain(F), vᵢ ∈ domain(G).

Unknowns (2N² bits):
  - bits 0..N²-1:    row-major entries of X = A₀⁻¹ ∈ F₂^{N×N}
  - bits N²..2N²-1:  row-major entries of Y = B₀    ∈ F₂^{N×N}

x_{i,k} at bit i*N+k (entry (i,k) of X, 0-indexed)
y_{k,j} at bit N²+k*N+j (entry (k,j) of Y, 0-indexed)

RHS packed in bit 2N² of each row (augmented form).
"""
function _build_combined_system(
    F::SBox{N,T},
    G::SBox{N,T},
    pairs::Vector{Tuple{Int,Int}},  # [(w_i, v_i)]
) where {N,T}
    n2 = N * N
    n_unknowns = 2 * n2
    rhs_shift = n_unknowns

    rows = UInt128[]
    sizehint!(rows, length(pairs) * (n2 + N))

    for (w, v) in pairs
        M_cols = jac_lin_cols(G, v)   # cols of Jac_lin G(v)
        N_cols = jac_lin_cols(F, w)   # cols of Jac_lin F(w)

        # n² equations: (X · Jac_lin G(v))_{i,j} = (Jac_lin F(w) · Y)_{i,j}
        for i in 0:(N-1)
            for j in 0:(N-1)
                row = UInt128(0)
                # Terms from X: coeff of x_{i,k} is bit k of M_cols[j]
                @inbounds for k in 0:(N-1)
                    if ((M_cols[j+1] >> k) & 1) == 1
                        row |= UInt128(1) << (i*N + k)
                    end
                end
                # Terms from Y: coeff of y_{k,j} is bit i of N_cols[k]
                @inbounds for k in 0:(N-1)
                    if ((N_cols[k+1] >> i) & 1) == 1
                        row |= UInt128(1) << (n2 + k*N + j)
                    end
                end
                push!(rows, row)  # RHS = 0
            end
        end

        # N equations: (Y · v)_i = w_i
        for i in 0:(N-1)
            row = UInt128(0)
            @inbounds for j in 0:(N-1)
                if ((v >> j) & 1) == 1
                    row |= UInt128(1) << (n2 + i*N + j)
                end
            end
            rhs_bit = (w >> i) & 1
            if rhs_bit == 1
                row |= UInt128(1) << rhs_shift
            end
            push!(rows, row)
        end
    end

    return rows
end

# ── EA-recovery Section 3.4.4 ─────────────────────────────────────────────────

"""
    _recover_ea_triple(F, G, A0inv, B0, N, T) -> NamedTuple or nothing

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

    # C₀ must be linear: C₀(0) = 0 and C₀(x⊕y) = C₀(x) ⊻ C₀(y)
    C0_lut[1] == 0 || return nothing
    for x in 1:(n_size-1)
        for y in (x+1):(n_size-1)
            C0_lut[(x⊻y)+1] == C0_lut[x+1] ⊻ C0_lut[y+1] || return nothing
        end
    end

    # Extract C₀ as F2LinearMap from its images on basis vectors
    C0_cols = T[C0_lut[(T(1) << j)+1] for j in 0:(N-1)]
    C0 = F2LinearMap{N,T}(C0_cols)

    # Final verification: G(x) = A₀ F(B₀ x) ⊕ C₀ x ⊕ a for all x
    for x in 0:(n_size-1)
        expected = A0(F.lut[B0(x)+1]) ⊻ C0(T(x)) ⊻ a_const
        G.lut[x+1] == expected || return nothing
    end

    return (; A0, B0, C0, a_const)
end

# ── Main Algorithm 1 ──────────────────────────────────────────────────────────

"""
    ea_recovery_quadratic(F, G; s, T_threshold, max_guesses, seed)
        -> Union{NamedTuple, Nothing}

Algorithm 1: EA-recovery for quadratic functions F, G : F₂ⁿ → F₂ⁿ.

Returns `(; A0, B0, C0, a_const)` such that G(x) = A0(F(B0(x))) ⊕ C0(x) ⊕ a_const
for all x, or `nothing` if not found within `max_guesses` trials.

Requires N ≤ 6 (2N² ≤ 72 bits fit in UInt128). For APN functions with N=5,
the algorithm typically succeeds within the first few hundred guesses.

# Parameters
- `s = 3`:           number of simultaneous guess pairs (Section 3.4.1)
- `T_threshold = 10`: max solution space dimension to enumerate (Section 3.4.5)
- `max_guesses`:     brute-force search limit (default 2^(3N))
"""
function ea_recovery_quadratic(
    F::SBox{N,T},
    G::SBox{N,T};
    s::Int = 3,
    T_threshold::Int = 10,
    max_guesses::Int = 1 << (3 * N),
) where {N,T}
    N ≤ 6 || throw(ArgumentError("ea_recovery_quadratic: N=$N > 6 not supported (UInt128 limit)"))

    # Step 1: Rank tables and distribution check
    rt_F = rank_table(F)
    rt_G = rank_table(G)
    rdist_F = rank_distribution(rt_F, N)
    rdist_G = rank_distribution(rt_G, N)
    rdist_F != rdist_G && return nothing

    # Step 2: Minimum-rank reference set from F
    r_min = minimum(keys(rdist_F))
    W = [a for a in 1:((1<<N)-1) if rt_F[a+1] == r_min]
    V = [a for a in 1:((1<<N)-1) if rt_G[a+1] == r_min]
    (length(W) < s || length(V) < s) && return nothing

    # Step 3: Choose s linearly independent reference vectors from W
    refs_w = Int[]
    for w in W
        isempty(refs_w) && (push!(refs_w, w); continue)
        length(refs_w) == 1 && _lin_indep_2(refs_w[1], w, T) && (push!(refs_w, w); continue)
        length(refs_w) == 2 && _lin_indep_3(refs_w[1], refs_w[2], w, T) &&
            (push!(refs_w, w); break)
    end
    length(refs_w) < s && return nothing

    n2 = N * N
    n_unknowns = 2 * n2

    # Step 4: Brute-force search over linearly independent (v₁, v₂, v₃) from V
    guesses = 0
    @inbounds for v1 in V
        for v2 in V
            _lin_indep_2(v1, v2, T) || continue
            for v3 in V
                _lin_indep_3(v1, v2, v3, T) || continue
                guesses += 1
                guesses > max_guesses && return nothing

                pairs = [(refs_w[1], v1), (refs_w[2], v2), (refs_w[3], v3)]
                sys_rows = _build_combined_system(F, G, pairs)
                result = solve_augmented_gf2(sys_rows, n_unknowns)
                result === nothing && continue

                particular, ker = result
                length(ker) > T_threshold && continue

                # Step 5: Iterate over solution space; find non-singular (X, Y)
                dim = length(ker)
                for mask in 0:((1 << dim) - 1)
                    u = particular
                    for bit in 0:(dim-1)
                        if ((mask >> bit) & 1) == 1
                            u ⊻= ker[bit+1]
                        end
                    end

                    X = extract_f2linear(u, 0, N, T)
                    is_invertible(X) || continue
                    Y = extract_f2linear(u, n2, N, T)
                    is_invertible(Y) || continue

                    triple = _recover_ea_triple(F, G, X, Y)
                    triple !== nothing && return triple
                end
            end
        end
    end
    return nothing
end

# ── Report ────────────────────────────────────────────────────────────────────

"""
    algorithm1_report(; io, n, seed) -> NamedTuple

Demonstrate Algorithm 1 on:
  (a) Known EA-equivalent pair: G = A₀ ∘ (Gold x^3 n=5) ∘ B₀ ⊕ C₀ ⊕ a
  (b) Non-EA-equivalent pair: Gold x^3 vs a modified function

Returns (found, verified, non_equiv_rejected).
Completeness: exhaustive over all linearly independent triples up to max_guesses.
"""
function algorithm1_report(; io::IO = stdout, n::Int = 5, seed::Int = 42)
    print_section(
        "Algorithm 1: EA-recovery for quadratic functions (n=$n, bounded)",
        io,
    )
    N = n

    T = N ≤ 8 ? UInt8 : UInt16
    F = gold_apn(N)

    # Build a known EA-equivalent pair with explicit (A₀, B₀, C₀, a)
    # A₀: swap images of e₀ and e₁
    A0_cols = Vector{T}(undef, N)
    A0_cols[1] = T(2); A0_cols[2] = T(1)
    for j in 2:(N-1); A0_cols[j+1] = T(1) << j; end
    A0 = F2LinearMap{N,T}(A0_cols)

    # B₀: cyclic shift eⱼ → e_{j+1 mod N}
    B0_cols = Vector{T}(undef, N)
    for j in 0:(N-1); B0_cols[j+1] = T(1) << ((j+1) % N); end
    B0 = F2LinearMap{N,T}(B0_cols)

    # C₀: bit-reverse linear map (eⱼ → e_{N-1-j})
    C0_cols = T[T(1) << (N-1-j) for j in 0:(N-1)]
    C0 = F2LinearMap{N,T}(C0_cols)

    a_const = T(3)  # arbitrary nonzero constant

    n_size = 1 << N
    G_lut = T[A0(F.lut[B0(x)+1]) ⊻ C0(T(x)) ⊻ a_const for x in 0:(n_size-1)]
    G = SBox{N,T}(G_lut)

    print_kv("Reference vectors (w₁,w₂,w₃)", "first 3 lin-indep in rank-$(N-1) set", io)
    print_kv("Known triple", "A₀=(swap e₀,e₁), B₀=(cyclic +1), C₀=(bit-rev), a=$(Int(a_const))", io)

    # Run Algorithm 1
    max_g = 1 << (3*N)
    triple = ea_recovery_quadratic(F, G; max_guesses=max_g)

    found = triple !== nothing
    print_check("Algorithm 1: EA triple found for known EA-equiv pair", found, io)

    verified = false
    if found
        # Verify recovered triple: G(x) = A0_r(F(B0_r(x))) ⊕ C0_r(x) ⊕ a_r for all x
        A0_r, B0_r, C0_r, a_r = triple.A0, triple.B0, triple.C0, triple.a_const
        verified = all(
            G.lut[x+1] == A0_r(F.lut[B0_r(x)+1]) ⊻ C0_r(T(x)) ⊻ a_r
            for x in 0:(n_size-1)
        )
        print_check("Recovered triple verifies G(x) = A₀ F(B₀ x) ⊕ C₀ x ⊕ a", verified, io)
        print_kv("a_const recovered", Int(a_r), io)
    end

    # Non-equivalent test: Gold x^3 vs Kasami (if available) or a random quadratic
    lut_k = gf_monomial_lut(N, (1 << (N ÷ 2)) + 1)  # Kasami-like exponent
    H = SBox{N,T}(T.(lut_k))
    non_equiv_result = ea_recovery_quadratic(F, H; max_guesses=max_g)
    non_equiv_rejected = non_equiv_result === nothing
    print_check(
        "Algorithm 1: non-EA-equiv pair returns nothing (or rejected by rank dist)",
        non_equiv_rejected,
        io,
    )

    print_kv(
        "Completeness",
        "exhaustive search up to $(max_g) linearly-independent triples",
        io,
    )

    all_ok = found && verified && non_equiv_rejected
    print_check("Algorithm 1 overall", all_ok, io)
    return (; found, verified, non_equiv_rejected, all_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
