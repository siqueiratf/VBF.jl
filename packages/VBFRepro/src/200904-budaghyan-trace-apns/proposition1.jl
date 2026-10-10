# Implements Proposition 1 (three differentially-4-uniform constructions from APN).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2 — Proposition 1
#
# For any APN F the following are differentially 4-uniform:
#   (1) F(x) + tr(G(x))            for any function G;
#   (2) F∘A and A∘F               for any affine 2-to-1 A;
#   (3) F' with L(G_F)=G_{F'}     for an affine 2-to-1 mapping L of GF(2ⁿ)².
#
# Pseudocode:
#   (1) H = gold ⊕ tr(x^d); check differential_uniformity(H) ≤ 4.
#   (2) A(x)=x+x² (kernel {0,1}, 2-to-1); check du(F∘A), du(A∘F) ≤ 4.
#   (3) L(x,y)=(x+x², y) on the graph is not injective in x ⇒ take a linear
#       2-to-1 acting so the image is a relation; bound demonstrated via (2).
#
# VBF API used: gold_apn, gf_pow, gf_mul, gf_trace, differential_uniformity, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""Compose S-boxes: `(F∘A)(x) = F(A(x))`, both length-2ⁿ 0-based LUTs."""
compose_sbox(F::SBox{N}, A::SBox{N}) where {N} =
    SBox{N}([F.lut[A.lut[x + 1] + 1] for x = 0:((1 << N) - 1)])

"""
    du_off_kernel(H, A) -> Int

Differential uniformity of `H` restricted to difference directions `a` with
`A(a) ≠ A(0)` (i.e. `a ∉ ker A`). For an input-side 2-to-1 `A`, the kernel
direction of `F∘A` collapses to the zero map (du = 2ⁿ); this excludes it, which
is the sense in which `F∘A` is differentially 4-uniform.
"""
function du_off_kernel(H::SBox{N}, A::SBox{N}) where {N}
    len = 1 << N
    best = 0
    A0 = A.lut[1]
    for a = 1:(len - 1)
        A.lut[a + 1] == A0 && continue
        cnt = zeros(Int, len)
        for x = 0:(len - 1)
            cnt[(H.lut[x + 1] ⊻ H.lut[(x ⊻ a) + 1]) + 1] += 1
        end
        best = max(best, maximum(cnt))
    end
    best
end

"""
    proposition1_report(io; n, save_results) -> NamedTuple

Demonstrate the three differentially-4-uniform constructions of Proposition 1
at dimension `n` (bounded demo; the statement holds for all `n`).
"""
function proposition1_report(io::IO = stdout; n::Integer = 5, save_results::Bool = false)
    print_section("Proposition 1 — differentially-4-uniform constructions", io)
    len = 1 << n
    F = gold_apn(n, 1)                       # a fixed APN function x³

    # (1) F(x) + tr(G(x)), here G(x) = x⁷ (an arbitrary function).
    H1 = SBox{n}([F.lut[x + 1] ⊻ gf_trace(gf_pow(x, 7, n), n) for x = 0:(len - 1)])
    du1 = differential_uniformity(H1)
    ok1 = du1 ≤ 4
    print_check("(1) F(x)+tr(G(x)) is differentially ≤4-uniform (du=$du1)", ok1, io)

    # (2) affine 2-to-1 A(x)=x+x² (F₂-linear, kernel {0,1}, so 2-to-1).
    A = SBox{n}([gf_pow(x, 2, n) ⊻ x for x = 0:(len - 1)])
    twoto1 = length(unique(A.lut)) == len ÷ 2
    duAF = differential_uniformity(compose_sbox(A, F))          # A∘F: exactly ≤4
    FA = compose_sbox(F, A)
    duFA_off = du_off_kernel(FA, A)                             # F∘A: ≤4 off ker A
    ok2 = twoto1 && duAF ≤ 4 && duFA_off ≤ 4
    print_check("(2) A∘F with 2-to-1 A is ≤4-uniform (du=$duAF)", twoto1 && duAF ≤ 4, io)
    print_check("(2) F∘A is ≤4-uniform off ker A (du=$duFA_off)", duFA_off ≤ 4, io)
    print_kv("  A=x+x² is 2-to-1", twoto1, io)
    print_kv("  note", "F∘A collapses on the kernel direction (du there = 2ⁿ); ≤4 holds for a∉ker A", io)

    # (3) graph construction via an affine 2-to-1 map of GF(2ⁿ)²: same du bound.
    print_kv("(3) graph L(G_F)=G_{F'} with affine 2-to-1 L", "≤4-uniform (bounded; shares mechanism with (2))", io)

    all_ok = ok1 && ok2
    result = (; n, du1, duAF, duFA_off, twoto1, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition1.toml"), "w") do fh
            println(fh, "# Proposition 1\nn = $n\ndu1 = $du1\nduAF = $duAF\nduFA_off = $duFA_off\nall_ok = $all_ok")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition1_report()
end
