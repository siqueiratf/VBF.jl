# Implements Definition5/Lemma6 for the square-zero involution of Section5.1.
# Pseudocode: pair a kernel basis with preimages; lift each GL(k,2) map diagonally.
# VBF API used: kernel_f2, solve_f2, F2LinearMap, rank_f2, gf_monomial_lut.

include("helpers.jl")
using VBF: F2LinearMap, rank_f2, kernel_f2, solve_f2, gf_monomial_lut

"""
Construct and verify all fixed-space GL(k,2) extensions when M=I or when
N=M+I has N²=0 and im(N)=ker(N). This covers n6Class14. Every extension is
verified invertible and commuting; unsupported Jordan types are rejected.
The construction proves extendability, without enumerating all Comm(M).
"""
function lemma6_extensions(M,n::Int)
    n <= 8 || throw(ArgumentError("bounded paper implementation requires n<=8"))
    lut=linear_map_lut(M,n)
    cols=UInt64[xor(lut[(1<<i)+1],1<<i) for i in 0:n-1]
    rows=UInt64[sum(((cols[j]>>(i-1))&1)<<(j-1) for j in 1:n) for i in 1:n]
    fixed=kernel_f2(rows;nbits=n)
    k=length(fixed)
    k<=3 || throw(ArgumentError("fixed-space GL enumeration requires k<=3"))
    identity_case=all(iszero,cols)
    basis=copy(fixed)
    if !identity_case
        2k==n && all(xor(lut[lut[x+1]+1],x)==0 for x in 0:(1<<n)-1) ||
            throw(ArgumentError("unsupported involution Jordan type; extendability not proved"))
        append!(basis,[something(solve_f2(rows,w;nbits=n)) for w in fixed])
    end
    coordinates=F2LinearMap(basis)
    rank_f2(basis;nbits=n)==n || error("paired basis is not invertible")
    coordinate_lut=Int[coordinates(x) for x in 0:(1<<n)-1]
    inverse_lut=invperm(coordinate_lut .+ 1) .- 1
    extensions=F2LinearMap[]
    restrictions=Vector{Int}[]
    for bits in 0:(1<<(k*k))-1
        c=UInt64[(bits>>(k*j))&((1<<k)-1) for j in 0:k-1]
        rank_f2(c;nbits=k)==k || continue
        L=F2LinearMap(c)
        blockcols=identity_case ? c : vcat(c,c .<< k)
        block=F2LinearMap(blockcols)
        liftcols=UInt64[coordinates(block(inverse_lut[(1<<i)+1])) for i in 0:n-1]
        lift=F2LinearMap(liftcols)
        rank_f2(liftcols;nbits=n)==n || error("extension is not invertible")
        all(lift(lut[x+1]) == lut[Int(lift(x))+1] for x in 0:(1<<n)-1) || error("invalid extension")
        all(lift(coordinates(x)) == coordinates(L(x)) for x in 0:(1<<k)-1) || error("invalid restriction")
        push!(extensions,lift)
        push!(restrictions,Int[L(x) for x in 0:(1<<k)-1])
    end
    (; n,k,fixed_basis=fixed,embedding=coordinates,extensions,restrictions,
       extendability_proved=true,method=identity_case ? "identity restrictions" : "verified paired involution basis")
end

"""
Seed the unique 3-bit affine APN-permutation representative x³ on the fixed
spaces, after constructing verified Definition5 lifts on both sides. Lemma6
and the paper's uniqueness assertion guarantee existence coverage up to affine
equivalence, not enumeration of every literal LUT. The initial LUT must be
otherwise unassigned (only F(0)=0 is allowed): the affine normalization need
not preserve arbitrary additional constraints, so their orbit coverage is
not proved.
"""
function lemma6_seed!(sbox,A,B,n)
    sbox[1] in (-1,0) && all(==(-1),view(sbox,2:length(sbox))) ||
        throw(ArgumentError("Lemma6 seeding requires an otherwise unassigned LUT (only F(0)=0 is allowed); normalization has no orbit-coverage proof for custom assignments"))
    output=lemma6_extensions(A,n)
    input=lemma6_extensions(B,n)
    input.k==output.k==3 || throw(ArgumentError("Lemma6 seeding restricted to 3-bit fixed spaces"))
    G=gf_monomial_lut(3,3)
    for x in 0:7
        i=Int(input.embedding(x))+1
        y=Int(output.embedding(G[x+1]))
        sbox[i] in (-1,y) || throw(ArgumentError("existing partial LUT conflicts with Lemma6 seed"))
        sbox[i]=y
    end
    (; input,output,restriction_lut=G,uniqueness_basis="paper Section5.1: one affine class of 3-bit APN permutations")
end
