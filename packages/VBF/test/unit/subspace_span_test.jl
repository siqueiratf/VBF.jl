@testitem "subspace_span_test" begin
    using VBF
    @test span_from_basis(UInt32[1,2])==UInt32[0,1,2,3]
    basis=UInt128[UInt128(1)<<63,UInt128(1)<<127]
    @test span_from_basis(basis)==UInt128[0,basis[1],basis[2],xor(basis...)]
    @test eltype(span_from_basis(basis))==UInt128
    @test span_from_basis(@view basis[:])==span_from_basis(basis)
    @test span_from_basis(UInt128[])==UInt128[0]
    @test all(parity(x&UInt128(7))==0 for x in span_from_basis(basis))
end
