# Relations between two concrete functions. They never merge function keys.
#
# Levels, from weakest to strongest; each says exactly what the evidence establishes:
#   :invariant_match       equal values of an EA/CCZ invariant (for example the sigma
#                          signature). A filter only: it proves no equivalence.
#   :candidate             equivalence is conjectured or under test; unresolved.
#   :invariant_separation  different values of an invariant of the stated relation. This
#                          proves that the functions are NOT equivalent under that relation,
#                          within the invariant's validity scope (for example the sigma
#                          signature for quadratic APN functions and CCZ equivalence).
#   :verified              a certificate (affine maps) that a checker accepted; proves
#                          equivalence under the stated relation.

const EQUIVALENCE_LEVELS = (:invariant_match, :candidate, :invariant_separation, :verified)
const RELATIONS = (:EA, :CCZ)

"""A relation record between two function keys, with the evidence that supports it."""
struct EquivalenceRecord
    a::FunctionKey
    b::FunctionKey
    relation::Symbol            # :EA or :CCZ
    level::Symbol               # one of EQUIVALENCE_LEVELS
    invariant::Union{Nothing,String}   # name of the invariant, for the invariant levels
    evidence::Union{Nothing,String}    # certificate path or evidence id
    function EquivalenceRecord(a, b, relation, level; invariant = nothing, evidence = nothing)
        relation in RELATIONS || throw(ArgumentError("relation must be :EA or :CCZ"))
        level in EQUIVALENCE_LEVELS || throw(ArgumentError("unknown level $level"))
        a == b && throw(ArgumentError("a relation needs two different function keys"))
        level in (:invariant_match, :invariant_separation) && invariant === nothing &&
            throw(ArgumentError("an invariant level needs the name of the invariant"))
        level == :verified && evidence === nothing &&
            throw(ArgumentError("a verified equivalence needs its certificate"))
        new(a, b, relation, level, invariant, evidence)
    end
end

"""True only when the record proves equivalence (a checked certificate)."""
proves_equivalence(r::EquivalenceRecord) = r.level == :verified

"""True only when the record proves that the two functions are not equivalent."""
proves_inequivalence(r::EquivalenceRecord) = r.level == :invariant_separation
