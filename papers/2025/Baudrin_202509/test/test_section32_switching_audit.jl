# Structural and mathematical regression tests for saved switching checkpoints.
@testset "switching checkpoint audit" begin
    isdefined(@__MODULE__,:bgp_audit_switching_parent) ||
        include(joinpath(@__DIR__,"..","section32_switching_audit.jl"))
    F = gold_apn(4)
    parent = (;function_value=F,root_index=1,label="small fixture")
    other = (;function_value=SBox{4}(F.lut .⊻ UInt8(1)),root_index=1,label="translated fixture")
    census = (;roots=[F],parents=[parent,other],sha256="fixture-census")
    identity = Dict{String,Any}("census_sha256"=>census.sha256,
        "schema"=>"vbf-switching-closure-v1","source_hashes"=>Dict("fixture"=>repeat("a",64)),"seed"=>940)

    function fixture(;max_neighbors=typemax(Int))
        kernels = Dict{Int,Any}()
        directions = Dict{String,Any}[]
        records = Dict{String,Any}[]
        node_count = Ref(0)
        result = switching_neighbors_bounded(F;timeout_seconds=Inf,
            max_evaluations=typemax(Int),max_neighbors,
            diagnostics=(event,value)->begin
                if event === :kernel
                    kernels[value.direction] = Dict(string(k)=>v for (k,v) in pairs(value))
                elseif event === :direction_complete
                    push!(directions,merge(kernels[value.direction],
                        Dict(string(k)=>v for (k,v) in pairs(value))))
                end
            end,
            observer=(event,G)->begin
                event === :apn || return
                outcome = partition_refinement_equivalence(G,F;
                    max_nodes=100000,timeout_seconds=10)
                outcome isa Found || error("small switching fixture did not recover its known CCZ map")
                node_count[] += nodes_visited(outcome)
                A = only(search_solutions(outcome))
                push!(records,Dict{String,Any}("candidate_lut"=>Int.(G.lut),
                    "candidate_sha256"=>bytes2hex(sha256(UInt8.(G.lut))),
                    "status"=>"matched","root_index"=>1,
                    "witness"=>bgp_witness(G,F,A;kind="switching_ccz_match",target=1),
                    "checks"=>[Dict("root_index"=>1,"outcome"=>"found",
                        "nodes"=>nodes_visited(outcome))]))
            end)
        return merge(copy(identity),Dict{String,Any}("parent_index"=>1,
            "parent_lut"=>Int.(F.lut),"source_root_index"=>1,
            "complete"=>result isa Exhausted,"constructor_complete"=>result isa Exhausted,
            "evaluations"=>nodes_visited(result),"neighbors"=>length(search_solutions(result)),
            "comparisons"=>length(records),"nodes"=>node_count[],"records"=>records,
            "directions"=>directions))
    end

    full = fixture()
    @test full["neighbors"] > 0
    audit = bgp_audit_switching_parent(full,parent,census;parent_index=1,identity)
    @test audit.complete
    @test audit.constructor_complete
    @test audit.directions_checked == 15
    @test audit.dimensions_verified
    @test audit.neighbors == audit.evaluations == full["neighbors"]
    @test Set(audit.edges) == Set([(1,1)])
    dimensions = bgp_switching_flat_dimensions(F)
    @test [row.direction for row in dimensions] == collect(1:15)
    @test sum((big(1) << row.quotient_dimension)-1 for row in dimensions) == full["neighbors"]

    @testset "binding and mathematical corruption" begin
        @test_throws ArgumentError bgp_audit_switching_parent(full,other,census;parent_index=2)
        swapped = deepcopy(full)
        swapped["parent_index"] = 2
        @test_throws ArgumentError bgp_audit_switching_parent(swapped,other,census;parent_index=2)
        for key in ("neighbors","evaluations","source_root_index")
            broken = deepcopy(full)
            broken[key] += 1
            @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        end
        broken = deepcopy(full)
        broken["source_hashes"]["fixture"] = repeat("b",64)
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1,identity)
        broken = deepcopy(full)
        pop!(broken["directions"])
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        broken = deepcopy(full)
        broken["directions"][1]["raw_dimension"] += 1
        broken["directions"][1]["trivial_dimension"] += 1
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        broken = deepcopy(full)
        broken["records"][1]["candidate_lut"][1] ⊻= 2
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        broken = deepcopy(full)
        broken["records"][1]["candidate_sha256"] = repeat("0",64)
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        broken = deepcopy(full)
        broken["records"][1]["witness"]["linear_columns"][1] = 0
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        # Correct counts, valid APN LUTs and distinct literal functions do not
        # suffice: quotient cosets must also be nonzero and distinct.
        broken = deepcopy(full)
        direction = first(filter(!iszero,Int.(F.lut) .⊻ broken["records"][1]["candidate_lut"]))
        broken["complete"] = false
        broken["records"][1]["status"] = "undecided"
        broken["records"][1]["candidate_lut"] = Int.(F.lut) .⊻ direction
        broken["records"][1]["candidate_sha256"] =
            bytes2hex(sha256(UInt8.(broken["records"][1]["candidate_lut"])))
        @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
        offset = 0
        for row in full["directions"]
            if row["neighbors"] >= 2
                broken = deepcopy(full)
                broken["complete"] = false
                record = broken["records"][offset+2]
                record["status"] = "undecided"
                record["candidate_lut"] = broken["records"][offset+1]["candidate_lut"] .⊻ row["direction"]
                record["candidate_sha256"] = bytes2hex(sha256(UInt8.(record["candidate_lut"])))
                @test_throws ArgumentError bgp_audit_switching_parent(broken,parent,census;parent_index=1)
                break
            end
            offset += row["neighbors"]
        end
    end

    @testset "incomplete coverage stays incomplete" begin
        partial = fixture(max_neighbors=1)
        checked = bgp_audit_switching_parent(partial,parent,census;parent_index=1)
        @test !checked.complete
        @test !checked.constructor_complete
        @test checked.neighbors == 1
        unknown = deepcopy(full)
        unknown["complete"] = false
        unknown["records"][1]["status"] = "undecided"
        checked = bgp_audit_switching_parent(unknown,parent,census;parent_index=1)
        @test !checked.complete
        @test checked.constructor_complete
        unknown["complete"] = true
        @test_throws ArgumentError bgp_audit_switching_parent(unknown,parent,census;parent_index=1)
    end

    @testset "directory totals and connection graph" begin
        mktempdir() do temporary
            directory = joinpath(temporary,"fixture")
            mkpath(directory)
            open(joinpath(directory,"parent_001.toml"),"w") do io
                TOML.print(io,full)
            end
            summary = Dict{String,Any}("census_sha256"=>census.sha256,
                "source_hashes"=>identity["source_hashes"],"seed"=>940,
                "checkpoint_directory"=>"fixture","parents_processed"=>1,
                "parents_completed"=>1,"complete"=>false,
                "evaluations"=>full["evaluations"],"comparisons"=>full["comparisons"],
                "nodes"=>full["nodes"],"unique_matched_luts"=>length(full["records"]),
                "edges"=>[[1,1]],"components"=>[[1]],"conjecture_proved"=>false)
            path = joinpath(temporary,"summary.toml")
            write_summary() = open(path,"w") do io
                TOML.print(io,summary)
            end
            write_summary()
            checked = bgp_audit_switching_results(path,census)
            @test !checked.complete
            @test checked.parents_checked == checked.complete_parents == 1
            @test checked.components == [[1]]
            summary["edges"] = Vector{Int}[]
            write_summary()
            @test_throws ArgumentError bgp_audit_switching_results(path,census)
            summary["edges"] = [[1,1]]
            summary["evaluations"] += 1
            write_summary()
            @test_throws ArgumentError bgp_audit_switching_results(path,census)
            summary["evaluations"] -= 1
            summary["conjecture_proved"] = true
            write_summary()
            @test_throws ArgumentError bgp_audit_switching_results(path,census)
        end
    end
end
