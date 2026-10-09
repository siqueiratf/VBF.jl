using Test, VBF, Random
if !isdefined(@__MODULE__, :gl_restriction_kappa_signature)
    include(joinpath(@__DIR__,"..","section2.jl"))
end

# Independent character sum over each affine hyperplane. Restriction Walsh
# characters have two equal-magnitude representatives a and a⊻u, so divide
# the fourth-moment sum over all ambient characters by two.
function _gl_test_restriction_pair(f,u)
    q = length(f)
    moments = Int128[]
    for c in 0:1
        fourth = Int128(0)
        for a in 0:q-1
            w = sum(isodd(Int(f.lut[x+1])+count_ones(a&x)) ? -1 : 1
                for x in 0:q-1 if isodd(count_ones(u&x)) == (c==1))
            fourth += Int128(w)^4
        end
        push!(moments,fourth)
    end
    return minmax(moments[1]//(2*Int128(q>>1)^3),
        moments[2]//(2*Int128(q>>1)^3))
end

function _gl_test_domain_affine(f::VBFTable{N,1},columns,t,output_mask,constant) where {N}
    lut = UInt8[]
    for x in 0:length(f)-1
        image = t
        for j in 0:N-1
            isodd(x >> j) && (image ⊻= columns[j+1])
        end
        push!(lut,f.lut[image+1] ⊻ UInt8(isodd(count_ones(output_mask&x))) ⊻ UInt8(constant))
    end
    return VBFTable{N,1}(lut)
end

@testset "GL Section 2 paired κ restriction lift" begin
    # All Boolean functions through dimension three, with a direct sum oracle.
    for n in 1:3, truth in 0:(1 << (1 << n))-1
        f = VBFTable{n,1}(UInt8[(truth >> x)&1 for x in 0:(1 << n)-1])
        expected = Tuple(sort!([_gl_test_restriction_pair(f,u) for u in 1:length(f)-1]))
        actual = gl_restriction_kappa_signature(f)
        @test actual == expected
        @test gl_restriction_kappa_signature(f;algorithm=:spectral) == expected
        @test actual isa Tuple
        @test length(actual) == length(f)-1
    end
    # All GL(2,2) maps, translations, and affine output additions on all
    # two-variable functions. The oracle map uses scalar XOR, not map APIs.
    matrices = [[a,b] for a in 1:3 for b in 1:3 if a != b]
    for truth in 0:15
        f = VBFTable{2,1}(UInt8[(truth >> x)&1 for x in 0:3])
        signature = gl_restriction_kappa_signature(f)
        for columns in matrices, t in 0:3, mask in 0:3, c in 0:1
            @test gl_restriction_kappa_signature(
                _gl_test_domain_affine(f,columns,t,mask,c)) == signature
        end
    end
    rng = Xoshiro(0x6c696674)
    for n in 3:6
        for _ in 1:12
            f = VBFTable{n,1}(rand(rng,UInt8[0,1],1 << n))
            columns = collect(1 << j for j in 0:n-1)
            # Elementary invertible column operations, with independent
            # affine translations and output additions.
            for _ in 1:4n
                i,j = randperm(rng,n)[1:2]
                columns[i] ⊻= columns[j]
            end
            g = _gl_test_domain_affine(f,columns,rand(rng,0:(1<<n)-1),
                rand(rng,0:(1<<n)-1),rand(rng,0:1))
            @test gl_restriction_kappa_signature(g) == gl_restriction_kappa_signature(f)
            @test gl_restriction_kappa_signature(g;algorithm=:spectral) ==
                gl_restriction_kappa_signature(f;algorithm=:literal)
        end
    end
    # Both functions are affine and every restriction has κ=2^(n-1).
    @test gl_restriction_kappa_signature(gl_boolean_anf("a+1",4)) ==
        ntuple(_->(Int128(8)//1,Int128(8)//1),15)
    @test gl_restriction_kappa_signature(gl_boolean_anf("",1)) == ((Int128(1)//1,Int128(1)//1),)
    # Identical absolute Walsh distributions, distinguished by the lift.
    # The proven EA invariance above makes differing signatures a certificate
    # of inequivalence; no external Boolean classifier is required.
    f = VBFTable{5,1}(UInt8[1,1,0,0,0,0,0,0,1,1,1,1,0,0,1,1,
        0,0,0,1,0,1,0,0,1,1,0,0,0,0,1,0])
    g = VBFTable{5,1}(UInt8[1,0,0,1,0,1,0,0,1,1,0,0,0,1,0,1,
        0,0,0,1,0,1,1,1,0,0,0,0,1,0,1,0])
    @test gl_boolean_signature(f)[2] == gl_boolean_signature(g)[2]
    @test gl_kappa(f) == gl_kappa(g)
    @test gl_restriction_kappa_signature(f) != gl_restriction_kappa_signature(g)
    # A stronger collision: even the sorted signed coefficients agree.
    h = VBFTable{5,1}(UInt8[1,1,1,0,1,1,1,1,0,0,0,1,1,1,1,0,
        1,1,1,0,0,1,0,0,0,0,0,0,0,1,1,0])
    @test sort(walsh_hadamard(1 .- 2Int.(f.lut))) ==
        sort(walsh_hadamard(1 .- 2Int.(h.lut)))
    @test gl_restriction_kappa_signature(f) != gl_restriction_kappa_signature(h)
    @test gl_restriction_kappa_signature(h;algorithm=:spectral) ==
        gl_restriction_kappa_signature(h;algorithm=:literal)
    for n in 4:7, _ in 1:20
        f = VBFTable{n,1}(rand(rng,UInt8[0,1],1 << n))
        @test gl_restriction_kappa_signature(f;algorithm=:spectral) ==
            gl_restriction_kappa_signature(f;algorithm=:literal)
    end
    @test_throws ArgumentError gl_restriction_kappa_signature(f;algorithm=:unknown)
end
