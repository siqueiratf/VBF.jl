"""Replayable restriction-rank obstructions to adding two APN coordinates.

Let U be a space of homogeneous quadratic components on V=F2^n. If adjoining
two Boolean coordinates gives an APN, then for every subspace H of dimension
k>=3, rank(U restricted to Lambda^2(H)) >= k-2. This tool validates one supplied
H using existing VBF restriction and GF(2) routines; it never enumerates H.

Proof. The restricted U has r independent components modulo affine terms.
After deleting affine output coordinates, any two-coordinate extension on H
therefore factors through at most r+2 output bits. Restriction and invertible
output changes preserve APN, as does adding or deleting affine/zero output
coordinates. If r<k-2, padding with zero coordinates would give APN k->k-1.
Such a map cannot exist for k>=3: every nonzero derivative would be balanced
two-to-one, so every nonzero component has Walsh coefficients of magnitude
2^(k/2). For odd k this is not an integer. For even k>=4, Fourier inversion of
an output fiber gives 2 + 2^(1-k/2) times an odd signed sum, also not an integer.
This proves the necessary rank condition. The standard no-affine-component
lemma is also stated in Carlet, Vectorial Boolean Functions, corrected online
chapter, Proposition13, printed page34; this restriction condition is derived
here without a novelty claim for that lemma.
https://www.math.univ-paris13.fr/~carlet/chap-vectorial-fcts-corr.pdf

k=3,r=0 recovers a totally singular three-space/Fano obstruction. k=4,r=1
includes a four-space carrying one nondegenerate quadratic form; its isotropic
line-intersection graph is the fifteen-vertex obstruction observed in the pilot.
"""
module QuadraticRestrictionObstruction
using VBF
const Q=VBF.QuadraticExtensions

"Validate one supplied H and return the exact restriction-rank witness."
function validate_given_H(G,U,H)
    n=G.n;k=length(H)
    3<=k<=n || throw(ArgumentError("the theorem requires 3<=dim(H)<=n"))
    all(h->h isa Integer && 0<h<1<<n,H) || throw(ArgumentError("basis outside the input space"))
    input_basis=UInt16.(H)
    VBF.rank_f2(input_basis;nbits=n)==k || throw(ArgumentError("dependent input basis"))
    all(q->q isa Integer && 0<=q<1<<G.N,U) || throw(ArgumentError("quadratic form outside the geometry"))
    forms=first(Q.rref(UInt32.(U)))
    length(forms)<=n || throw(ArgumentError("supports at most n independent component forms"))
    lut=Q.lut_from_coeffs(G,Q.forms_to_coeffs(forms,G.N))
    matrix=VBF.QuadraticRestrictions.restrict_coeffs(lut,Int.(input_basis))
    coefficients=UInt16[matrix[i,j] for i in 1:k for j in i+1:k]
    restricted_forms=Q.coord_forms(coefficients,length(forms))
    restricted_basis=first(Q.rref(restricted_forms))
    restricted_rank=length(restricted_basis)
    violation=restricted_rank<k-2
    (;status=violation ? "no_two_coordinate_apn_extension" : "no_certificate",
        violation,input_dimension=n,subspace_dimension=k,
        component_dimension=length(forms),remaining_coordinates=2,
        restricted_rank,minimum_required_rank=k-2,
        U_forms=forms,H_basis=input_basis,restricted_forms,restricted_basis)
end
end
