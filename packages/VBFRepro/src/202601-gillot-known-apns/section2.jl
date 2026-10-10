# Implements Section 2 — The lift by restriction, with J = κ.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Algorithm credit: the paired-hyperplane restriction lift is described in
# Section 2, following Eric Brier and Philippe Langevin, "The classification
# of boolean cubics of nine variables," IEEE Information Theory Workshop
# (2003), cited there as BL2003. κ is their normalized
# fourth Walsh moment. This instantiation does not identify all Boolean EA classes.
#
# Pseudocode:
#   1. For each nonzero normal u, restrict f to u⋅x=0 and u⋅x=1.
#   2. Evaluate κ on both (N-1)-variable restrictions and sort the pair.
#   3. Sort all pairs, retaining multiplicity, to represent the multiset J'(f).
# VBF API used: VBFTable, parity, walsh_hadamard (through gl_kappa).

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

function _gl_restriction_kappa_pair(f::VBFTable{N,1},u::Int) where {N}
    # Choose one pivot coordinate where u is nonzero. The other coordinates
    # parametrize both affine hyperplanes; solve u⋅x=c for the pivot bit.
    N == 1 && return (Int128(1)//Int128(1),Int128(1)//Int128(1))
    pivot = trailing_zeros(u)
    low_mask = (1 << pivot)-1
    q = length(f) >> 1
    zero_side = Vector{UInt8}(undef,q)
    one_side = similar(zero_side)
    for y in 0:q-1
        free = (y & low_mask) | ((y >> pivot) << (pivot+1))
        x = free | (Int(parity(free & u)) << pivot)
        zero_side[y+1] = f.lut[x+1]
        one_side[y+1] = f.lut[(x ⊻ (1 << pivot))+1]
    end
    first = gl_kappa(VBFTable{N-1,1}(zero_side))
    second = gl_kappa(VBFTable{N-1,1}(one_side))
    return minmax(first,second)
end

function _gl_spectral_restriction_kappa_pair(W::Vector{Int},u::Int)
    # Exact optimization of the literal restrictions, not an additional
    # invariant from the paper. The ambient character sum on u⋅x=c is
    # (W(a)+(-1)^c W(a⊻u))/2. Parametrizing that hyperplane can multiply this
    # by a sign, which disappears in the fourth power. Characters a and a⊻u
    # describe the same restricted character, so enumerate one per pair.
    pivot = trailing_zeros(u)
    low_mask = (1 << pivot)-1
    q = length(W) >> 1
    zero_moment = Int128(0)
    one_moment = Int128(0)
    for y in 0:q-1
        a = (y & low_mask) | ((y >> pivot) << (pivot+1))
        first,second = W[a+1],W[(a ⊻ u)+1]
        zero_moment += Int128((first+second)÷2)^4
        one_moment += Int128((first-second)÷2)^4
    end
    denominator = Int128(q)^3
    return minmax(zero_moment//denominator,one_moment//denominator)
end

"""
    gl_restriction_kappa_signature(f::VBFTable{N,1}; algorithm=:literal)

Gillot–Langevin Section 2's lift by restriction, instantiated with `J = κ`.
Return an immutable sorted tuple of sorted pairs `(κ(f|Hᵤ), κ(f|H̄ᵤ))`,
one for every **nonzero** normal `u`, retaining multiplicities. The omitted
zero normal does not define two complementary hyperplanes.

The signature is invariant under invertible affine input substitutions and
addition of an affine Boolean function: these permute the hyperplane pairs
and preserve κ on each restriction. It is an invariant, not a complete EA
classifier, and does not reproduce the paper's 206-class Boolean classifier
or its claimed 150,355 distinct lifted values.

The default `:literal` constructs both restriction truth tables and evaluates
κ directly. The optional `:spectral` optimization reuses one full Walsh
transform: the restricted character sums are `(W(a)±W(a⊻u))/2`. It returns
exactly the same rational multiset and retains one character from each
pair `{a,a⊻u}` when accumulating fourth moments.
"""
function gl_restriction_kappa_signature(f::VBFTable{N,1};algorithm=:literal) where {N}
    algorithm in (:literal,:spectral) || throw(ArgumentError("unknown restriction algorithm"))
    pairs = if algorithm === :literal
        [_gl_restriction_kappa_pair(f,u) for u in 1:length(f)-1]
    else
        W = walsh_hadamard([iszero(v) ? 1 : -1 for v in f.lut])
        [_gl_spectral_restriction_kappa_pair(W,u) for u in 1:length(f)-1]
    end
    return Tuple(sort!(pairs))
end

if abspath(PROGRAM_FILE)==@__FILE__
    f = gl_boolean_anf("abc+abd+ac",4)
    println("Section 2 — paired κ restriction lift: ",gl_restriction_kappa_signature(f))
end
