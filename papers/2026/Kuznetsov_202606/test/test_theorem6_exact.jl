# Pins the exact CCZ decision behind the Theorem 6 refutation (theorem6_exact.jl).
#
# theorem6.jl locates the four candidates by sigma; a sigma match is necessary
# and not sufficient, so this test asserts the DECISION, which is what licenses
# stating the refutation as a computed fact.
#
# Runtime is about 95 s, dominated by CLASS-B at roughly 80 s. That is the same
# order as phase2_test (55 s) in this suite, so the pairs run unconditionally:
# this directory has no slow-test guard convention, and a skipped assertion here
# would defeat the point of pinning the result.
#
# Needs the tracked corpus edelpott2009_n8.sqlite only. It does NOT need the
# gitignored ccz_sigma_index.sqlite, so it runs on a fresh clone.
include(joinpath(@__DIR__, "..", "theorem6_exact.jl"))

@testset "Theorem 6 exact CCZ decision" begin
    rows = theorem6_exact_run()

    @testset "every claimed-new class was decided" begin
        @test length(rows) == 4
        @test [r.nm for r in rows] == [:class_a, :class_b, :class_c, :class_d]
        @test [r.member for r in rows] == [18, 5, 3, 4]
    end

    @testset "all four are Edel-Pott 2009 functions" begin
        # The refutation: are_ccz_equivalent routes through the complete EA
        # decision here, so each `true` is decided, not merely sigma-matched.
        for r in rows
            @test r.equivalent
        end
    end
end
