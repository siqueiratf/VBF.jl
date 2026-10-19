using Test,VBF
include(joinpath(@__DIR__,"../tools/analysis/u6_obstructions.jl"))
@testset "Singular three-space obstruction agrees with exhaustive n4 completion" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);work=Q.ExtWork(4,4)
    certificates=0;existing=0;unchecked=0
    for U in Q.each_rref(G.N,2)
        found=U6Obstructions.inspect(G,U;prioritize_du=false)
        if found.status=="singular_three_space"
            certificates+=1
            @test U6Obstructions.verify_certificate(G,U,found.certificate)
            result=Q.extensions(G,U,work;du_filter=false,max_kernel=20,max_T=100000)
            @test !result.capped
            @test isempty(result.Ts)
        elseif found.status=="existing_du_obstruction"
            existing+=1
        else
            unchecked+=1
        end
    end
    @test certificates+existing+unchecked==651
    @test certificates>0
    @test !U6Obstructions.verify_certificate(G,UInt32[1,2],[1,1,2])
end
