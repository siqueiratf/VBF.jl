# Implements Section 5A: CCZ-inequivalence via orthoderivative differential spectra
# Paper: Li, Kaleyski (2024), "Two New Infinite Families of APN Functions in Trivariate Form"
# Section: 5A — Table IV: orthoderivative differential spectra over GF(2^9)
#
# Pseudocode:
#   1. Build F₁ (Prop. 4, m=3, i=1) and F₂ (Prop. 8, m=3, i=1) LUTs over GF(2^9)
#   2. Compute ortho_derivative of each
#   3. Compute differential_spectrum of each orthoderivative
#   4. Compare to paper Table IV expected values
#   5. Note: spectra distinct from all known families in Table IV → CCZ-inequivalent
#   6. Both match Beierle-Leander (2021) sporadic instances #34 and #35
# VBF API used: ortho_derivative, differential_spectrum, differential_uniformity,
#               SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem1.jl"))
include(joinpath(@__DIR__, "theorem6.jl"))

# Paper Table IV — orthoderivative differential spectra for n=9 (page 25)
const TABLE_IV_KNOWN = Dict(
    "Gold (x³)"       => Dict(0=>153811, 2=>96579, 6=>10731, 8=>511),
    "Gold (x^33)"     => Dict(0=>159943, 2=>78183, 4=>18396, 6=>4599, 8=>511),
    "F4"              => Dict(0=>159016, 2=>79389, 4=>19089, 6=>3483, 8=>493, 10=>144, 12=>18),
    "F5"              => Dict(0=>159226, 2=>78813, 4=>19683, 6=>3201, 8=>529, 10=>162, 12=>18),
    "F6"              => Dict(0=>160525, 2=>77058, 4=>19467, 6=>3792, 8=>598, 10=>126, 12=>45, 14=>12, 16=>9),
    "F10"             => Dict(0=>160097, 2=>79128, 4=>17808, 6=>3269, 8=>700, 10=>357, 12=>231, 14=>42),
)

# Paper Table IV — F₁ and F₂ orthoderivative spectra (n=9, page 25)
const TABLE_IV_F1_EXPECTED = Dict(
    0=>164199, 2=>76734, 4=>13524, 6=>4312, 8=>2205, 12=>147, 16=>294, 18=>147, 20=>49, 22=>21
)
const TABLE_IV_F2_EXPECTED = Dict(
    0=>172557, 2=>68355, 4=>12201, 6=>3871, 8=>1638, 10=>735, 12=>1470, 14=>49,
    16=>147, 18=>441, 20=>147, 42=>21
)

"""
    spec_to_dict(spec) -> Dict{Int,Int}

Convert a `Spectrum` (or `Vector{Int}`) to Dict{value => count}.
"""
function spec_to_dict(spec::Spectrum)::Dict{Int,Int}
    copy(spec.counts)
end
function spec_to_dict(spec::Vector{Int})::Dict{Int,Int}
    d = Dict{Int,Int}()
    for v in spec
        d[v] = get(d, v, 0) + 1
    end
    d
end

"""
    dicts_equal(a, b) -> Bool

Compare two Dict{Int,Int} ignoring zero-count entries.
"""
function dicts_equal(a::Dict{Int,Int}, b::Dict{Int,Int})::Bool
    for (k, v) in a; v != 0 && get(b, k, 0) != v && return false; end
    for (k, v) in b; v != 0 && get(a, k, 0) != v && return false; end
    return true
end

"""
    format_spec(d) -> String

Format a multiplicity dict as "0×N, 2×M, ..." sorted by multiplicity.
"""
function format_spec(d::Dict{Int,Int})::String
    pairs = sort(collect(d), by = first)
    join(["$(k)×$(v)" for (k, v) in pairs if v > 0], ", ")
end

"""
    section5a_report(; io) -> NamedTuple

Table IV verification: compute orthoderivative differential spectra for F₁ and F₂
at n=9 (m=3, i=1) and compare to paper values. Both should be distinct from all
entries in Table IV (known families), confirming CCZ-inequivalence.
"""
function section5a_report(; io::IO = stdout)
    print_section("Section 5A — Table IV: Orthoderivative Differential Spectra (n=9)", io)
    print_kv("m", 3, io);  print_kv("i", 1, io);  print_kv("q", 2, io)

    # F₁ — Proposition 4 (Family 1, n=9)
    lut1    = family1_lut(3, 1)
    od1     = ortho_derivative(SBox(lut1))
    spec1   = differential_spectrum(od1)
    dict1   = spec_to_dict(spec1)

    print_kv("F₁ ortho-deriv spectrum", format_spec(dict1), io)
    match1 = dicts_equal(dict1, TABLE_IV_F1_EXPECTED)
    print_check("F₁ spectrum matches Table IV (paper, p. 25)", match1, io)

    # F₂ — Proposition 8 (Family 2, n=9)
    lut2    = family2_lut(3, 1)
    od2     = ortho_derivative(SBox(lut2))
    spec2   = differential_spectrum(od2)
    dict2   = spec_to_dict(spec2)

    print_kv("F₂ ortho-deriv spectrum", format_spec(dict2), io)
    match2 = dicts_equal(dict2, TABLE_IV_F2_EXPECTED)
    print_check("F₂ spectrum matches Table IV (paper, p. 25)", match2, io)

    # Confirm spectra are distinct from all known families in Table IV
    known_spectra = values(TABLE_IV_KNOWN)
    f1_new = all(!dicts_equal(dict1, s) for s in known_spectra)
    f2_new = all(!dicts_equal(dict2, s) for s in known_spectra)
    print_check("F₁ spectrum distinct from all Table IV known families", f1_new, io)
    print_check("F₂ spectrum distinct from all Table IV known families", f2_new, io)
    print_check("F₁ and F₂ spectra are distinct from each other", !dicts_equal(dict1, dict2), io)

    return (; dict1, dict2, match1, match2, f1_new, f2_new)
end

if abspath(PROGRAM_FILE) == @__FILE__
    include(joinpath(@__DIR__, "helpers.jl"))
    include(joinpath(@__DIR__, "theorem1.jl"))
    include(joinpath(@__DIR__, "theorem6.jl"))
    print_header()
    section5a_report()
end
