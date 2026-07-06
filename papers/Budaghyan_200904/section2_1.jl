# Implements §2.1 (An algorithmic approach) — examples + linear-dependence search.
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2.1 — An algorithmic approach
#
# For a Gold F(x)=x^{2^r+1} and g(x)=Σ_i α_i x^{2^i+1}, Theorem 1 gives F+g APN
# iff  Σ_i tr(T_i^r(a, α_i)) = 0  whenever tr(a^{-(2^r+1)})=0, where
#   T_i^r(a, α) = Σ_{j=0}^{t} α^{2^{-jr}} a^{2^{i-jr}+2^{-jr}-(2^r+1)},  t=(i r^{-1}-1) mod n.
# Writing α_i in a basis (b_j) turns this into: find the F₂-kernel of the matrix
# W with columns w_{ij}=(tr(T_i^r(a,b_j)))_{a: tr(a^{-3})=0}. Every kernel vector
# yields a g with F+g APN. The paper's search to dimension 15 found only
#   x³+tr(x⁹) (all n),  x⁵+tr(x³) (n=5),  x⁹+tr(x³) (n=8).
#
# Pseudocode:
#   examples:  build the two listed functions; check APN + (n=5) CCZ-equiv Gold,
#              (n=8) CCZ-inequiv to power maps and to x³+tr(x⁹) via ortho-sig.
#   search (opt-in): build W, kernel_f2(W), verify each basis g gives F+g APN.
#
# VBF API used: gold_apn, gf_pow, gf_inv, gf_mul, gf_trace, kernel_f2,
#               differential_uniformity, are_ccz_equivalent, SBox

include(joinpath(@__DIR__, "helpers.jl"))

# ── §2.1 listed examples ─────────────────────────────────────────────────────

"""
    section2_1_examples(io; save_results) -> NamedTuple

The two examples besides x³+tr(x⁹): x⁵+tr(x³) (n=5, CCZ-equiv Gold) and
x⁹+tr(x³) (n=8, CCZ-inequiv to power maps and to x³+tr(x⁹)).
"""
function section2_1_examples(io::IO = stdout; save_results::Bool = false)
    print_section("§2.1 examples — x⁵+tr(x³) (n=5) and x⁹+tr(x³) (n=8)", io)

    # (1) n=5: x⁵+tr(x³), APN, CCZ-equivalent to a Gold function.
    F5 = gold_plus_trace(5, 5, 3)
    du5 = differential_uniformity(F5)
    ccz5 = du5 == 2 && are_ccz_equivalent(F5, gold_apn(5, 1))
    print_check("n=5: x⁵+tr(x³) APN (du=$du5) & CCZ-equivalent to Gold", du5 == 2 && ccz5, io)

    # (2) n=8: x⁹+tr(x³), APN, CCZ-inequiv to x³+tr(x⁹) and to Gold power maps.
    F8 = gold_plus_trace(8, 9, 3)
    du8 = differential_uniformity(F8)
    sig_F8 = ortho_signature(F8)
    sig_x3tr9 = ortho_signature(apn_x3_tr_x9(8))
    sig_g1 = ortho_signature(gold_apn(8, 1))
    sig_g3 = ortho_signature(gold_apn(8, 3))
    # distinct CCZ-invariant ortho-derivative signatures ⇒ CCZ-inequivalent.
    inequiv = sig_F8 != sig_x3tr9 && sig_F8 != sig_g1 && sig_F8 != sig_g3
    print_check("n=8: x⁹+tr(x³) APN (du=$du8)", du8 == 2, io)
    print_check("n=8: CCZ-inequiv to x³+tr(x⁹) and to Gold power maps (ortho-sig)", inequiv, io)
    print_kv("  ortho-sig x⁹+tr(x³)", sig_F8, io)
    print_kv("  ortho-sig x³+tr(x⁹)", sig_x3tr9, io)
    print_kv("catalog-gap candidate", "n=8 x⁹+tr(x³) — NOT written to catalog (separate agent)", io)

    all_ok = (du5 == 2 && ccz5) && du8 == 2 && inequiv
    result = (; du5, ccz5, du8, inequiv, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "section2_1_examples.toml"), "w") do fh
            println(fh, "# §2.1 examples\nccz5 = $ccz5\ndu8 = $du8\ninequiv8 = $inequiv\nall_ok = $all_ok")
        end
    end
    return result
end

# ── §2.1 linear-dependence search (opt-in) ───────────────────────────────────

"""T_i^r(a, α) over GF(2ⁿ), exponents reduced mod (2ⁿ−1) / n (Frobenius)."""
function _Tir(a::Int, α::Int, i::Int, r::Int, n::Int, M::Int)
    period = (1 << n) - 1
    rinv = invmod(r, n)
    t = mod(i * rinv - 1, n)
    base = (1 << r) + 1
    acc = 0
    for j = 0:t
        e1 = mod(i - j * r, n)
        e2 = mod(-j * r, n)
        E = mod((1 << e1) + (1 << e2) - base, period)          # a-exponent
        αe = gf_pow(α, 1 << e2, n; modulus = M)                # α^{2^{-jr}}
        acc ⊻= gf_mul(αe, gf_pow(a, E, n; modulus = M), n; modulus = M)
    end
    acc
end

"""
    g_in_kernel(n, r, i, j) -> Bool

Theorem-1 membership test for the single-term perturbation `g(x) = b_j·x^{2^i+1}`
(with `b_j = 2ʲ`) added to the Gold `F(x) = x^{2^r+1}`: `true` iff
`tr(T_i^r(a, b_j)) = 0` for every `a` with `tr(a^{-(2^r+1)}) = 0`. By Theorem 1
this holds **iff** `F + g` is APN, so it is the algebraic oracle behind the
dependence search (each kernel vector is a superposition of such members).
"""
function g_in_kernel(n::Integer, r::Integer, i::Integer, j::Integer)
    nn = Int(n); M = primitive_polynomial(nn); base = (1 << r) + 1
    b = 1 << j
    for a = 1:((1 << nn) - 1)
        gf_trace(gf_inv(gf_pow(a, base, nn; modulus = M), nn; modulus = M), nn; modulus = M) == 0 ||
            continue
        gf_trace(_Tir(a, b, i, r, nn, M), nn; modulus = M) == 0 || return false
    end
    true
end

"""
    dependence_search(io; n, r, save_results) -> NamedTuple

Build W = (tr(T_i^r(a,b_j)))_{a: tr(a^{-3})=0} over the standard basis b_j=2ʲ,
compute its F₂-kernel, and verify that every kernel basis vector g gives F+g APN
(Gold F=x^{2^r+1}). OPT-IN / bounded: this reproduces the paper's search engine
but at a single n (default n=5), not the full dim-15 sweep.
"""
function dependence_search(io::IO = stdout; n::Integer = 5, r::Integer = 1, save_results::Bool = false)
    print_section("§2.1 linear-dependence search (opt-in, n=$n, r=$r)", io)
    nn = Int(n); M = primitive_polynomial(nn); base = (1 << r) + 1
    # A = {a≠0 : tr(a^{-(2^r+1)})=0}
    A = [a for a = 1:((1 << nn) - 1) if gf_trace(gf_inv(gf_pow(a, base, nn; modulus = M), nn; modulus = M), nn; modulus = M) == 0]
    bj = [1 << j for j = 0:(nn - 1)]          # standard basis
    cols = [(i, j) for i = 0:(nn - 1) for j = 0:(nn - 1)]
    ncol = length(cols)
    ncol ≤ 64 || throw(ArgumentError("dependence_search: n=$nn gives $ncol columns > 64; use n ≤ 8"))
    # Each a∈A gives one F₂ constraint row Σ c_{ij} tr(T_i^r(a,b_j)) = 0, packed as
    # a bitmask over the `ncol` coefficient columns. kernel_f2 returns the valid
    # coefficient vectors (each a nonzero (c_{ij}) ⇒ a g with F+g APN).
    rows = UInt64[]
    for a in A
        mask = UInt64(0)
        for (ci, (i, j)) in enumerate(cols)
            gf_trace(_Tir(a, bj[j + 1], i, r, nn, M), nn; modulus = M) == 1 && (mask |= UInt64(1) << (ci - 1))
        end
        push!(rows, mask)
    end
    ker = kernel_f2(rows; nbits = ncol)       # basis of valid coefficient vectors
    kdim = length(ker)
    print_kv("|A| (tr(a^{-3})=0)", length(A), io)
    print_kv("W size", "$(length(A))×$ncol", io)
    print_kv("kernel dimension", kdim, io)

    # Verify a few kernel vectors: reconstruct g(x)=Σ c_{ij} b_j x^{2^i+1}, check F+g APN.
    F = gold_apn(nn, r)
    verified = 0
    checks = kdim                              # exhaustive over the kernel basis
    for k = 1:checks
        v = ker[k]
        glut = zeros(Int, 1 << nn)
        for (ci, (i, j)) in enumerate(cols)
            (v >> (ci - 1)) & UInt64(1) == UInt64(1) || continue
            b = bj[j + 1]; e = (1 << i) + 1
            for x = 0:((1 << nn) - 1)
                glut[x + 1] ⊻= gf_trace(gf_mul(b, gf_pow(x, e, nn; modulus = M), nn; modulus = M), nn; modulus = M)
            end
        end
        Fg = SBox{nn}([F.lut[x + 1] ⊻ glut[x + 1] for x = 0:((1 << nn) - 1)])
        differential_uniformity(Fg) == 2 && (verified += 1)
    end
    print_check("all $checks kernel basis vectors give F+g APN (exhaustive over basis)", verified == checks, io)

    result = (; n = nn, r, num_A = length(A), kdim, checks, verified)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "section2_1_search.toml"), "w") do fh
            println(fh, "# §2.1 dependence search\nn = $nn\nr = $r\nkernel_dim = $kdim\nverified = $verified\nchecked = $checks")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section2_1_examples()
end
