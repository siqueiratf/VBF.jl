@testset "section5_test" begin
    include(joinpath(@__DIR__, "..", "section5.jl"))

    db = load_catalog()

    # Gold x^3 n=6 (even): Gold-like partition (3 buckets [1, 21, 42]).
    F6 = gold_x3(6)
    p6 = ea_partition(F6)
    @test is_gold_like_partition(p6)
    @test sort(p6.bucket_sizes) == [1, 21, 42]

    # Gold x^3 n=5 (odd): trivial partition (2 buckets [1, 31]).
    F5 = gold_x3(5)
    p5 = ea_partition(F5)
    @test is_trivial_partition(p5)
    @test sort(p5.bucket_sizes) == [1, 31]

    # All n=5 quadratic APN have trivial partition (paper Section 5: odd n claim).
    rows5 = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = 5))
    for r in rows5
        F = load_sbox(db, r.canonical_name)
        @test is_trivial_partition(ea_partition(F))
    end

    # At least one n=6 quadratic APN has a non-trivial, non-Gold-like partition.
    rows6 = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = 6))
    n_gold_like = count(is_gold_like_partition(ea_partition(load_sbox(db, r.canonical_name))) for r in rows6)
    n_nontrivial = count(!is_trivial_partition(ea_partition(load_sbox(db, r.canonical_name))) for r in rows6)
    @test n_nontrivial == length(rows6)   # no trivial for even n
    @test n_gold_like ≥ 1
end
