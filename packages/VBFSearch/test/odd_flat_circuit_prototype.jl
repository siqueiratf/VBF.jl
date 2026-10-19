using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/odd_flat_circuit_prototype.jl"))
const OFC=OddFlatCircuitPrototype
const OFA=OFC.A
const OFQ=VBF.QuadraticExtensions

@testset "Odd-five circuit witnesses and packed annihilators replay exactly" begin
    G=OFQ.geometry(4)
    found=OFA.odd_five_circuits(G.flats,collect(eachindex(G.flats)),G)
    @test found.complete
    @test !isempty(found.circuits)
    for circuit in found.circuits
        @test length(unique(circuit.flats))==5
        @test reduce(⊻,circuit.flats)==0
        @test VBF.rank_f2(collect(circuit.flats);nbits=G.N)==4
        @test OFQ.solve_ones(collect(circuit.flats),G.N)===nothing
        masks=[OFA.point_mask(G.flatpts[i]) for i in circuit.geometry_indices]
        @test OFA.pairwise_disjoint(masks,1:5)
    end
    for count in (0,1,63,64,65)
        circuits=isempty(found.circuits) ? OFA.OddFiveCircuit[] :
            [found.circuits[mod1(i,length(found.circuits))] for i in 1:count]
        L=UInt32.(0:63)
        plan=OFC.prepare(circuits,L);stats=OFC.CircuitStats()
        for x in UInt32.(0:63)
            OFC.set_x!(plan,x,stats)
            for (i,t) in enumerate(L)
                actual=OFC.rejects(plan,i,stats)
                expected=any(c->OFA.rejects(c,x,t),circuits)
                @test actual==expected
            end
        end
    end
end

@testset "Odd-five filtering preserves complete APN outputs and logical coset coverage" begin
    G=OFQ.geometry(4);V=UInt32[0x21];beta=OFQ.bent_fourier(G)
    for need in 0:2,du in (true,false),kernel in (0,8)
        expected_events=Any[];actual_events=Any[]
        expected=OFC.circuit_v5_extensions(G,V,need,OFQ.V5Work(5,4);
            beta,du_filter=du,max_kernel=kernel,du7_filter=:bitsets,circuit_filter=false,
            coset_observer=e->push!(expected_events,e))
        stats=OFC.CircuitStats()
        actual=OFC.circuit_v5_extensions(G,V,need,OFQ.V5Work(5,4);
            beta,du_filter=du,max_kernel=kernel,du7_filter=:bitsets,circuit_stats=stats,
            coset_observer=e->push!(actual_events,e))
        @test expected.Ss==actual.Ss
        @test expected.key==actual.key
        @test expected.capped==actual.capped
        @test expected.nX==actual.nX
        @test expected.nX_used==actual.nX_used
        @test expected.next_x==actual.next_x
        @test expected.du_reject==actual.du_reject
        @test expected.nT==actual.nT
        @test expected.ncand>=actual.ncand
        @test length(expected_events)==length(actual_events)
        for (a,b) in zip(expected_events,actual_events)
            @test a.Ss==b.Ss
            @test a.index==b.index
            @test a.next_x==b.next_x
            @test a.total_x==b.total_x
            @test a.representative==b.representative
            @test a.du_reject==b.du_reject
            @test a.nT==b.nT
            @test a.capped==b.capped
        end
        if expected.nX>0
            selected=unique([1,expected.nX])
            plain=OFC.circuit_v5_extensions(G,V,need,OFQ.V5Work(5,4);
                beta,du_filter=du,max_kernel=kernel,du7_filter=:bitsets,
                circuit_filter=false,selected_coset_indices=selected)
            partial=OFC.circuit_v5_extensions(G,V,need,OFQ.V5Work(5,4);
                beta,du_filter=du,max_kernel=kernel,du7_filter=:bitsets,
                selected_coset_indices=selected)
            @test plain.Ss==partial.Ss
            @test plain.capped==partial.capped
            @test partial.next_x===nothing
            @test partial.selected_coset_indices==selected
        end
    end
end
