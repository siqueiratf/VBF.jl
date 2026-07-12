@testset "section4_4 (Tables 6-7, catalog partition)" begin
    include(joinpath(@__DIR__, "..", "section4_4.jl"))

    using VBFCatalog

    # Table 6: the Banff list
    fns = banff_functions()
    @test length(fns) == 13
    @test all(differential_uniformity(F) == 2 for F in fns)
    @test all(algebraic_degree(F) == 2 for F in fns)
    @test fns[5].lut == kim_apn().lut   # function 5 is κ

    # mugshots separate all 13 (including functions 9 vs 10)
    @test length(Set(apn_ea_mugshot(F) for F in fns)) == 13
    @test !are_ea_equivalent(fns[9], fns[10])

    # catalog: 15 quadratic 6-bit APN → 13 EA-classes, one bucket of 3
    db = load_catalog()
    quad_fns = filter(f -> f.is_quadratic, list_functions(db; n = 6, is_apn = true))
    @test length(quad_fns) == 15

    sboxes = [load_sbox(db, f.id) for f in quad_fns]
    buckets = Dict()
    for sb in sboxes
        push!(get!(buckets, apn_ea_mugshot(sb), Any[]), sb)
    end
    @test length(buckets) == 13
    @test any(length(v) == 3 for v in values(buckets))

    # catalog classes coincide with the Banff classes
    @test Set(keys(buckets)) == Set(apn_ea_mugshot(F) for F in fns)

    # same-bucket pairs are EA-equivalent
    for members in values(buckets)
        for i in 1:length(members), j in (i+1):length(members)
            @test are_ea_equivalent(members[i], members[j])
        end
    end

    # full Table 7 verification (thickness spectra, linearity, Γ/Δ-rank,
    # max #EA, π_F differential spectra, π thickness spectra; ≈ 30 s)
    r = section4_4_report(io = devnull)
    @test r.table7_ok
    @test r.seven_spectra
    @test r.all_ok
end
