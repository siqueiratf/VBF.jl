# Table 7, entry 14.3 — exact source-polynomial reconstruction at n=7.
# VBF API: gf_pow, gf_mul, gf_trace, terms_to_lut, SBox, design ranks.
include(joinpath(@__DIR__, "helpers.jl"))

function edelpott_table7_14_3()
    n, modulus = 7, 131 # Table 2: x^7+x+1; u=x.
    base = terms_to_lut([(1,e) for e in (3,6,34,40,72)], n, modulus)
    trace_input = terms_to_lut([(gf_pow(2,c,n; modulus),e)
        for (c,e) in ((20,3),(94,5),(66,9))], n, modulus)
    multiplier = gf_pow(2,27,n; modulus)
    SBox{7}([base[x+1] ⊻ gf_mul(multiplier,
        gf_trace(trace_input[x+1],n; modulus),n; modulus) for x in 0:127])
end

function table7_report(; io::IO=stdout)
    F = edelpott_table7_14_3()
    r = (; differential_uniformity=differential_uniformity(F),
        degree=algebraic_degree(F), gamma_rank=gamma_rank(F), delta_rank=delta_rank(F))
    print_section("Table 7, entry 14.3 / Table 8 invariants", io)
    print_kv("independently computed", r, io)
    print_check("published (du, degree, Gamma, Delta) = (2,2,4046,212)",
        r == (differential_uniformity=2, degree=2, gamma_rank=4046, delta_rank=212), io)
    print_kv("scope", "source representative verified; global novelty is not inferred from catalog absence", io)
    r
end

if abspath(PROGRAM_FILE) == @__FILE__
    table7_report()
end
