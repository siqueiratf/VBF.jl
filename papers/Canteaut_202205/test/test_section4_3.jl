@testset "section4_3" begin
    include(joinpath(@__DIR__, "..", "section4_3.jl"))

    using VBFCatalog

    db = load_catalog()
    all_fns = list_functions(db; n=6, is_apn=true)
    quad_fns = filter(f -> f.is_quadratic, all_fns)

    @test length(quad_fns) == 15

    sboxes = [load_sbox(db, f.id) for f in quad_fns]

    # Partition by mugshot
    buckets = Dict()
    for sb in sboxes
        mug = apn_ea_mugshot(sb)
        push!(get!(buckets, mug, Any[]), sb)
    end

    # Should produce exactly 13 EA-classes (paper claim for 6-bit quadratic APN)
    @test length(buckets) == 13

    # One class should have 3 members (Gold, Kasami, reprs6_0)
    @test any(length(v) == 3 for v in values(buckets))

    # All same-bucket pairs must be EA-equivalent
    for members in values(buckets)
        length(members) < 2 && continue
        for i in 1:length(members)
            for j in (i+1):length(members)
                @test are_ea_equivalent(members[i], members[j])
            end
        end
    end
end
