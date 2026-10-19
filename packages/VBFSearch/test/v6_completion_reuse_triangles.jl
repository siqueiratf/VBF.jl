using VBF, Test
include(joinpath(@__DIR__,"fixtures","v5_prototype_baselines.jl"))
withenv(V5PrototypeBaselines.environment(:pre_du7)...) do
    include(joinpath(@__DIR__,"..","tools","analysis","v6_completion_reuse_triangles.jl"))
end
using .V6CompletionReuseTriangles

@testset "Odd three-circuit prefilter preserves full V5 completion sets" begin
    Q=VBF.QuadraticExtensions; G=Q.geometry(4); beta=Q.bent_fourier(G)
    for V in (UInt32[1],UInt32[0x21]),need in 0:2,du_filter in (false,true)
        stats=V6CompletionReuseTriangles.TriangleStats()
        expected=V6CompletionReuseTriangles.reference_v5_extensions(G,V,need,Q.V5Work(5,4);beta,du_filter,max_kernel=23)
        native=Q.v5_extensions(G,V,need,Q.V5Work(5,4);beta,du_filter,max_kernel=23)
        V5PrototypeBaselines.native_parity(expected,native)
        actual=V6CompletionReuseTriangles.triangle_v5_extensions(G,V,need,Q.V5Work(5,4);
            beta,du_filter,max_kernel=23,audit_stats=stats)
        @test expected.Ss==actual.Ss
        @test expected.capped==actual.capped
        @test expected.nX_used==actual.nX_used
        @test expected.ncand==actual.ncand
        @test actual.nT==expected.nT
    end
    # Rejected candidates are independently inconsistent under the original solver.
    pairs=NTuple{2,UInt32}[(1,2),(4,8)]
    for t in UInt32(0):UInt32(15)
        i=V6CompletionReuseTriangles.triangle_rejection(pairs,t)
        i==0 && continue
        a,b=pairs[i]
        @test all(c->!Q.par(c&t),UInt32[a,b,a⊻b])
        @test Q.solve_ones(UInt32[a,b,a⊻b],4)===nothing
    end
end
