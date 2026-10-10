# Implements Example 4.2 + Theorem 4.1 verification
# Paper: Taniguchi et al. (2025), "Changing APN functions on affine subspaces
#        of small codimensions"
# Section: 4 — Modifying APN functions on affine subspaces of codimension two
#
# Pseudocode:
#   1. F(x) = x^3 on GF(2^8), modulus α^8+α^4+α^3+α^2+1
#   2. Decompose GF(2^8) into 4 cosets via Tr_2^8:
#      U_i = {x : Tr_2^8(x) = c_i}, c_i ∈ {0, 1, β, β²}, β = α^85
#   3. Compute exclusion set A = F_{2^8} \ {F(x₁)+F(x₂)+F(x₃)+F(x₄) : ...}
#   4. Verify A = {0, 1, α^85, α^170}
#   5. Build G with a₁=a₂=0, a₃=α^85·β, a₄=α^85·β²
#   6. Verify G is APN
#   7. Verify simplified form: G(x) = x^3 + α^85·Tr(x)·Tr_2^8(x)
# VBF API used: gf_pow, gf_mul, gf_trace, gf_relative_trace, SBox,
#               differential_uniformity, algebraic_degree, apn_ea_mugshot

include(joinpath(@__DIR__, "helpers.jl"))

function example4_2_report(io::IO = stdout)
    n = 8
    mod = PAPER_MODULUS_8
    N = 1 << n
    print_section("Example 4.2: codim-2 APN on GF(2^8)", io)

    # β is root of x²+x+1, i.e. β ∈ GF(4)\GF(2). Paper: β ∈ {α^85, α^170}.
    β = alpha_power(85, n, mod)
    β2 = gf_mul(β, β, n; modulus=mod)
    print_kv(io, "β = α^85", β)
    print_kv(io, "β² = α^170", β2)
    # Verify β²+β+1 = 0
    print_check(io, "β² + β + 1 = 0", (β2 ⊻ β ⊻ 1) == 0)

    # Decompose into 4 cosets via Tr_2^8
    U = [Int[] for _ in 1:4]
    coset_values = [0, 1, β, β2]
    for x in 0:N-1
        tr = gf_relative_trace(x, n, 2; modulus=mod)
        idx = findfirst(==(tr), coset_values)
        idx === nothing && error("Tr_2^8($x) = $tr not in {0,1,β,β²}")
        push!(U[idx], x)
    end
    for i in 1:4
        print_kv(io, "|U_$i| (Tr_2^8 = $(coset_values[i]))", length(U[i]))
    end
    print_check(io, "each coset has 64 elements", all(u -> length(u) == 64, U))

    # F(x) = x^3
    F_lut = [gf_pow(x, 3, n; modulus=mod) for x in 0:N-1]

    # Compute the set of sums F(x₁)+F(x₂)+F(x₃)+F(x₄) where xᵢ ∈ Uᵢ
    # and x₁+x₂+x₃+x₄ = 0 (2-dim affine subspace, one point per coset)
    image_sums = Set{Int}()
    for x1 in U[1], x2 in U[2], x3 in U[3]
        x4 = x1 ⊻ x2 ⊻ x3  # x₄ = x₁+x₂+x₃ (so sum = 0)
        # Check x4 ∈ U4
        tr4 = gf_relative_trace(x4, n, 2; modulus=mod)
        tr4 != β2 && continue
        s = F_lut[x1+1] ⊻ F_lut[x2+1] ⊻ F_lut[x3+1] ⊻ F_lut[x4+1]
        push!(image_sums, s)
    end

    # A = F_{2^8} \ image_sums
    A = Set{Int}(0:N-1)
    setdiff!(A, image_sums)
    A_sorted = sort(collect(A))
    expected_A = sort([0, 1, β, β2])
    print_kv(io, "|A| (exclusion set)", length(A))
    print_check(io, "A = {0, 1, α^85, α^170}", A_sorted == expected_A)

    # Build G: a₁=a₂=0, a₃=α^85·β, a₄=α^85·β²
    α85 = alpha_power(85, n, mod)
    a = [0, 0, gf_mul(α85, β, n; modulus=mod), gf_mul(α85, β2, n; modulus=mod)]
    a_sum = a[1] ⊻ a[2] ⊻ a[3] ⊻ a[4]
    print_kv(io, "a₁+a₂+a₃+a₄", a_sum)
    print_check(io, "a₁+a₂+a₃+a₄ = α^85 ∈ A", a_sum == α85 && a_sum in A)

    G_lut = Vector{Int}(undef, N)
    for x in 0:N-1
        tr = gf_relative_trace(x, n, 2; modulus=mod)
        idx = findfirst(==(tr), coset_values)
        G_lut[x+1] = F_lut[x+1] ⊻ a[idx]
    end

    G = SBox(G_lut)
    du = differential_uniformity(G)
    deg = algebraic_degree(G)
    print_check(io, "G is APN (du=2)", du == 2)
    print_kv(io, "algebraic degree", deg)

    # Verify simplified form: G(x) = x^3 + α^85 · Tr(x) · Tr_2^8(x)
    G_simplified = Vector{Int}(undef, N)
    for x in 0:N-1
        fx = F_lut[x+1]
        tr1 = gf_trace(x, n; modulus=mod)
        tr2 = gf_relative_trace(x, n, 2; modulus=mod)
        product = gf_mul(gf_mul(α85, tr1, n; modulus=mod), tr2, n; modulus=mod)
        G_simplified[x+1] = fx ⊻ product
    end
    print_check(io, "simplified form matches: G(x) = x³ + α^85·Tr(x)·Tr₂⁸(x)",
                G_lut == G_simplified)

    # EA-inequivalence: check mugshots differ from Gold x^3
    F = SBox(F_lut)
    mug_F = apn_ea_mugshot(F)
    mug_G = apn_ea_mugshot(G)
    print_check(io, "G ≠ EA F (different mugshots)", mug_F != mug_G)
    println(io, "  [loaded] Γ-rank(G) = 13842 ≠ Γ-rank(F) = 11818 (paper claim)")

    (; is_apn=(du==2), degree=deg, A_correct=(A_sorted==expected_A),
       simplified_matches=(G_lut==G_simplified), ea_distinct=(mug_F != mug_G))
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    example4_2_report()
end
