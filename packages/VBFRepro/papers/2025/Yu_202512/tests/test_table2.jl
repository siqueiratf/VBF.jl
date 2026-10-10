@testset "Table 2 explicit Frobenius representatives" begin
    include(joinpath(@__DIR__,"..","table2.jl"))
    for (n,value_count,log_count) in ((6,1,4),(7,117,78))
        values=partial_search_apn_f2(n;limit=1000,max_evaluations=1<<24,reps=:min_value,return_stats=true)
        logs=partial_search_apn_f2(n;limit=1000,max_evaluations=1<<24,reps=:min_log,return_stats=true)
        @test values.count == value_count
        @test logs.count == log_count
        @test values.exhaustive && logs.exhaustive
        @test logs.candidate_space == (n==6 ? 567 : 5832)
        @test Set(gf_pow(x,1<<j,n;modulus=conway_polynomial(n)) for x in fn_set(n;reps=:min_log) for j in 0:n-1) ==
              Set(gf_pow(x,1<<j,n;modulus=conway_polynomial(n)) for x in fn_set(n;reps=:min_value) for j in 0:n-1)
    end
    bounded=partial_search_apn_f2(7;max_evaluations=1,return_stats=true)
    @test bounded.evaluations == 1
    @test !bounded.exhaustive
    @test_throws ArgumentError partial_search_apn_f2(7;max_evaluations=0)
    @test_throws ArgumentError fn_set(7;reps=:unknown)
end
