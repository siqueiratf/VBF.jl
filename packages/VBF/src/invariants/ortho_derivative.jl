"""
The ortho-derivative of an APN function.

For a **quadratic** APN function `F : F₂ⁿ → F₂ⁿ`, the discrete derivative
`D_a F(x) := F(x) ⊕ F(x ⊕ a)` is an affine function of `x` (since `F` is
quadratic) for every fixed `a`. The image set `H_a := {D_a F(x) : x ∈
F₂ⁿ}` has exactly `2^{n-1}` elements (APN-ness), i.e., it is an
**affine hyperplane** in `F₂ⁿ`. The hyperplane's **direction** is a
one-dimensional subspace; its annihilator contains a unique non-zero
vector `π_F(a)` with `⟨π_F(a), v⟩ = 1` for every `v ∈ H_a`.

The function `π_F : a ↦ π_F(a)` (with `π_F(0) := 0` by convention) is
the **ortho-derivative** of `F`. The linear-equivalence class of `π_F`
is an **EA-equivalence invariant** of quadratic APN `F`
([Canteaut, Couvreur and Perrin, 2022](@cite CanteautCouvreurPerrin2022EA); the
quadratic CCZ ⟺ EA fact it builds on is [Yoshiara, 2012](@cite Yoshiara2012)).
This makes `π_F` an extremely
fast CCZ/EA-distinguisher for quadratic APN, including the monomial
APN where the k=4 multiplicity partition is degenerate.
"""

"""
    ortho_derivative(F::SBox{N,T}) -> Union{SBox{N,T}, Nothing}

The ortho-derivative `π_F` of `F`, when defined. Returns

- `SBox{N,T}` — the LUT of `π_F` with `π_F(0) = 0`, if `F` is a
  quadratic APN function.
- `nothing` — if `F` is not a quadratic APN function (either because
  the differential uniformity is not `2`, or because some `D_a F` is
  not affine, both of which prevent the construction from succeeding).

# Algorithm

For each non-zero `a`:

  1. Compute the DDT row `DDT(a, ·)`.
  2. `H_a := {b ≠ 0 : DDT(a, b) ≠ DDT(a, 0)}` — the non-zero
     differences achieved by `D_a F`. APN requires `|H_a| = 2^{n-1}`.
  3. Brute-force search for `ortho ∈ 1:2ⁿ-1` such that `⟨ortho, b⟩ = 1`
     for every `b ∈ H_a` — this `ortho` is `π_F(a)`. If no such ortho
     exists, `F` is not a quadratic APN and we return `nothing`.

# Examples

```jldoctest
julia> using VBF

julia> π = ortho_derivative(load_apn_function("n5_Gold_x3"));

julia> π isa SBox{5, UInt8}
true

julia> π.lut[1] == 0  # π_F(0) = 0 by convention
true
```
"""
function ortho_derivative(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    result = zeros(T, n_size)
    ddt_row = Vector{Int}(undef, n_size)

    @inbounds for a = 1:(n_size-1)
        # DDT row at a: count #{x : F(x) ⊕ F(x ⊕ a) = b} for each b.
        fill!(ddt_row, 0)
        for x = 0:(n_size-1)
            d = Int(F.lut[x+1] ⊻ F.lut[(x⊻a)+1])
            ddt_row[d+1] += 1
        end
        row_0 = ddt_row[1]   # DDT(a, 0)

        # Hyperplane {b ≥ 1 : DDT(a, b) ≠ DDT(a, 0)}; APN ⇒ |H| = 2^{n-1}.
        hp_count = 0
        # We store the hyperplane elements in a stack-allocated-like Vector.
        hyperplane = Int[]
        sizehint!(hyperplane, n_size >> 1)
        for b = 1:(n_size-1)
            if ddt_row[b+1] != row_0
                push!(hyperplane, b)
                hp_count += 1
            end
        end
        # APN condition: |H_a| must be exactly 2^{n-1}. If smaller, F isn't APN.
        hp_count == (n_size >> 1) || return nothing

        # Brute-force ortho ∈ [1, 2ⁿ - 1] with ⟨ortho, b⟩ = 1 for all b in H_a.
        found = false
        ortho_val = 0
        for candidate = 1:(n_size-1)
            ok = true
            for b in hyperplane
                if (count_ones(UInt32(candidate) & UInt32(b)) & 1) == 0
                    ok = false
                    break
                end
            end
            if ok
                ortho_val = candidate
                found = true
                break
            end
        end
        found || return nothing
        result[a+1] = T(ortho_val)
    end
    return SBox{N,T}(result)
end

"""
    is_quadratic_apn(F::SBox) -> Bool

Convenience predicate: `true` iff `ortho_derivative(F) !== nothing`.
"""
is_quadratic_apn(F::SBox) = ortho_derivative(F) !== nothing
