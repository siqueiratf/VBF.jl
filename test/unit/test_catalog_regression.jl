using BFA
using Test

# One-glance cryptographic fingerprint for every literature S-box. Adding a
# new S-box requires extending this table; the entries are locked because
# divergence here means either the loader broke or a port regressed.
#
# Columns:
#   name           — key into the literature catalog
#   du   (Int)     — differential_uniformity
#   lin  (Int)     — linearity
#   deg  (Int)     — algebraic_degree
#   bu   (Int)     — boomerang_uniformity; missing for non-permutations
#
# References for each value live in the per-statistic unit test files.

const FINGERPRINTS = [
    #=  name             du  lin  deg  bu  =#
    ("AES",                4,  32,   7,   6),
    ("AES_inv",            4,  32,   7,   6),
    ("PRESENT",            4,   8,   3,  16),
    ("GIFT",               6,   8,   3,  16),
    ("Midori_Sb0",         4,   8,   3,  16),
    ("Midori_Sb1",         4,   8,   3,  10),
    ("SKINNY_4",           4,   8,   3,  16),
    ("Piccolo",            4,   8,   3,  16),
    ("SERPENT_S0",         4,   8,   3,  16),
    ("SERPENT_S1",         4,   8,   3,  16),
    ("SERPENT_S2",         4,   8,   3,  16),
    ("SERPENT_S3",         4,   8,   3,  10),
    ("SERPENT_S4",         4,   8,   3,  10),
    ("SERPENT_S5",         4,   8,   3,  10),
    ("SERPENT_S6",         4,   8,   3,  16),
    ("SERPENT_S7",         4,   8,   3,  10),
    ("TWINE",              4,   8,   3,   6),
    ("KLEIN",              4,   8,   3,  10),
]

@testset "catalog fingerprint locked: $name" for (name, du, lin, deg, bu) in FINGERPRINTS
    s = load_literature_sbox(name)
    @test differential_uniformity(s) == du
    @test linearity(s)               == lin
    @test algebraic_degree(s)        == deg
    @test boomerang_uniformity(s)    == bu
end

@testset "catalog fingerprint covers every catalog entry" begin
    # If someone adds a new S-box to literature_sboxes.toml but forgets to
    # extend FINGERPRINTS, this test surfaces it.
    @test Set(first.(FINGERPRINTS)) == Set(literature_sbox_names())
end
