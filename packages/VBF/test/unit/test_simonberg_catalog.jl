using VBF
using Test
import DBInterface

# Simon-Berg thesis data — "All CCZ classes of functions with coefficients in
# GF(2²) over GF(2⁸)" — is imported as 27 first-class representative rows
# (family "CCZ-rep-GF4"), one per CCZ class. The full ~197k membership is
# ingested as "matches only" provenance, not as rows. These tests are written
# relationally so they don't desync; the absolute count (27) is pinned in
# test_catalog_content.jl.

@testset "CCZ-rep-GF4 family: present and well-formed" begin
    db = load_catalog()
    gf4 = list_functions(db; family = "CCZ-rep-GF4")
    @test length(gf4) == 27
    # all are n=8 quadratic APN non-permutations
    @test all(r.n == 8 for r in gf4)
    @test all(r.is_apn == 1 || r.is_apn == true for r in gf4)
    @test all(r.differential_uniformity == 2 for r in gf4)
    @test all(r.is_quadratic == 1 || r.is_quadratic == true for r in gf4)
    @test all(r.is_permutation == 0 || r.is_permutation == false for r in gf4)
    # one canonical name per class 1..27
    names = Set(r.canonical_name for r in gf4)
    @test names == Set("SimonBerg_GF4_n8_class_$(k)" for k in 1:27)
    # provenance: each row carries both the BFA tag and the Simon-Berg tag
    @test all(occursin("simonberg@", r.source_repo) && occursin("bfa@", r.source_repo) for r in gf4)
    # the per-class member count is recorded in the notes
    @test all(occursin("members", r.notes) for r in gf4)
    # representatives are pairwise distinct functions
    @test length(Set(r.lut_sha256 for r in gf4)) == 27
end

@testset "CCZ-rep-GF4 rows round-trip and recompute their stats" begin
    db = load_catalog()
    gf4 = list_functions(db; family = "CCZ-rep-GF4")
    for r in gf4
        s = load_sbox(db, r.id)
        @test inputbits(s) == 8
        @test differential_uniformity(s) == 2
        @test algebraic_degree(s) == r.algebraic_degree
        @test algebraic_degree(s) == 2          # quadratic
        @test Int(is_permutation(s)) == r.is_permutation
    end
end

@testset "CCZ-rep-GF4: 27 distinct CCZ classes (ortho-derivative fingerprints)" begin
    db = load_catalog()
    gf4 = list_functions(db; family = "CCZ-rep-GF4")
    # The ortho-derivative's differential + (absolute) Walsh spectra are an
    # EA/CCZ invariant of quadratic APN functions. 27 distinct fingerprints
    # confirm 27 distinct CCZ classes (the thesis' claim).
    fps = Set{UInt64}()
    for r in gf4
        s = load_sbox(db, r.id)
        o = ortho_derivative(s)
        @test o !== nothing
        D = ddt(o); L = abs.(lat(o))
        ddt_spec = sort([(v, count(==(v), D)) for v in unique(D)])
        lat_spec = sort([(v, count(==(v), L)) for v in unique(L)])
        push!(fps, hash((ddt_spec, lat_spec)))
    end
    @test length(fps) == 27
end

# --- dev-time polynomial parser (data-build/_polynomial_parser.jl) ----------

# Guard so `include` doesn't trigger any importer autorun (defensive — the
# parser file itself has no autorun, but keep the convention).
ENV["BFA_SIMONBERG_NO_AUTORUN"] = "1"
include(joinpath(pkgdir(VBFCatalog), "data-build", "_polynomial_parser.jl"))

@testset "parser: `a` is an alias for the field generator" begin
    n = 8; mod = conway_polynomial(n)
    # `a` (Magma/Simon-Berg) ≡ `g`/`ksi` (Sage) ≡ the element 2 under Conway.
    @test evaluate_polynomial("a**85", 0, n, mod) == gf_pow(2, 85, n; modulus = mod)
    @test evaluate_polynomial("a^170 * X", 5, n, mod) ==
          gf_mul(gf_pow(2, 170, n; modulus = mod), 5, n; modulus = mod)
end

@testset "parser: term evaluator matches the reference evaluator" begin
    n = 8; mod = conway_polynomial(n)
    expr = "a^85*X^160 + a^170*X^132 + X^130 + X^3"
    ref  = polynomial_to_lut(expr, n, mod)
    fast = terms_to_lut(polynomial_terms(expr, n, mod), n, mod)
    @test ref == fast
    # with a shared power table (the importer's bulk path)
    powtab = monomial_power_table(n, mod)
    @test terms_to_lut(polynomial_terms(expr, n, mod), n, mod; powtab = powtab) == ref
    # parentheses are rejected by the flat term parser
    @test_throws ErrorException polynomial_terms("a*(X + X^2)", n, mod)
end

@testset "parser: monomial_power_table is correct" begin
    n = 8; mod = conway_polynomial(n)
    tab = monomial_power_table(n, mod)
    @test tab[0 + 1][0 + 1] == 1          # 0^0 = 1
    @test tab[5 + 1][3 + 1] == gf_pow(5, 3, n; modulus = mod)
    @test tab[2 + 1][200 + 1] == gf_pow(2, 200, n; modulus = mod)
end

# Optional: if the thesis checkout is present, re-derive class 1's
# representative from the source file and confirm it matches the catalog row.
@testset "CCZ-rep-GF4: class-1 representative re-derives from the thesis source" begin
    candidates = [get(ENV, "BFA_THESIS_PATH", ""),
                  "/home/zambonin/APN.jl/Simon-Berg@thesis",
                  joinpath(homedir(), "APN.jl", "Simon-Berg@thesis")]
    idx = findfirst(p -> !isempty(p) && isfile(joinpath(p, "rep1.txt")), candidates)
    if idx === nothing
        @test_skip "thesis checkout not present"
    else
        thesis = candidates[idx]
        n = 8; mod = conway_polynomial(n)
        body = strip(read(joinpath(thesis, "rep1.txt"), String))
        body = strip(body[nextind(body, firstindex(body)):prevind(body, lastindex(body))])
        first_poly = strip(replace(split(body, ','; keepempty = false)[1], '\n' => ' '))
        lut = terms_to_lut(polynomial_terms(first_poly, n, mod), n, mod)
        s = SBox{8}(lut)
        db = load_catalog()
        row = find_function(db; canonical_name = "SimonBerg_GF4_n8_class_1")
        @test row !== nothing
        @test row.lut_sha256 == lut_sha256_hex(s)
    end
end
