@testitem "quadratic_space_equivalence" begin
    using VBF, Test, Random
    QE = VBF.QuadraticExtensions

    @testset "Boolean diagonal terms and polar pullback" begin
        G = QE.geometry(2)
        # x1*x2 at (x1+x2,x2) acquires x2^2=x2. Its quadratic
        # coefficient remains x1*x2; equality of full LUTs would be wrong.
        A = UInt16[1, 3]
        q = UInt32(1)
        @test transform_quadratic_form(G, q, A) == q
        values = QE.lut_from_coeffs(G, UInt16[1])
        @test values[F2LinearMap{2,UInt16}(A)(2)+1] != values[2+1]

        rng = Xoshiro(20261018)
        for n in 2:6, _ in 1:3
            H = QE.geometry(n)
            L = random_linear_permutation(rng, Val(n))
            form = rand(rng, UInt32) & ((UInt32(1) << H.N) - UInt32(1))
            transformed = transform_quadratic_form(H, form, L.cols)
            original_lut = QE.lut_from_coeffs(H, QE.forms_to_coeffs(UInt32[form], H.N))
            image_lut = QE.lut_from_coeffs(H, QE.forms_to_coeffs(UInt32[transformed], H.N))
            drift = UInt16[original_lut[L(x)+1] ⊻ image_lut[x+1] for x in 0:(1<<n)-1]
            @test drift[1] == 0
            # A function is linear iff its basis values reconstruct every value.
            for x in 0:(1<<n)-1
                expected = UInt16(0)
                for i in 0:n-1
                    isodd(x >> i) && (expected ⊻= drift[(1<<i)+1])
                end
                @test drift[x+1] == expected
            end
        end
    end

    @testset "basis independence and replayable transporters" begin
        G = QE.geometry(4)
        V = UInt32[1, 10]
        A = UInt16[3, 2, 4, 8]
        W = transform_quadratic_space(G, V, A)
        @test W != first(QE.rref(V))
        @test transform_quadratic_space(G, UInt32[11, 10, 1, 0], A) == W
        @test quadratic_space_rank_signature(G, V) == quadratic_space_rank_signature(G, W)
        @test verify_quadratic_space_transporter(G, V, W, A)
        @test !verify_quadratic_space_transporter(G, V, W, UInt16[1, 2, 4, 8])
        @test !verify_quadratic_space_transporter(G, V, W, UInt16[3, 3, 4, 8])
        @test !verify_quadratic_space_transporter(G, V, W, UInt16[3, 2, 4])
        @test !verify_quadratic_space_transporter(G, V, W, Int[-1, 2, 4, 8])
        @test !verify_quadratic_space_transporter(G, V, W, UInt16[16, 2, 4, 8])
        outcome = quadratic_space_transporter(G, V, W; timeout_seconds=10.0)
        @test outcome isa Found
        if outcome isa Found
            columns = only(search_solutions(outcome))
            @test verify_quadratic_space_transporter(G, V, W, columns)
            @test transform_quadratic_space(G, W,
                inv(F2LinearMap{4,UInt16}(columns)).cols) == first(QE.rref(V))
        end
        # Full-form drift is irrelevant, and changes of output basis are free.
        identical = quadratic_space_transporter(G, V, UInt32[11, 1])
        @test identical isa Found
        @test only(search_solutions(identical)) == UInt16[1, 2, 4, 8]
        empty = quadratic_space_transporter(G, UInt32[], UInt32[0])
        @test empty isa Found
    end

    @testset "inequivalence and strict uncertainty semantics" begin
        G = QE.geometry(4)
        V, W = UInt32[1, 10], UInt32[1, 8]
        separated = quadratic_space_transporter(G, UInt32[1], UInt32[33])
        @test proves_emptiness(separated) # rank two versus rank four
        @test proves_emptiness(quadratic_space_transporter(G, V, UInt32[1]))
        # Both have seven rank-two nonzero forms. The common polar radical
        # has dimension zero for the star and one for the triangle, so a
        # matching rank histogram must not authorize a merge.
        star, triangle = UInt32[1, 2, 4], UInt32[1, 2, 8]
        @test quadratic_space_rank_signature(G, star) == quadratic_space_rank_signature(G, triangle)
        @test proves_emptiness(quadratic_space_transporter(G, star, triangle;
            timeout_seconds=10.0))
        for (options, reason) in (((max_nodes=0,), :nodes),
                                  ((timeout_seconds=0.0,), :time),
                                  ((max_memory_bytes=0,), :memory))
            outcome = quadratic_space_transporter(G, V, W; options...)
            @test outcome isa BudgetHit
            @test outcome.where_it_stopped.reason == reason
            @test !proves_emptiness(outcome)
        end
        for options in ((max_nodes=-1,), (timeout_seconds=-1.0,),
                        (timeout_seconds=NaN,), (max_memory_bytes=-1,),
                        (algorithm=:unknown,))
            @test_throws ArgumentError quadratic_space_transporter(G, V, W; options...)
        end
        @test_throws ArgumentError transform_quadratic_form(G, 64, UInt16[1, 2, 4, 8])
        @test_throws ArgumentError transform_quadratic_space(G, V, UInt16[1, 1, 4, 8])
        @test_throws ArgumentError quadratic_space_rank_signature(G, UInt32[1, 2, 4, 8, 16])
        @test_throws ArgumentError quadratic_space_transporter(G, UInt32[1, 2, 4, 8, 16], W)
    end

    @testset "eight-variable five-space generated conjugate" begin
        G = QE.geometry(8)
        rng = Xoshiro(525208)
        V = first(QE.rref(rand(rng, UInt32, 5) .& UInt32(0x0fffffff)))
        @test length(V) == 5
        L = random_linear_permutation(rng, Val(8))
        W = transform_quadratic_space(G, V, L.cols)
        @test quadratic_space_rank_signature(G, V) == quadratic_space_rank_signature(G, W)
        outcome = quadratic_space_transporter(G, V, W; max_nodes=10_000, timeout_seconds=5.0)
        @test outcome isa Found
        if outcome isa Found
            @test verify_quadratic_space_transporter(G, V, W, only(search_solutions(outcome)))
        end
    end
end
