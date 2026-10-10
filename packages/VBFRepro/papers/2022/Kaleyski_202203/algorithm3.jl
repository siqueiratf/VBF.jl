# Implements Algorithm 3 from Section 4.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: 4 — Guessing the inner permutation, Algorithm 3
#
# Algorithm 3: Find invertible linear A2 such that F ∘ A2 ⊕ currentG is affine.
#   Given F and currentG = L1⁻¹ ∘ G:
#   (1) Domain reduction:
#     For each basis element bᵢ = 2ⁱ, compute the 3-derivative trail of currentG at bᵢ:
#       Tᵢ = { currentG(bᵢ) ⊕ currentG(y) ⊕ currentG(bᵢ ⊕ y) : y ∈ F₂ⁿ }.
#     Intersect {x : F(x)⊕F(y)⊕F(x⊕y) ∈ Tᵢ for some y} to get domain D(bᵢ).
#   (2) DFS over basis images A2(bᵢ) ∈ D(bᵢ), check if F∘A2⊕currentG is affine.
#
# Pseudocode:
#   result = inner_permutation(F, currentG)
#   result.A2 = recovered A2 LUT
#   result.A_drift = (F ∘ A2 ⊕ currentG).lut (affine drift)
# VBF API used: SBox, F2LinearMap, inner_permutation, are_ea_equivalent

include(joinpath(@__DIR__, "helpers.jl"))


"""
    algorithm3_recovery_demo(; io, n) -> NamedTuple

Demonstrate Algorithm 3: recover A2 from a known EA-equivalent pair.
F = Gold x^3 (n), currentG = F(A2(·)) for a specific linear bijection A2.
"""
function algorithm3_recovery_demo(; io::IO = stdout, n::Int = 5)
    F = gold_x3(n)
    sz = 1 << n
    N = n

    # Construct a specific invertible linear map A2:
    # A2(x) = x with bits 0 and 1 swapped (a specific linear bijection).
    function _swap_bits01(x)
        b0 = (x >> 0) & 1
        b1 = (x >> 1) & 1
        rest = x & ~3
        rest | (b1 << 0) | (b0 << 1)
    end
    A2_lut = UInt8[_swap_bits01(x) for x = 0:(sz - 1)]
    # Verify A2 is a bijection
    @assert length(unique(A2_lut)) == sz "A2 is not a bijection"

    # Build currentG = F ∘ A2 (no outer permutation, no drift)
    currentG_lut = UInt8[F.lut[A2_lut[x + 1] + 1] for x = 0:(sz - 1)]
    currentG = SBox{N,UInt8}(currentG_lut)

    print_section("Algorithm 3 — Inner permutation recovery (n=$n)", io)
    print_kv("F", "Gold x^3 over F_2^$n", io)
    print_kv("A2", "swap bits 0 and 1", io)
    print_kv("currentG", "F(A2(x)) — EA-equivalent to F", io)

    result = inner_permutation(F, currentG)

    recovered_ok = (result !== nothing && result.A2 == A2_lut)
    no_drift_ok = (result !== nothing && all(d == 0x00 for d in result.A_drift))
    print_check("inner_permutation recovers A2", recovered_ok, io)
    print_check("Drift is zero (no affine drift applied)", no_drift_ok, io)

    if result !== nothing
        # Verify: F(A2(x)) ⊕ drift(x) = currentG(x) for all x
        verify_ok = all(
            xor(F.lut[result.A2[x + 1] + 1], result.A_drift[x + 1]) ==
            currentG_lut[x + 1] for x = 0:(sz - 1)
        )
        print_check("F∘A2 ⊕ drift == currentG (certificate validity)", verify_ok, io)
    end

    return (;
        recovered_ok,
        no_drift_ok,
        n,
        A2_is_nontrivial = (A2_lut != UInt8.(0:(sz - 1))),
    )
end

"""
    algorithm3_report(; io) -> NamedTuple
"""
function algorithm3_report(; io::IO = stdout)
    print_section("Algorithm 3 — Inner Permutation (Section 4)", io)
    r5 = algorithm3_recovery_demo(; io, n = 5)
    return r5
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    algorithm3_report()
end
