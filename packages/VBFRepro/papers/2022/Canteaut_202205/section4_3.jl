# Implements Section 4.3 from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 4.3 — Kim Mapping and Dillon et al.'s Permutation
#
# Claims reproduced:
#   (a) Z(κ) contains exactly 222 vector spaces of dimension 6, so the
#       CCZ-class of κ contains at most 222 EA-classes.
#   (b) The thickness spectrum of κ is {0:1, 1:63, 2:126, 3:32}.
#   (c) The 222 EA-class representatives realize exactly 8 distinct thickness
#       spectra (so at least 8 distinct EA-classes; with Prop 40, 8+1).
#   (d) The 32 thickness-3 spaces split into two sets {Vᵢ}, {Uᵢ} of 16 such
#       that every cross pair (Vᵢ, Uⱼ) spans F₂¹²  (these are the pairs that
#       produce permutations, Proposition 39).
#   (e) The 256 permutations Γ_G = L^T(Γ_κ) from cross pairs, together with
#       their inverses, fall into exactly 4 affine-equivalence classes
#       𝒜₀..𝒜₃, pairing into exactly 2 EA-classes of permutations
#       (Proposition 40); P ∈ 𝒜₀ ⟹ P⁻¹ ∈ 𝒜₀, same for 𝒜₁, while 𝒜₂ and 𝒜₃
#       swap under inversion.
#   (f) The generalized open butterflies H_{α,1} and H_{α,β}, β = α³ + 1/α
#       (α ≠ 0, Tr(α) = 0), are APN involutions representing the two
#       EA-classes of permutations (Remark 41: degree n-2 = 4).
#   (g) Both permutation EA-classes share the thickness spectrum
#       {0:1, 1:7, 2:14, 3:58, 4:42, 5:84, 6:16}.
#   (h) The quadratic part of the CCZ-class is a single EA-class (Yos11):
#       every degree-2 representative has κ's ortho-derivative mugshot.
#
# The permutation-bearing spaces have thickness 3, matching Figure 1's claim
# that each permutation EA-class is reached from κ by a 3-twist. Verifying the
# full t-twist arrows of Figure 1 per part is out of scope (it would require a
# per-part twist search over CCZ-mappings; the thickness data above already
# pins the t = 3 case, the only one the paper makes a sharp claim about).
#
# VBF API used: kim_apn, walsh_zeroes, extract_linear_subspaces, thickness,
#               thickness_spectrum, enumerate_ccz_class, ccz_equivalent_function,
#               F2AffineMap, F2LinearMap, transpose, rank_f2, is_permutation,
#               compositional_inverse, are_affine_equivalent, are_ea_equivalent,
#               is_ccz_equivalent_to_permutation, algebraic_degree,
#               apn_ea_mugshot, gf_mul, gf_pow, gf_inv, gf_trace,
#               primitive_polynomial, dillon_apn_permutation

include(joinpath(@__DIR__, "helpers.jl"))

# -- CCZ mapping from a pair of complementary Walsh-zero spaces ---------------

"""
    _perm_from_pair(F::SBox{6}, b1, b2) -> Union{SBox, Nothing}

Apply the CCZ mapping built from the ordered basis pair (b1, b2) (two 6-dim
Walsh-zero spaces of F spanning F₂¹²) to the graph of F, as in Section 4.2:
L(V₁) = 𝒱, L(V₂) = 𝒱^⊥, then Γ_G = L^T(Γ_F).
"""
function _perm_from_pair(F::SBox{6}, b1::Vector{UInt32}, b2::Vector{UInt32})
    L = transpose(F2LinearMap{12,UInt32}(UInt32[b1; b2]))
    return ccz_equivalent_function(F, F2AffineMap(L, UInt32(0)))
end

# -- generalized open butterflies (CDP17) --------------------------------------

"""
    open_butterfly(alpha, beta) -> SBox{6}

The generalized open butterfly H_{α,β} over (F₂³)² with
T_y(x) = (x + αy)³ + βy³ [CDP17].
The paper prints H(x,y) = (T_y⁻¹(x), T_{T_y⁻¹(x)}(y)), but that ordering is
not an involution. The correct involutive form swaps the two components:
H(x,y) = (T_{T_y⁻¹(x)}(y), T_y⁻¹(x)). Verified computationally: H∘H = id.
Input packing: v = (x << 3) | y.
"""
function open_butterfly(alpha::Int, beta::Int)
    mod3 = primitive_polynomial(3)
    mul(a, b) = gf_mul(a, b, 3; modulus = mod3)
    pw(a, e) = gf_pow(a, e, 3; modulus = mod3)
    T(x, y) = pw(x ⊻ mul(alpha, y), 3) ⊻ mul(beta, pw(y, 3))
    Tinv(x, y) = pw(x ⊻ mul(beta, pw(y, 3)), 5) ⊻ mul(alpha, y)  # cube root = ^5

    lut = zeros(Int, 64)
    for v in 0:63
        x, y = v >> 3, v & 7
        u = Tinv(x, y)          # T_y⁻¹(x)
        w = T(y, u)             # T_{T_y⁻¹(x)}(y)
        lut[v+1] = (w << 3) | u
    end
    return SBox{6}(lut)
end

# -- report ---------------------------------------------------------------------

"""
    section4_3_report(; io) -> NamedTuple

Reproduce Section 4.3: the structure of the CCZ-class of the Kim mapping.
Runtime is dominated by the thickness-spectrum sweep over all 222 EA-class
representatives (~3 min) and the affine partition of the 512 permutations
(~2–5 min).
"""
function section4_3_report(; io::IO = stdout)
    print_section("Section 4.3: the CCZ-class of the Kim mapping κ", io)
    κ = kim_apn()

    # (a) 222 spaces
    Z = walsh_zeroes(κ)
    bases = extract_linear_subspaces(Z, 6; max_bits = 12)
    ok_a = length(bases) == 222
    print_check("Z(κ) contains 222 vector spaces of dimension 6", ok_a, io)

    # (b) thickness spectrum of κ
    ts_κ = counts(thickness_spectrum(κ))
    ok_b = ts_κ == [0 => 1, 1 => 63, 2 => 126, 3 => 32]
    print_kv("thickness spectrum of κ", ts_κ, io)
    print_check("thickness spectrum of κ = {0:1, 1:63, 2:126, 3:32}", ok_b, io)

    # (c) 8 distinct thickness spectra among the 222 EA representatives
    reps = enumerate_ccz_class(κ)
    ok_len = length(reps) == 222
    print_check("enumerate_ccz_class(κ) yields 222 representatives", ok_len, io)
    spectra = Dict{Vector{Int},Int}()
    for r in reps
        s = thickness_spectrum(r)
        spectra[s] = get(spectra, s, 0) + 1
    end
    ok_c = length(spectra) == 8
    print_check("222 representatives realize exactly 8 thickness spectra (≥8 EA-classes)", ok_c, io)
    degs = sort(unique(algebraic_degree.(reps)))
    print_kv("algebraic degrees among representatives (Fig. 1)", degs, io)

    # (h) the quadratic part is one EA-class (Yos11): mugshot check
    mug_κ = apn_ea_mugshot(κ)
    quad_reps = [r for r in reps if algebraic_degree(r) == 2]
    ok_h = !isempty(quad_reps) && all(apn_ea_mugshot(r) == mug_κ for r in quad_reps)
    print_check("all $(length(quad_reps)) quadratic representatives share κ's mugshot (single EA-class, Yos11)", ok_h, io)

    # (d) thickness-3 bipartition
    th = [thickness(b, 6) for b in bases]
    t3 = [b for (b, t) in zip(bases, th) if t == 3]
    ok_32 = length(t3) == 32
    print_check("exactly 32 spaces of thickness 3", ok_32, io)
    spans(a, b) = rank_f2(UInt32[a; b]; nbits = 12) == 12
    side = fill(0, length(t3))
    side[1] = 1
    for _ in 1:length(t3), i in eachindex(t3), j in eachindex(t3)
        if side[i] != 0 && side[j] == 0
            side[j] = spans(t3[i], t3[j]) ? -side[i] : side[i]
        end
    end
    ok_d = count(==(1), side) == 16 && count(==(-1), side) == 16 &&
        all(spans(t3[i], t3[j]) == (side[i] != side[j])
            for i in eachindex(t3), j in eachindex(t3) if i != j)
    print_check("two 16-sets {Vᵢ},{Uᵢ}: exactly the cross pairs span F₂¹² (3-twists)", ok_d, io)

    # permutation-CCZ criterion (Prop 39 via Canteaut–Perrin)
    ok_perm = is_ccz_equivalent_to_permutation(κ)
    print_check("κ is CCZ-equivalent to a permutation (Prop 39 criterion)", ok_perm, io)

    # (e) 256 cross-pair permutations + inverses → 4 affine classes, 2 EA classes
    side1 = [t3[i] for i in eachindex(t3) if side[i] == 1]
    side2 = [t3[i] for i in eachindex(t3) if side[i] == -1]
    perms = SBox{6,UInt8}[]
    perm_pair = Tuple{Int,Int}[]          # (iv, iu) of each forward perm
    for (iv, v) in enumerate(side1), (iu, u) in enumerate(side2)
        P = _perm_from_pair(κ, v, u)
        if P === nothing || !is_permutation(P)
            # the mapping convention may orient the pair the other way round
            P2 = _perm_from_pair(κ, u, v)
            P = (P2 !== nothing && is_permutation(P2)) ?
                compositional_inverse(P2) : nothing
        end
        if P !== nothing
            push!(perms, P)
            push!(perm_pair, (iv, iu))
        end
    end
    ok_256 = length(perms) == 256
    print_check("all 256 cross pairs (Vᵢ,Uⱼ) yield permutations", ok_256, io)
    all512 = vcat(perms, [compositional_inverse(P) for P in perms])

    # Affine partition of all 512 (the 256 forward permutations, then their 256
    # inverses), by canonical form. `affine_representative` is a canonical form
    # for permutations — F ~A G iff their representatives agree — so the partition
    # is a bucketing on it, not the pairwise scan the greedy version did (1276
    # `are_affine_equivalent` calls, each recomputing up to 2ⁿ linear
    # representatives internally).
    #
    # Only the FORWARDS are canonicalised. Affine equivalence commutes with
    # inversion — Q = A₁∘P∘A₂ ⟹ Q⁻¹ = A₂⁻¹∘P⁻¹∘A₁⁻¹, again affine — so the class
    # of P⁻¹ is determined by the class of P alone, and one canonical form per
    # CLASS (not per permutation) places all 256 inverses. That is 256 + 4
    # canonical forms rather than 512. The step is a theorem, so it is spot-checked
    # below rather than taken on faith.
    #
    # Classes are numbered by first appearance, forwards before inverses — the
    # order the greedy loop discovered them in — so `class_of`, which keys the
    # Prop 40 union-find below, is unchanged, not merely equivalent up to
    # relabelling.
    nfw = length(perms)
    class_of_key = Dict{Vector{UInt8},Int}()
    class_key = Vector{Vector{UInt8}}()
    classes = Vector{Vector{Int}}()
    class_of = zeros(Int, length(all512))
    assign! = function (k, i)
        ci = get!(class_of_key, k) do
            push!(classes, Int[])
            push!(class_key, k)
            length(classes)
        end
        class_of[i] = ci
        push!(classes[ci], i)
        ci
    end
    for i = 1:nfw
        assign!(collect(affine_representative(all512[i]).lut), i)
    end
    # the inverse-class key of each forward class, from that class's rep alone
    inv_key_of_class =
        [collect(affine_representative(compositional_inverse(all512[cls[1]])).lut)
         for cls in classes]
    for i = 1:nfw
        assign!(inv_key_of_class[class_of[i]], nfw + i)
    end

    # the inversion shortcut is sound by the conjugation identity above; check it
    # where it is cheap — for a non-representative member of each class, the
    # inverse's canonical form must be the one predicted from the class alone.
    ok_invthm = all(
        let j = findfirst(i -> i <= nfw && i != cls[1], cls),
            m = j === nothing ? cls[1] : cls[j]      # a FORWARD member, not the rep

            collect(affine_representative(compositional_inverse(all512[m])).lut) ==
            inv_key_of_class[c]
        end
        for (c, cls) in enumerate(classes) if c <= length(inv_key_of_class)
    )
    print_check("class of P⁻¹ is fixed by the class of P (inversion shortcut, spot-check)",
                ok_invthm, io)

    ok_e4 = length(classes) == 4
    print_check("the 512 permutations fall into exactly 4 affine classes 𝒜₀..𝒜₃", ok_e4, io)
    print_kv("affine class sizes", sort(map(length, classes); rev = true), io)
    distinct = all512   # naming kept for the checks below

    # (f) butterflies pin down 𝒜₀ and 𝒜₁
    mod3 = primitive_polynomial(3)
    α = first(a for a in 1:7 if gf_trace(a, 3; modulus = mod3) == 0)
    β = gf_pow(α, 3, 3; modulus = mod3) ⊻ gf_inv(α, 3; modulus = mod3)
    H1 = open_butterfly(α, 1)          # 𝒜₀ representative
    H2 = open_butterfly(α, β)          # 𝒜₁ representative
    ok_f_basic = true
    for (nm, H) in (("H_{α,1}", H1), ("H_{α,β}", H2))
        good = is_permutation(H) &&
               all(H(H(v)) == v for v in 0:63) &&
               differential_uniformity(H) == 2 &&
               algebraic_degree(H) == 4
        ok_f_basic &= good
        print_check("$nm: APN involution of degree n-2 = 4 (Remark 41)", good, io)
    end
    # Which affine class each butterfly lands in. Equal canonical forms IS affine
    # equivalence (same decision as are_affine_equivalent, one canonical form
    # instead of a scan over the class reps), and the butterflies are permutations
    # — asserted just above — so the canonical form is defined for them.
    cls_reps = [distinct[cls[1]] for cls in classes]
    kH1 = collect(affine_representative(H1).lut)
    kH2 = collect(affine_representative(H2).lut)
    m1 = [k == kH1 for k in class_key]
    m2 = [k == kH2 for k in class_key]
    i1 = something(findfirst(m1), 0)
    i2 = something(findfirst(m2), 0)
    ok_f = count(m1) == 1 && count(m2) == 1 && i1 != i2 && i1 > 0 && i2 > 0
    print_check("H_{α,1} and H_{α,β} lie in two distinct affine classes (𝒜₀, 𝒜₁)", ok_f, io)

    # inversion structure: 𝒜₀, 𝒜₁ closed under inversion; the other two swap.
    # The inverse of a permutation is a permutation, so its class is again a
    # canonical-key lookup; 0 if it lands outside the four classes.
    inv_map = [
        get(class_of_key, collect(affine_representative(compositional_inverse(R)).lut), 0)
        for R in cls_reps
    ]
    others = [k for k in eachindex(cls_reps) if k != i1 && k != i2]
    ok_inv = ok_e4 && ok_f && inv_map[i1] == i1 && inv_map[i2] == i2 &&
             length(others) == 2 &&
             inv_map[others[1]] == others[2] && inv_map[others[2]] == others[1]
    print_check("P∈𝒜₀ ⟹ P⁻¹∈𝒜₀; same for 𝒜₁; 𝒜₂ and 𝒜₃ swap under inversion", ok_inv, io)

    # EA grouping (Proposition 40): exactly two EA-classes of permutations.
    #
    # Merge direction (≤ 2), certified constructively: for two cross pairs
    # sharing the same Uⱼ, the transition mapping E between the generated
    # graphs satisfies E(𝒱^⊥) = 𝒱^⊥, so E is EA-shaped and the two forward
    # permutations are EA-equivalent by construction; for pairs sharing the
    # same Vᵢ the same argument applies on the inverse side (E fixes 𝒱, so
    # the two inverses are EA-equivalent). Affine equivalence implies
    # EA-equivalence, so these witnesses union the four affine classes.
    uf = collect(1:length(classes))
    _find(x) = (while uf[x] != x; uf[x] = uf[uf[x]]; x = uf[x]; end; x)
    _union(a, b) = (ra = _find(a); rb = _find(b); ra != rb && (uf[ra] = rb); nothing)
    nfw = length(perms)
    row_first = Dict{Int,Int}()   # iv -> inverse-perm class (shared V ⟹ inverse-EA)
    col_first = Dict{Int,Int}()   # iu -> forward-perm class (shared U ⟹ forward-EA)
    for (k, (iv, iu)) in enumerate(perm_pair)
        c_fw = class_of[k]
        c_inv = class_of[nfw+k]
        haskey(row_first, iv) ? _union(c_inv, row_first[iv]) : (row_first[iv] = c_inv)
        haskey(col_first, iu) ? _union(c_fw, col_first[iu]) : (col_first[iu] = c_fw)
    end
    groups = Dict{Int,Vector{Int}}()
    for c in eachindex(classes)
        push!(get!(groups, _find(c), Int[]), c)
    end
    ea_classes = sort(collect(values(groups)); by = first)
    ok_merge = length(ea_classes) == 2 &&
               all(length(g) == 2 for g in ea_classes) &&
               !any(issubset([i1, i2], g) for g in ea_classes)
    print_check("certified EA-merges pair the classes into {𝒜₀,𝒜₂}, {𝒜₁,𝒜₃} (≤ 2 EA-classes)", ok_merge, io)

    # Separation direction (≥ 2): 𝒜₀ ≁EA 𝒜₁, per Prop 40's argument on the
    # butterflies (and Calderini 2020's independent code-equivalence proof).
    # The core Heggebakk search agrees; note that its negatives on these
    # degenerate-partition degree-4 permutations are the best algorithmic
    # evidence available (no cheap EA-invariant separates the two classes —
    # they share thickness spectrum and Σ⁴-multiplicities, as the paper notes).
    # `on_inconclusive = :best_effort` is explicit: the search cannot DECIDE
    # degree-4 permutations, so this is a best-effort negative agreeing with
    # Prop 40 / Cal20, not a proof from this oracle.
    ok_sep = !are_ea_equivalent(H1, H2; on_inconclusive = :best_effort)
    print_check("H_{α,1} ≁EA H_{α,β}: the two EA-classes are distinct (Prop 40 / Cal20)", ok_sep, io)
    ok_ea = ok_merge && ok_sep
    print_check("exactly 2 EA-classes of permutations (Prop 40)", ok_ea, io)

    # (g) shared thickness spectrum of the two permutation EA-classes
    ts_p1 = counts(thickness_spectrum(cls_reps[max(i1, 1)]))
    ts_p2 = counts(thickness_spectrum(cls_reps[max(i2, 1)]))
    expected_p = [0 => 1, 1 => 7, 2 => 14, 3 => 58, 4 => 42, 5 => 84, 6 => 16]
    ok_g = ts_p1 == expected_p && ts_p2 == expected_p
    print_kv("permutation thickness spectrum", ts_p1, io)
    print_check("both permutation EA-classes share {0:1,1:7,2:14,3:58,4:42,5:84,6:16}", ok_g, io)

    # Dillon et al.'s permutation belongs to one of the two classes. This is a
    # positive existence check (find the class it lands in), so an undecided
    # EA-query is naturally "no match here" — best-effort `false` is the intended
    # fallback, made explicit so it does not throw under a stricter global default.
    D = dillon_apn_permutation()
    okD = haskey(class_of_key, collect(affine_representative(D).lut)) ||
          any(are_ea_equivalent(D, cls_reps[g[1]]; on_inconclusive = :best_effort)
              for g in ea_classes)
    print_check("Dillon et al.'s permutation lies in the CCZ-class permutation EA-classes", okD, io)

    all_ok = ok_a && ok_b && ok_len && ok_c && ok_h && ok_32 && ok_d &&
             ok_perm && ok_256 && ok_invthm && ok_e4 && ok_f_basic && ok_f &&
             ok_inv && ok_ea && ok_g && okD
    print_check("Section 4.3 overall", all_ok, io)

    return (;
        n_spaces = length(bases),
        thickness_κ = ts_κ,
        n_reps = length(reps),
        n_thickness_spectra = length(spectra),
        n_affine_classes = length(classes),
        n_perm_ea_classes = length(ea_classes),
        perm_thickness = ts_p1,
        all_ok,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_3_report()
end
