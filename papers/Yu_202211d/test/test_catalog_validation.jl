using Test

@testset "Catalog: yuperrin2022_qam_n8 member count" begin
    db = load_catalog()
    try
        info = corpus_info(db, CORPUS_NAME)
        if info === nothing
            @warn "corpus '$(CORPUS_NAME)' not registered in catalog; skipping count test"
        else
            n = corpus_length(db, CORPUS_NAME)
            @test n == EXPECTED_COUNT
        end
    finally
        close(db)
    end
end

@testset "Catalog: first and last members are quadratic APN QAMs" begin
    db = load_catalog()
    try
        n_total = corpus_length(db, CORPUS_NAME)
        if n_total == 0
            @warn "corpus '$(CORPUS_NAME)' empty; skipping member checks"
        else
            for idx in (1, n_total)
                F = corpus_function(db, CORPUS_NAME, idx)
                @test differential_uniformity(F) == 2
                @test algebraic_degree(F) == 2
                @test is_qam(quadratic_apn_matrix(F))
            end
        end
    finally
        close(db)
    end
end
