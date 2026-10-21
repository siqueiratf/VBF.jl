@testitem "Int32 Walsh prefix fusion" begin
using VBF,Test,Random

# Int64 retains the generic transform and cannot overflow on these Int32 inputs.
# Reduce only the completed reference transform modulo 2^32, independently of
# the fused operation grouping, to check the fixed-width arithmetic contract.
function reference32(source)
    wide=Int64.(source)
    walsh_hadamard!(wide)
    map(x->x % Int32,wide)
end

function check32(source;threaded=false)
    expected=reference32(source)
    original=copy(source)
    vector=copy(source)
    result=walsh_hadamard!(vector;threaded)
    @test result===vector
    @test result isa Vector{Int32}
    @test vector==expected
    @test source==original
end

@testset "exact small transforms and all Boolean eight-element inputs" begin
    for count in (1,2,4)
        check32(fill(typemin(Int32),count))
        check32(fill(typemax(Int32),count))
    end
    for bits in 0:255
        check32(Int32[iszero(bits & (1<<i)) ? 1 : -1 for i in 0:7])
    end
end

@testset "full-width wrap and chunk boundaries" begin
    rng=Xoshiro(940)
    for power in 3:16
        count=1<<power
        for source in (rand(rng,Int32,count),fill(typemin(Int32),count),
                       fill(typemax(Int32),count),
                       Int32[isodd(i) ? typemin(Int32) : typemax(Int32) for i in 1:count])
            check32(source)
        end
    end
    # A complete transform crosses four prefix chunks at the native n=8 scale.
    points=zeros(Int32,1<<16)
    for x in 0:255
        points[(x<<8)+rand(rng,0:255)+1]=rand(rng,Int32(1):Int32(8191))
    end
    planes=zeros(Int32,1<<16)
    for index in randperm(rng,length(planes))[1:8192]
        planes[index]=rand(rng,Int32(-8191):Int32(8191))
    end
    check32(points)
    check32(planes)
    check32(points;threaded=true) # Remains serial below the existing threshold.
    check32(planes;threaded=true)
end

@testset "validation, other signed widths and strided input contract" begin
    for count in (0,3,5,6,17)
        vector=zeros(Int32,count)
        expected=count==0 ? "walsh_hadamard!: empty input" :
            "walsh_hadamard!: length $count is not a power of 2"
        exception=try
            walsh_hadamard!(vector)
            nothing
        catch error
            error
        end
        @test exception isa ArgumentError
        @test exception.msg==expected
        @test vector==zeros(Int32,count)
    end
    rng=Xoshiro(941)
    for T in (Int8,Int16,Int64,Int128,BigInt),power in 0:6
        source=T.(rand(rng,-1:1,1<<power))
        expected=BigInt.(source)
        walsh_hadamard!(expected)
        result=copy(source)
        @test walsh_hadamard!(result)===result
        @test eltype(result)===T
        @test result==T.(expected)
    end
    vector=Int32[1:16;]
    snapshot=copy(vector)
    @test_throws MethodError walsh_hadamard!(view(vector,1:2:16))
    @test vector==snapshot
end

@testset "existing threaded dispatch and independent callers" begin
    rng=Xoshiro(942)
    # The original threaded branch still owns arrays of at least 2^18 elements.
    check32(rand(rng,Int32,1<<18);threaded=true)
    inputs=[rand(rng,Int32,1<<16) for _ in 1:4]
    expected=map(reference32,inputs)
    tasks=map(inputs) do source
        Threads.@spawn walsh_hadamard!(copy(source))
    end
    @test map(fetch,tasks)==expected
end
end
