@testitem "finite_field_generators" begin
using VBF, Test
@test IRREDUCIBLE_POLYNOMIALS===PRIMITIVE_POLYNOMIALS
@test irreducible_polynomial(8)==primitive_polynomial(8)==283
@test gf_multiplicative_order(2,8)==51
@test gf_primitive_element(8)==3
@test gf_primitive_element(8;modulus=conway_polynomial(8))==2
for n in 2:16
    g=gf_primitive_element(n)
    @test gf_multiplicative_order(g,n)==(1<<n)-1
    n==8 || @test g==2
end
@test_throws ArgumentError gf_multiplicative_order(0,8)
@test_throws ArgumentError gf_multiplicative_order(256,8)
@test_throws ArgumentError gf_primitive_element(8;modulus=0x101)
@test_throws ArgumentError gf_primitive_element(8;modulus=0x11)
# The default AES bit basis stays unchanged, but Gold's 85 canonical triples
# must use a genuine cube root, not 2^85=1 under the AES modulus.
F=gold_apn(8,1)
@test canonical_triplicate(F)!==nothing
@test canonical_triplicate(F).tN==85
end
