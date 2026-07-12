# Implements Table 3.1 verification
# Paper: Taniguchi et al. (2025), "Changing APN functions on affine subspaces
#        of small codimensions"
# Section: 3.1 — Table 3.1: APN functions G_i(x) = x^3 + Tr(x) L_i(x) on GF(2^6)
#
# Pseudocode:
#   1. Load 13 linearized polynomials L_i from Table 3.1 (helpers.jl)
#   2. Build LUT for each G_i(x) = x^3 + Tr(x) L_i(x)
#   3. Verify each G_i is APN (differential_uniformity == 2)
#   4. Compute EA-class mugshots, check 13 distinct classes
# VBF API used: gf_pow, SBox, differential_uniformity,
#               algebraic_degree, apn_ea_mugshot, APNEAMugshot

include(joinpath(@__DIR__, "helpers.jl"))

"""
Build all 13 G_i functions as SBox objects.
"""
function build_table3_1_functions(n::Int = 6, mod::Int = PAPER_MODULUS_6)
    F_lut = [gf_pow(x, 3, n; modulus=mod) for x in 0:(1<<n)-1]
    entries = table3_1_coefficients(n, mod)
    results = []
    for entry in entries
        g_lut = build_g_lut(F_lut, entry.coeffs, n, mod)
        push!(results, (name=entry.name, dillon=entry.dillon, coeffs=entry.coeffs,
                        sbox=SBox(g_lut)))
    end
    results
end

function table3_1_report(io::IO = stdout)
    n = 6
    mod = PAPER_MODULUS_6
    print_section("Table 3.1: 13 APN functions G_i(x) = x^3 + Tr(x)L_i(x)", io)

    funcs = build_table3_1_functions(n, mod)

    all_apn = true
    all_quad = true
    mugshots = Dict{String, APNEAMugshot}()

    for f in funcs
        du = differential_uniformity(f.sbox)
        deg = algebraic_degree(f.sbox)
        is_apn = (du == 2)

        all_apn &= is_apn
        all_quad &= (deg == 2)

        if is_apn
            m = apn_ea_mugshot(f.sbox)
            mugshots[f.name] = m
        end

        status = is_apn ? "APN" : "NOT APN"
        print_kv(io, "$(f.name) → $(f.dillon)", "$status, deg=$deg")
    end

    print_check(io, "all 13 functions are APN", all_apn)
    print_check(io, "all 13 functions are quadratic", all_quad)

    unique_mugshots = unique(collect(values(mugshots)))
    n_classes = length(unique_mugshots)
    print_kv(io, "distinct EA-classes (mugshots)", n_classes)
    print_check(io, "13 distinct EA-classes", n_classes == 13)

    (; all_apn, all_quadratic=all_quad, n_classes, mugshots)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table3_1_report()
end
