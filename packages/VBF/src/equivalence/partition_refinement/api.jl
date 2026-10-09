"""Rectangular public integration of Kaleyski–Sunde Algorithms 1–7 (2026/940)."""

"""Native CCZ decision for n-input, m-output truth tables."""
function are_ccz_equivalent(F::AbstractTruthTable,G::AbstractTruthTable;
    strategy::Symbol=:auto,on_inconclusive::Symbol=:best_effort,kwargs...)
    strategy in (:auto,:partition_refinement) || throw(ArgumentError("rectangular tables require native refinement"))
    _pr_validate_policy(on_inconclusive)
    result = partition_refinement_equivalence(F,G;kwargs...)
    return _pr_decision(result,on_inconclusive,:are_ccz_equivalent)
end

"""Native EA decision for n-input, m-output truth tables."""
function are_ea_equivalent(F::AbstractTruthTable,G::AbstractTruthTable;
    strategy::Symbol=:auto,on_inconclusive::Symbol=:best_effort,kwargs...)
    strategy in (:auto,:partition_refinement) || throw(ArgumentError("rectangular tables require native refinement"))
    _pr_validate_policy(on_inconclusive)
    result = partition_refinement_equivalence(F,G;relation=:ea,kwargs...)
    return _pr_decision(result,on_inconclusive,:are_ea_equivalent)
end

"""Verified ambient CCZ certificate for rectangular truth tables."""
function ccz_equivalence_certificate(F::AbstractTruthTable,G::AbstractTruthTable;
    on_inconclusive::Symbol=:throw,kwargs...)
    _pr_validate_policy(on_inconclusive)
    result = partition_refinement_equivalence(F,G;kwargs...)
    return _pr_witness(result,on_inconclusive,:ccz_equivalence_certificate)
end

"""Recover the existing outer/input/drift EA convention with independent widths."""
function ea_equivalence_certificate(F::AbstractTruthTable{N,M},G::AbstractTruthTable;
    strategy::Symbol=:auto,on_inconclusive::Symbol=:throw,kwargs...) where {N,M}
    strategy in (:auto,:partition_refinement) || throw(ArgumentError("rectangular tables require native refinement"))
    _pr_validate_policy(on_inconclusive)
    result = partition_refinement_equivalence(F,G;relation=:ea,kwargs...)
    A = _pr_witness(result,on_inconclusive,:ea_equivalence_certificate)
    (A === nothing || ismissing(A)) && return A
    T = storage_type(F)
    mask = (UInt32(1)<<M)-UInt32(1)
    outer = F2LinearMap{M,T}(T[A.linear.cols[i]&mask for i in 1:M])
    input = F2LinearMap{N,UInt32}(UInt32[A.linear.cols[M+i]>>M for i in 1:N])
    inverse = inv(input)
    inner = F2AffineMap(inverse,inverse(A.constant>>M))
    drift_map = F2LinearMap{N+M,UInt32}(vcat(zeros(UInt32,M),
        UInt32[A.linear.cols[M+i]&mask for i in 1:N]))
    drift = VBFTable{N,M,T}(T[drift_map(UInt32(inner(x))<<M) ⊻ (A.constant&mask)
        for x in 0:(length(F)-1)])
    return (L1=outer,A2=is_linear(inner) ? inner.linear : inner,A_drift=drift)
end
