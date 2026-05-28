"""
Quadratic-APN-specific equivalence helpers.

This file holds the quadratic-APN helper that depends only on already-
ported machinery. The ortho-derivative-based automorphism /
EA-mapping functions (`automorphisms_from_ortho_derivative`,
`ea_mappings_from_ortho_derivative`, `get_walsh_zeroes_spaces_quadratic_apn`,
`enumerate_ea_classes_apn_quadratic`) require the CCZ graph machinery
(block decomposition, `EA_mapping`, graph image / xor-equivalence) and
live alongside it in the CCZ layer (Phase 12).
"""

"""
    ccz_equivalent_quadratic_function(F::SBox{N,T}) -> Union{SBox{N,T}, Nothing}

A quadratic (algebraic-degree-2) function in the CCZ-class of `F`, or
`nothing` if the CCZ-class contains no quadratic representative.

Many APN functions of higher algebraic degree are CCZ-equivalent to a
quadratic one; this finds such a representative so that the fast
quadratic-only invariants (ortho-derivative, etc.) become applicable.
Ports `cpp_ccz_equivalent_quadratic_function`: scan
[`enumerate_ccz_class`](@ref) for the first degree-2 member.
"""
function ccz_equivalent_quadratic_function(F::SBox{N,T}) where {N,T}
    for f in enumerate_ccz_class(F)
        algebraic_degree(f) == 2 && return f
    end
    return nothing
end
