@testset "Section 3.2 seven-bit checkpoint audit fixtures" begin
    include(joinpath(@__DIR__,"..","section32_sevenbit_audit.jl"))
    F = gold_apn(4,1)
    computed = ea_class_representatives(F; algorithm=:optimized,
        subspace_algorithm=:optimized, prefer_permutations=false)
    @test computed.complete
    H = computed.orbit_result.automorphisms
    input = (;function_value=F,label="fixture",identifier="fixture4",provenance="test")
    witnesses = [Dict{String,Any}("dimension"=>4,"relation"=>"ccz",
        "source_lut"=>Int.(F.lut),"target_lut"=>Int.(G.lut),"target_index"=>i,
        "linear_columns"=>Int.(A.linear.cols),"constant"=>Int(A.constant))
        for (i,(G,A)) in enumerate(zip(computed.representatives,computed.mappings))]
    degrees = Dict{String,Int}()
    for G in computed.representatives
        degree = string(algebraic_degree(G))
        degrees[degree] = get(degrees,degree,0)+1
    end
    fixture = Dict{String,Any}("root_index"=>1,"source_lut"=>Int.(F.lut),
        "label"=>input.label,"identifier"=>input.identifier,"provenance"=>input.provenance,
        "schema"=>"vbf-sevenbit-closure-v1","source_hashes"=>Dict("fixture"=>repeat("0",64)),
        "algorithm_profile"=>"optimized","subspace_algorithm"=>"optimized","seed"=>940,
        "complete"=>true,"automorphisms_complete"=>true,"subspaces_complete"=>true,
        "actions_complete"=>true,"stop_reason"=>"none",
        "bases"=>[Int.(b) for b in computed.orbit_result.bases],
        "orbits"=>computed.orbit_result.orbits,"spaces"=>computed.orbit_result.nspaces,
        "classes"=>length(witnesses),"degrees"=>degrees,"witnesses"=>witnesses,
        "group_order"=>string(H.order),
        "generators"=>[Dict("linear_columns"=>Int.(A.linear.cols),"constant"=>Int(A.constant))
            for A in H.generators])
    budget() = (;start=time_ns(),timeout=30.0)
    audited = _bgp_seven_audit_row(fixture,input,1,budget())
    @test audited["complete"]
    @test audited["degrees"] == degrees
    @test audited["classes"] == 2

    for corrupt in (
        row -> (row["source_lut"][1] ⊻= 1),
        row -> (row["generators"][1]["linear_columns"][2] = row["generators"][1]["linear_columns"][1]),
        row -> (row["bases"][1][1] = 0),
        row -> push!(row["bases"],copy(row["bases"][1])),
        row -> push!(row["orbits"][1],row["orbits"][1][1]),
        row -> empty!(row["generators"]),
        row -> (row["witnesses"][1]["target_lut"][1] ⊻= 1),
        row -> (row["witnesses"][1]["target_index"] = 9),
        row -> begin
            reverse!(row["witnesses"])
            for (i,witness) in pairs(row["witnesses"])
                witness["target_index"] = i
            end
        end,
        row -> (row["degrees"]["2"] += 1),
        row -> (row["actions_complete"] = false),
    )
        bad = deepcopy(fixture)
        corrupt(bad)
        @test_throws ArgumentError _bgp_seven_audit_row(bad,input,1,budget())
    end

    mktempdir() do directory
        path = joinpath(directory,"root_001.toml")
        write_fixture(row) = open(path,"w") do io
            TOML.print(io,row;sorted=true)
        end
        write_fixture(fixture)
        full = _bgp_seven_audit_paths([path],[input],budget();limit=1,expected_counts=degrees)
        @test full.complete
        @test full.complete_counts == degrees
        @test isempty(full.partial_counts)
        @test occursin("not independently replayed",full.summary["completeness_scope"])
        bytes = read(path)
        TOML.print(IOBuffer(),full.summary)
        @test read(path) == bytes
        @test_throws ArgumentError _bgp_seven_audit_paths([path],[input],budget();
            limit=1,expected_counts=Dict("2"=>100))
        second = deepcopy(fixture)
        second["root_index"] = 2
        second["seed"] = 941
        second["source_hashes"]["fixture"] = repeat("1",64)
        second_path = joinpath(directory,"root_002.toml")
        open(second_path,"w") do io
            TOML.print(io,second;sorted=true)
        end
        @test_throws ArgumentError _bgp_seven_audit_paths([path,second_path],
            [input,input],budget();limit=2,expected_counts=degrees)
        partial = deepcopy(fixture)
        partial["complete"] = false
        partial["stop_reason"] = "time"
        write_fixture(partial)
        result = _bgp_seven_audit_paths([path],[input],budget();limit=1,expected_counts=degrees)
        @test !result.complete
        @test isempty(result.complete_counts)
        @test result.partial_counts == degrees
        @test !result.summary["paper_totals_match"]
        stopped = _bgp_seven_audit_paths([path],[input],(;start=time_ns(),timeout=0.0);
            limit=1,expected_counts=degrees)
        @test !stopped.complete && isempty(stopped.rows)
        @test stopped.summary["stop_reason"] == "time"
    end
end
