@testset "Section VII-D: thirteen named quadratic classes, both shift valences" begin
    include(joinpath(@__DIR__,"..","section7d.jl"))
    result=section7d_replay()
    @test result.complete && result.all_valid
    @test length(result.references)==13
    @test length(result.records)==26
    @test length(Set(apn_ea_mugshot(r.sbox) for r in result.references))==13
    @test result.verified==result.expected
    @test !result.space_exhausted
    @test result.discovery["evaluations"]==65_614_477
    @test result.discovery["apn_trials"]==200
    @test result.discovery["undecided"]==0
    @test result.discovery["sampling"]=="uniform basis images with replacement"
    for r in result.records
        @test r.valid
        @test differential_uniformity(r.shift.F)==2
        @test r.nullity==0 ? is_permutation_map(r.shift.L_lut) : is_2to1(r.shift.L_lut)
        # Direct preimage-count control independently of the binary-rank test.
        counts=zeros(Int,64)
        for value in r.shift.L_lut
            counts[value+1]+=1
        end
        @test all(c==0 || c==1 << r.nullity for c in counts)
    end
    original=TOML.parsefile(SECTION7D_FIXTURE)["witnesses"][1]
    bad=deepcopy(original);bad["columns"]=zeros(Int,12)
    @test !section7d_verify_record(bad).valid
    bad=deepcopy(original);bad["constant"]⊻=1
    @test !section7d_verify_record(bad).valid
    bad=deepcopy(original);bad["source_sha256"]="incorrect"
    @test !section7d_verify_record(bad).valid
    bad=deepcopy(original);bad["nullity"]=1-original["nullity"]
    @test !section7d_verify_record(bad).valid
    bad=deepcopy(original);bad["normalization"]["coefficients"][1]⊻=1
    @test !section7d_verify_record(bad).valid
    # An invertible CCZ graph map need not preserve the EA output subspace.
    mixed=F2AffineMap{12,UInt32}([1 << (j<6 ? j+6 : j-6) for j in 0:11],0)
    @test !section7d_verify_graph(result.records[1].shift.F,result.references[1].sbox,mixed)
    bounded=section7d_discover(max_evaluations=0)
    @test bounded.outcome isa BudgetHit && isempty(bounded.covered)
    @test !bounded.space_exhausted
    @test !proves_emptiness(bounded.outcome)
    timed=section7d_discover(timeout_seconds=0)
    @test timed.outcome isa BudgetHit
    @test_throws ArgumentError section7d_discover(max_evaluations=-1)
    @test_throws ArgumentError section7d_shift([1,2,3,4,5,64])
end
