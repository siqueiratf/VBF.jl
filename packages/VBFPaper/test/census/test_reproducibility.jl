# RNG scheme: sample i uses Xoshiro(seed * 100003 + th), th = ((i-1) mod T) + 1,
# T = number of RNG streams (default: number of threads).
@testset "reproducibility" begin
    a = sample_chunk(60, 3; n = 6, m = 6)
    b = sample_chunk(60, 3; n = 6, m = 6)
    @test a == b
    # One stream equals the corresponding lines of a T-thread chunk.
    T = 4
    res = fill("", 60)
    for th in 1:T
        sample_stream!(res, 3, th, T, 6, 6)
    end
    if nthreads() == T
        @test res == a
    end
    @test all(!isempty, res)
    # T streams on any number of threads give the same chunk.
    @test sample_chunk(60, 3; n = 6, m = 6, streams = T) == res
    @test sample_chunk(60, 3; n = 6, m = 6, streams = 1) != res

end

@testset "Sampling resumes only with matching identity and chunk digests" begin
    mktempdir() do dir
        kwargs=(outdir=dir,first_seed=1,nchunks=1,samples=20,threads=nthreads(),streams=2,n=5,m=5,io=devnull)
        run_sampling(;kwargs...)
        file=joinpath(dir,"c1.tsv");before=read(file)
        run_sampling(;kwargs...)
        @test read(file)==before
        @test length(TOML.parsefile(joinpath(dir,"sampling.toml"))["chunks"])==1
        @test_throws ErrorException run_sampling(;kwargs...,samples=21)
        @test_throws ErrorException run_sampling(;kwargs...,streams=3)
        write(file,"tampered")
        @test_throws ErrorException run_sampling(;kwargs...)
    end
end
