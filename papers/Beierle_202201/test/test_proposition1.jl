@testset "proposition1_test" begin
    include(joinpath(@__DIR__, "..", "proposition1.jl"))

    # ortho_derivative_signature: returns sorted pairs (CCZ-invariant)
    f = gold_apn(8)
    sig = ortho_derivative_signature(f)
    @test sig isa Vector
    @test !isempty(sig)
    # Signature is sorted by key
    @test issorted([p.first for p in sig])

    # Two CCZ-inequivalent functions have different signatures
    # (Gold n=8 vs first function in the dataset)
    g = first(stream_dataset(joinpath(@__DIR__, "..", "inputs", "apn_8bit.txt")))
    sig_g = ortho_derivative_signature(g)
    @test sig_g != sig   # the new instance is not CCZ-equivalent to Gold

    # ccz_distinctness: small sample, all distinct from Gold
    r = ccz_distinctness(devnull; sample_size = 3, seed = 42)
    @test r.distinct_from_gold == 3
    @test r.pairwise_distinct
    @test r.exhaustive == false
    @test r.sample_size == 3
end