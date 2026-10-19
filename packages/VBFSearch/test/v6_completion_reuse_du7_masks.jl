using VBF, Test
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_du7)...) do
    include(joinpath(@__DIR__,"..","tools","analysis","v6_completion_reuse_du7_masks.jl"))
end
using .V6CompletionReuseDU7Masks

@testset "Packed DU7 signatures equal the direct point-flat obstruction" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4)
    for V in (UInt32[1],UInt32[0x21])
        R,piv=Q.rref(V);_,Qmask=Q.pivots_masks(R,piv,G.N)
        C=UInt32[];Cidx=Int[]
        for (i,w) in enumerate(G.flats)
            all(r->!Q.par(w&r),R) || continue
            push!(C,Q.pext(w,Qmask));push!(Cidx,i)
        end
        L=UInt32.(0:31)
        plan=V6CompletionReuseDU7Masks.prepare(C,Cidx,G,L)
        @test plan!==nothing
        for x in UInt32(1):UInt32(31)
            count_x=zeros(Int,16)
            for (c,fi) in zip(C,Cidx)
                Q.par(c&x) && continue
                for p in G.flatpts[fi];count_x[p+1]+=1;end
            end
            for t in L
                point_counts=zeros(Int,16)
                for (c,fi) in zip(C,Cidx)
                    (Q.par(c&x)||Q.par(c&t)) && continue
                    for p in G.flatpts[fi];point_counts[p+1]+=1;end
                end
                bad=maximum(point_counts)>1
                rejected=V6CompletionReuseDU7Masks.reject(plan,
                    V6CompletionReuseDU7Masks.state(plan,x),plan.states[Int(t)+1])
                @test !rejected || bad
                maximum(count_x)<=3 && @test rejected==bad
            end
        end
    end
end

@testset "DU7 masks preserve V5 outputs with caps and selected cosets" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);beta=Q.bent_fourier(G)
    for V in (UInt32[1],UInt32[0x21]),need in 0:2,du_filter in (false,true),kernel in (0,23)
        expected=V6CompletionReuseDU7Masks.T.reference_v5_extensions(G,V,need,Q.V5Work(5,4);beta,du_filter,max_kernel=kernel)
        native=Q.v5_extensions(G,V,need,Q.V5Work(5,4);beta,du_filter,max_kernel=kernel)
        V5PrototypeBaselines.native_parity(expected,native)
        actual=V6CompletionReuseDU7Masks.du7_v5_extensions(G,V,need,Q.V5Work(5,4);
            beta,du_filter,max_kernel=kernel)
        @test expected.Ss==actual.Ss
        # Skipping a provably inconsistent system cannot introduce a kernel cap.
        @test expected.capped==actual.capped
        @test expected.ncand==actual.ncand
        @test expected.nT==actual.nT
    end
end
