@testset "proposition25" begin
    include(joinpath(@__DIR__, "..", "proposition25.jl"))

    for N in (6, 8)
        @testset "n=$N" begin
            F = pseudo_random_multirank_quadratic(N)
            T = storage_type(F)
            A0, B0 = _demo_maps(N, T)
            C0 = F2LinearMap{N,T}(T[T(1) << (N-1-j) for j in 0:(N-1)])
            G = build_ea_triple(F, A0, B0, C0, T(3))

            rt_F = rank_table(F)
            rt_G = rank_table(G)
            nmax = (1 << N) - 1

            checked = 0
            for r in sort(collect(keys(rank_distribution(rt_F, N))))
                ws = [a for a in 1:nmax if rt_F[a+1] == r]
                vs = [a for a in 1:nmax if rt_G[a+1] == r]
                (isempty(ws) || isempty(vs)) && continue
                w, v = ws[1], vs[1]
                rank8, rank6 = _system_ranks(F, G, [(w, v)])
                b8 = r * (2N - r)
                @test rank8 <= b8
                @test rank6 <= b8 + (N - r)
                @test rank8 == b8
                @test rank6 == b8 + (N - r)
                checked += 1
            end
            @test checked ≥ 2
        end
    end

    r = proposition25_report(io = devnull)
    @test r.all_ok
end
