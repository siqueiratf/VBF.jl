@testitem "quadratic switching empty certificates preserve complete events and cursors" begin
    using VBF, Test

    F=gold_apn(3)
    @test VBF._sn_quadratic_empty_certificate(F)
    @test all(isempty,switching_neighbors(F))

    function capture(parent;certificate=false,kwargs...)
        checkpoints=Any[];diagnostics=Any[];observers=Any[]
        result=switching_neighbors_bounded(parent;timeout_seconds=Inf,
            quadratic_certificate=certificate,
            checkpoint=(event,value)->push!(checkpoints,(event,deepcopy(value))),
            diagnostics=(event,value)->push!(diagnostics,(event,deepcopy(value))),
            observer=(event,value)->push!(observers,(event,deepcopy(value))),kwargs...)
        (;result,checkpoints,diagnostics,observers)
    end

    plain=capture(F);certified=capture(F;certificate=true)
    @test plain.result isa Exhausted
    @test certified.result isa Exhausted
    @test search_solutions(plain.result)==search_solutions(certified.result)==typeof(F)[]
    @test nodes_visited(plain.result)==nodes_visited(certified.result)==0
    @test plain.checkpoints==certified.checkpoints
    @test plain.diagnostics==certified.diagnostics
    @test plain.observers==certified.observers==Any[]
    @test count(p->p[1]===:kernel,certified.checkpoints)==7
    for (event,value) in certified.checkpoints
        if event===:kernel
            @test value.raw_dimension==6
            @test value.quotient_dimension==0
            @test value.basis==BitVector[]
        else
            @test event===:direction_complete
            @test value.next_direction==value.direction+1
            @test value.next_combination==1
            @test value.evaluations==0
        end
    end
    @test switching_neighbors(F;quadratic_certificate=true)==switching_neighbors(F)

    @testset "eight-variable certificate matches the complete Boolean oracle" begin
        # Fixed regression control; the original 256-variable systems below
        # independently establish the claimed empty quotient in every direction.
        G=VBF.QuadraticExtensions.geometry(8)
        coefficients=UInt16[1,2,4,8,16,96,128,4,8,6,128,16,196,16,
            32,77,208,97,64,13,47,31,120,214,155,35,147,217]
        H=SBox{8}(UInt8.(VBF.QuadraticExtensions.lut_from_coeffs(G,coefficients)))
        @test differential_uniformity(H)==2
        @test VBF._sn_quadratic_empty_certificate(H)
        old=capture(H);new=capture(H;certificate=true)
        @test old.result isa Exhausted
        @test new.result isa Exhausted
        @test old.checkpoints==new.checkpoints
        @test old.diagnostics==new.diagnostics
        @test old.observers==new.observers==Any[]
        @test nodes_visited(old.result)==nodes_visited(new.result)==0
        @test count(p->p[1]===:kernel,new.checkpoints)==255
        @test all(p->p[1]!==:kernel || p[2].raw_dimension==16,new.checkpoints)
    end

    @testset "affine terms leave the exact certificate and full events unchanged" begin
        H=SBox{3}(UInt8[F.lut[(x⊻1)+1]⊻UInt8(x)⊻0x03 for x in 0:7])
        @test algebraic_degree(H)==2
        @test differential_uniformity(H)==2
        @test VBF._sn_quadratic_empty_certificate(H)
        old=capture(H);new=capture(H;certificate=true)
        @test old.checkpoints==new.checkpoints
        @test old.diagnostics==new.diagnostics
        @test search_solutions(old.result)==search_solutions(new.result)
    end

    @testset "inconclusive quadratic and nonquadratic parents retain the original path" begin
        for parent in (gold_apn(4),inverse_apn(5))
            @test !VBF._sn_quadratic_empty_certificate(parent)
            old=capture(parent;max_evaluations=3)
            new=capture(parent;certificate=true,max_evaluations=3)
            @test typeof(old.result)==typeof(new.result)
            @test search_solutions(old.result)==search_solutions(new.result)
            @test nodes_visited(old.result)==nodes_visited(new.result)
            @test old.checkpoints==new.checkpoints
            @test old.observers==new.observers
            old_regular=[d for d in old.diagnostics if d[1]!==:stop]
            new_regular=[d for d in new.diagnostics if d[1]!==:stop]
            @test old_regular==new_regular
        end
        @test !isempty(reduce(vcat,switching_neighbors(gold_apn(4));init=SBox{4,UInt8}[]))
        @test switching_neighbors(gold_apn(4);quadratic_certificate=true)==switching_neighbors(gold_apn(4))
    end

    @testset "certified directions stop and resume at ordinary persisted cursors" begin
        cursor=Ref((1,big(1)));stopped=Ref(false);events=Any[]
        checkpoint=function(event,value)
            push!(events,(event,deepcopy(value)))
            if event===:direction_complete
                cursor[]=(value.next_direction,BigInt(value.next_combination))
                value.direction==3 && (stopped[]=true)
            end
        end
        partial=switching_neighbors_bounded(F;timeout_seconds=Inf,
            quadratic_certificate=true,checkpoint,stop_requested=()->stopped[])
        @test partial isa BudgetHit
        @test partial.where_it_stopped.reason===:external
        @test nodes_visited(partial)==0
        @test cursor[]==(4,big(1))
        @test events==plain.checkpoints[1:6]
        tail=capture(F;certificate=true,start_direction=cursor[][1],start_combination=cursor[][2])
        @test tail.result isa Exhausted
        @test vcat(events,tail.checkpoints)==plain.checkpoints
        @test isempty(search_solutions(tail.result))
        done=capture(F;certificate=true,start_direction=8)
        @test done.result isa Exhausted
        @test isempty(done.checkpoints)
        @test_throws ArgumentError switching_neighbors_bounded(F;timeout_seconds=Inf,
            quadratic_certificate=true,start_direction=2,start_combination=2)
    end

    @testset "certificate scans respect budgets before emitting coverage" begin
        for kwargs in ((;timeout_seconds=0),(;max_evaluations=0),
                (;max_neighbors=0),(;stop_requested=()->true))
            stopped_result=switching_neighbors_bounded(F;quadratic_certificate=true,kwargs...)
            @test stopped_result isa BudgetHit
            @test nodes_visited(stopped_result)==0
        end
        polls=Ref(0);events=Any[]
        stopped_result=switching_neighbors_bounded(gold_apn(7);timeout_seconds=Inf,
            quadratic_certificate=true,
            stop_requested=()->begin;polls[]+=1;polls[]>=2;end,
            checkpoint=(event,value)->push!(events,(event,value)))
        @test stopped_result isa BudgetHit
        @test stopped_result.where_it_stopped.reason===:external
        @test stopped_result.where_it_stopped.resume_key["stage"]===:constraints
        @test isempty(events)
        @test nodes_visited(stopped_result)==0
        @test_throws ArgumentError switching_neighbors(SBox{3}(UInt8.(0:7));quadratic_certificate=true)
    end

    @testset "geometry publication is synchronized and per-parent rows stay private" begin
        geometry=VBF._sn_quadratic_geometry(3)
        flats=copy(geometry.flats);points=copy(geometry.flatpts)
        @test !ismutabletype(typeof(geometry))
        @test all(fetch, [Threads.@spawn(VBF._sn_quadratic_empty_certificate(F)) for _ in 1:8])
        @test geometry===VBF._sn_quadratic_geometry(3)
        @test geometry.flats==flats
        @test geometry.flatpts==points
    end
end
