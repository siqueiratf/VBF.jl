# Implements Table 1 — NL and diff spectra for Construction 1 (Theorem 1)
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 5
#
# Pseudocode:
#   1. For each (s,n) with s even and sn ≤ 8, build Construction 1
#   2. Compute nonlinearity, differential spectrum, algebraic degree
#   3. Compare against paper's Table 1 values
# VBF API used: SBox, differential_spectrum, linearity, algebraic_degree,
#               sorted_pairs, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

# Paper Table 1 expected values: {value^count, ...}
# NOTE: Row 3 (s=2,n=4) in paper reports NL=108 and same spectrum as Row 4 (s=4,n=2).
# Our computation (verified with all t ∈ F_4* and both Conway/primitive polynomials)
# gives NL=110 and spectrum {0^33111, 2^31698, 4^471}. The paper likely pasted
# Row 4's results into Row 3. Row 4 (s=4,n=2) matches exactly.
const TABLE1_EXPECTED = [
    # (s, n, NL(f), diff_spectrum_dict(f), bound(f))
    (2, 2, 4,   Dict(0=>135, 2=>90, 4=>15), 0),
    (2, 3, 22,  Dict(0=>2127, 2=>1794, 4=>111), 20),
    (2, 4, 110, Dict(0=>33111, 2=>31698, 4=>471), 108),
    (4, 2, 108, Dict(0=>34335, 2=>29250, 4=>1695), 96),
]

# Reuse the earlier paper's construction as a concrete independent reference.
module ZhaInverseSwapControl
include(joinpath(@__DIR__,"..","..","2013","Yuyin_201300","helpers.jl"))
end

# Keep printed claims separate from independently recomputed regression values.
const TABLE1_PUBLISHED = [
    (2,2,4,Dict(0=>135,2=>90,4=>15),0),
    (2,3,22,Dict(0=>2127,2=>1794,4=>111),20),
    (2,4,108,Dict(0=>34335,2=>29250,4=>1695),108),
    (4,2,108,Dict(0=>34335,2=>29250,4=>1695),96),
]

"""Evaluate the nonlinearity-only separation argument against the paper's [16] value.
Equal nonlinearity is inconclusive; it never proves CCZ equivalence.
"""
function proposition5_nonlinearity_evidence(; modulus=primitive_polynomial(8))
    rows = [table1_compute(s,n;modulus) for (s,n) in ((2,4),(4,2))]
    # This fixed control is built in the AES representation used by that reproduction.
    control = ZhaInverseSwapControl.inverse_swap(1,32,8;modulus=283)
    control_du = differential_uniformity(control)
    control_nl = compute_nonlinearity(control)
    control_ds = Dict(sorted_pairs(differential_spectrum(control)))
    control_du==4 && control_nl==110 || error("inverse-swap control changed; re-audit comparison")
    return [(;s=r.s,n=r.n,computed_nonlinearity=r.nl,comparison_nonlinearity=110,
              separates_by_nonlinearity=r.nl != 110,
              control_source="Yuyin_201300 inverse_swap(1,32,8), modulus 283",
              control_diff_uniformity=control_du, control_nonlinearity=control_nl,
              control_differential_spectrum=control_ds,
              separates_from_control_by_differential_spectrum=Dict(sorted_pairs(r.ds)) != control_ds,
              conclusion=r.nl == 110 ? "inconclusive against the whole cited family: the nonlinearity argument fails; distinct differential spectrum separates this single control" :
              "different nonlinearity proves CCZ inequivalence to references with nonlinearity 110") for r in rows]
end

function table1_compute(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    N = s * n
    t = if iseven(s) && ((1 << s) - 1) % 3 == 0
        find_t_construction1(s, n; modulus)
    else
        1
    end
    lut = construction1_lut(s, n, t; modulus)
    sbox = SBox{N}(lut)
    nl = compute_nonlinearity(sbox)
    ds = differential_spectrum(sbox)
    deg = algebraic_degree(sbox)
    du = differential_uniformity(sbox)
    bound = nl_lower_bound(s, n)
    (; s, n, N, t, nl, ds, deg, du, bound, sbox)
end

function table1_report(io::IO = stdout)
    print_section("Table 1 — Construction 1 (Theorem 1) computational results", io)

    for (row, (s, n, exp_nl, exp_ds, exp_bound)) in enumerate(TABLE1_EXPECTED)
        r = table1_compute(s, n)
        N = r.N
        label = "sn=$N (s=$s, n=$n)"

        printed = TABLE1_PUBLISHED[row]
        published_match = r.nl == printed[3] && Dict(sorted_pairs(r.ds)) == printed[4]
        print_check("$label: matches printed Table 1", published_match, io)
        published_match || print_kv("$label: paper contradiction", "published NL=$(printed[3]); computed NL=$(r.nl), spectrum=$(Dict(sorted_pairs(r.ds)))", io)

        # Nonlinearity
        print_check("$label: NL = $exp_nl", r.nl == exp_nl, io)
        print_kv("$label: NL computed", r.nl, io)

        # NL lower bound
        print_check("$label: B(f) = $exp_bound", r.bound == exp_bound, io)
        print_check("$label: NL ≥ B(f)", r.nl >= r.bound, io)

        # Differential spectrum
        ds_dict = Dict(v => c for (v, c) in sorted_pairs(r.ds))
        ds_match = ds_dict == exp_ds
        print_check("$label: diff spectrum matches", ds_match, io)
        if !ds_match
            print_kv("$label: expected", exp_ds, io)
            print_kv("$label: computed", ds_dict, io)
        end

        # Algebraic degree
        print_check("$label: deg = $(N - 1)", r.deg == N - 1, io)

        # Differential uniformity
        print_check("$label: Δ_f = 4", r.du == 4, io)
    end
    evidence=proposition5_nonlinearity_evidence()
    for row in evidence
        print_kv("Proposition 5 s=$(row.s),n=$(row.n)", row.conclusion, io)
    end
    return evidence
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table1_report()
end
