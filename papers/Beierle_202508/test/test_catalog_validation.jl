@testset "catalog diagnostics" begin
    r = catalog_count_comparison()
    @test r.paper_prior_classes == 32_892
    @test r.local_total >= r.paper_prior_classes
    @test haskey(r.counts, "yuperrin2022_qam_n8")
end
