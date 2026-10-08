# The fast last-step counters FL, FL2, FL3 against the slow reference QK2.
"Random pure quadratic APN function on nv variables (retry dead ends)."
function random_apn(rng, nv, m)
    while true
        lw, C, _ = QK.probe(rng, nv, m)
        isfinite(lw) && return C[1:nv, 1:nv]
    end
end

@testset "fast exact last-step counters" begin
    rng = Xoshiro(4242)
    ncases = 0
    nzero = 0
    cases = [(3, 4), (3, 5), (4, 4), (4, 5), (4, 6), (5, 5), (5, 6), (6, 6)]
    # Four random functions per small case, one per larger case (QK2 needs about 10 s there).
    for (nv, m) in [repeat(cases, 4); (5, 7); (6, 7)]
        C = random_apn(rng, nv, m)
        e0, _ = QK2.completions(C, nv, m)
        e1, _ = FL.count_completions(C, nv, m)
        e2, _ = FL2.count_completions(C, nv, m)
        e3, _ = FL3.count_completions(C, nv, m)
        @test e1 == e0
        @test e2 == e0
        @test e3 == e0
        # Free action of Lambda (Lemma 4.5): e is a multiple of 2^nv.
        @test e0 % (1 << nv) == 0
        # Canonical solutions: one per orbit; each extends C to an APN function.
        _, sols = FL3.count_completions(C, nv, m; want_solution = true)
        @test length(sols) << nv == e0
        _, sols2 = FL2.count_completions(C, nv, m; want_solution = true)
        @test length(sols2) << nv == e0
        for L in first(sols, 5)
            D = zeros(UInt16, nv + 1, nv + 1)
            D[1:nv, 1:nv] = C
            for k in 1:nv
                D[k, nv + 1] = L[k]
                D[nv + 1, k] = L[k]
            end
            @test QK.images(D, nv + 1, m) !== nothing
        end
        ncases += 1
        nzero += e0 == 0
    end
    @test ncases == 34
    @test nzero >= 4        # (5,5) -> (6,5) has no APN completion
end
