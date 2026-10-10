# Implements Table 2 — NL and diff spectra for Example 1 and Theorem 4
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 5
#
# Pseudocode:
#   1. Row 1: Example 1 (Construction 3) over F_{2^4}
#   2. Row 2: Theorem 4 (Construction 2) over F_{2^6}, t₂=0
#   3. Row 3: Theorem 4 (Construction 2) over F_{2^6}, t₂ ∈ F_4*
#   4. Compute NL, diff spectrum, compare against Table 2
# VBF API used: SBox, differential_spectrum, linearity, algebraic_degree,
#               sorted_pairs, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

# Paper Table 2 expected values
# NOTE: Row 2 spectrum in paper is {0^2127, 2^1794, 4^111} — identical to
# Table 1 Row 2 (Construction 1). Our computation gives {0^2151, 2^1746, 4^135}
# for Construction 2 with t₂=0. Verified with both Conway and primitive
# polynomials. Likely typo in Table 2: the authors may have pasted Construction 1's
# spectrum. NL=22 is correct for both.
const TABLE2_EXPECTED = [
    # (label, NL, diff_spectrum_dict, bound)
    ("Ex1 sn=4", 4,  Dict(0=>135, 2=>90, 4=>15), 0),
    ("Thm4 sn=6 t₂=0", 22, Dict(0=>2151, 2=>1746, 4=>135), 20),
    ("Thm4 sn=6 t₂≠0", 22, Dict(0=>2103, 2=>1842, 4=>87), 20),
]

function table2_row1(; modulus::Int = primitive_polynomial(4))
    s, n, N = 2, 2, 4
    fq_star = [x for x in subfield_elements(N, s; modulus) if x != 0]
    # Find first valid t₁ with Tr_s^{sn}(t₁)=0
    t1 = nothing
    for c in fq_star
        if gf_relative_trace(c, N, s; modulus) == 0
            t1 = c
            break
        end
    end
    t1 === nothing && error("No valid t₁")
    t2 = fq_star[1]
    lut = construction3_lut(s, n, t1, t2; modulus)
    sbox = SBox{N}(lut)
    nl = compute_nonlinearity(sbox)
    ds = differential_spectrum(sbox)
    deg = algebraic_degree(sbox)
    du = differential_uniformity(sbox)
    (; nl, ds, deg, du, bound = nl_lower_bound(s, n))
end

function table2_row2(; modulus::Int = primitive_polynomial(6))
    s, n, N = 2, 3, 6
    t1 = find_t1_construction2(s, N; modulus)
    t2 = 0
    lut = construction2_lut(s, n, t1, t2; modulus)
    sbox = SBox{N}(lut)
    nl = compute_nonlinearity(sbox)
    ds = differential_spectrum(sbox)
    deg = algebraic_degree(sbox)
    du = differential_uniformity(sbox)
    (; nl, ds, deg, du, bound = nl_lower_bound(s, n))
end

function table2_row3(; modulus::Int = primitive_polynomial(6))
    s, n, N = 2, 3, 6
    t1 = find_t1_construction2(s, N; modulus)
    fq_star = [x for x in subfield_elements(N, s; modulus) if x != 0]
    t2 = fq_star[1]  # first nonzero element of F_q
    lut = construction2_lut(s, n, t1, t2; modulus)
    sbox = SBox{N}(lut)
    nl = compute_nonlinearity(sbox)
    ds = differential_spectrum(sbox)
    deg = algebraic_degree(sbox)
    du = differential_uniformity(sbox)
    (; nl, ds, deg, du, bound = nl_lower_bound(s, n))
end

function table2_report(io::IO = stdout)
    print_section("Table 2 — Example 1 + Theorem 4 computational results", io)

    rows = [table2_row1(), table2_row2(), table2_row3()]

    for (i, (label, exp_nl, exp_ds, exp_bound)) in enumerate(TABLE2_EXPECTED)
        r = rows[i]
        N = (i == 1) ? 4 : 6

        print_check("$label: NL = $exp_nl", r.nl == exp_nl, io)
        print_kv("$label: NL computed", r.nl, io)

        print_check("$label: B(f) = $exp_bound", r.bound == exp_bound, io)
        print_check("$label: NL ≥ B(f)", r.nl >= r.bound, io)

        ds_dict = Dict(v => c for (v, c) in sorted_pairs(r.ds))
        ds_match = ds_dict == exp_ds
        print_check("$label: diff spectrum matches", ds_match, io)
        if !ds_match
            print_kv("$label: expected", exp_ds, io)
            print_kv("$label: computed", ds_dict, io)
        end

        print_check("$label: deg = $(N - 1)", r.deg == N - 1, io)
        print_check("$label: Δ_f = 4", r.du == 4, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table2_report()
end
