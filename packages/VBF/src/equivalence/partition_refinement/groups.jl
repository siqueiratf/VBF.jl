"""
Permutation-group machinery for Kaleyski–Sunde Sections 5 and 8.2.

Deterministic Schreier–Sims: orbit transversals, sifting, Schreier generators
and point stabilizers. Actions use one-based graph storage indices; packed
ambient points keep VBF's mathematical convention. No ambient permutation of
degree 2^(2n) is stored. Every group is owned by its search.
"""

const _PRTransversals = Vector{Union{Nothing,Vector{Int}}}

"""A base and strong generating set with exact orbit transversals."""
mutable struct _PRPermutationGroup
    degree::Int
    base::Vector{Int}
    strong::Vector{Vector{Int}}
    transversals::Vector{_PRTransversals}
    inverses::Vector{_PRTransversals}
    orbits::Vector{Vector{Int}}
    closed::Bool
end

_PRPermutationGroup(n::Int) = _PRPermutationGroup(
    n, Int[], Vector{Int}[], _PRTransversals[], _PRTransversals[], Vector{Int}[], true)

@inline _pr_perm_identity(p) = all(i -> p[i] == i, eachindex(p))
_pr_perm_compose(p, q) = Int[p[i] for i in q]

function _pr_perm_inverse(p)
    q = similar(p)
    @inbounds for i in eachindex(p)
        q[p[i]] = i
    end
    return q
end

"""Orbit of b, with t[q](b)=q and its inverse for each reached point q."""
function _pr_orbit_transversals(n, generators, b, budget)
    trans = _PRTransversals(nothing, n)
    inverses = _PRTransversals(nothing, n)
    trans[b] = collect(1:n)
    inverses[b] = trans[b]
    orbit = Int[b]
    head = 1
    while head <= length(orbit)
        _pr_check!(budget) || return nothing
        q = orbit[head]
        for g in generators
            r = g[q]
            trans[r] === nothing || continue
            t = _pr_perm_compose(g, trans[q])
            trans[r], inverses[r] = t, _pr_perm_inverse(t)
            push!(orbit, r)
        end
        head += 1
    end
    return trans, inverses, orbit
end

"""Rebuild the orbit tables of the current strong generating set."""
function _pr_group_rebuild!(H::_PRPermutationGroup, budget)
    trans, inverses, orbits = _PRTransversals[], _PRTransversals[], Vector{Int}[]
    for level in eachindex(H.base)
        gens = filter(g -> all(i -> g[H.base[i]] == H.base[i], 1:(level-1)), H.strong)
        data = _pr_orbit_transversals(H.degree, gens, H.base[level], budget)
        data === nothing && return false
        t, invt, orbit = data
        push!(trans, t); push!(inverses, invt); push!(orbits, orbit)
    end
    H.transversals, H.inverses, H.orbits = trans, inverses, orbits
    return true
end

"""Sift p through the chain; return its residue and first unrepresented level."""
function _pr_group_sift(H::_PRPermutationGroup, p; firstlevel::Int = 1)
    residue = p
    for level in firstlevel:length(H.base)
        t = H.inverses[level][residue[H.base[level]]]
        t === nothing && return residue, level
        residue = _pr_perm_compose(t, residue)
    end
    return residue, length(H.base) + 1
end

"""Identity sifting is a membership proof, even for a partially built chain."""
function _pr_group_contains(H::_PRPermutationGroup, p)
    residue, _ = _pr_group_sift(H, p)
    return _pr_perm_identity(residue)
end

function _pr_group_extend!(H, residue, level)
    if level > length(H.base)
        push!(H.base, findfirst(i -> residue[i] != i, eachindex(residue)))
    end
    push!(H.strong, residue)
    H.closed = false
end

"""Close the stabilizer chain under Schreier generators, checking the deadline."""
function _pr_group_close!(H::_PRPermutationGroup, budget)
    while _pr_check!(budget)
        _pr_group_rebuild!(H, budget) || return false
        extended = false
        for level in eachindex(H.base)
            gens = filter(g -> all(i -> g[H.base[i]] == H.base[i], 1:(level-1)), H.strong)
            for q in H.orbits[level]
                _pr_check!(budget) || return false
                for g in gens
                    # t[g(q)]^-1 * g * t[q] fixes the current base point.
                    s = _pr_perm_compose(H.inverses[level][g[q]],
                        _pr_perm_compose(g, H.transversals[level][q]))
                    residue, failed = _pr_group_sift(H, s; firstlevel = level + 1)
                    _pr_perm_identity(residue) && continue
                    _pr_group_extend!(H, residue, failed)
                    extended = true
                    break
                end
                extended && break
            end
            extended && break
        end
        if !extended
            H.closed = true
            return true
        end
    end
    return false
end

"""Adjoin a verified permutation; completion never enumerates group elements."""
function _pr_group_add!(H::_PRPermutationGroup, p, budget)
    _pr_check!(budget) || return false
    residue, level = _pr_group_sift(H, p)
    _pr_perm_identity(residue) && return false
    _pr_group_extend!(H, residue, level)
    _pr_group_close!(H, budget)
    return true
end

"""Exact order of a closed chain; an interrupted construction has unknown order."""
_pr_group_order(H::_PRPermutationGroup) = H.closed ?
    prod(BigInt(length(orbit)) for orbit in H.orbits; init = BigInt(1)) : nothing

"""Point stabilizer, reusing the strong chain when b is its first base point."""
function _pr_group_stabilizer(H::_PRPermutationGroup, b::Int, budget)
    _pr_check!(budget) || return nothing
    all(g -> g[b] == b, H.strong) && return H
    if b == first(H.base)
        # Schreier–Sims has already computed precisely this stabilizer.
        return _PRPermutationGroup(H.degree, H.base[2:end],
            filter(g -> g[b] == b, H.strong), H.transversals[2:end],
            H.inverses[2:end], H.orbits[2:end], true)
    end
    data = _pr_orbit_transversals(H.degree, H.strong, b, budget)
    data === nothing && return nothing
    trans, inverses, orbit = data
    K = _PRPermutationGroup(H.degree)
    for q in orbit, g in H.strong
        _pr_check!(budget) || return nothing
        s = _pr_perm_compose(inverses[g[q]], _pr_perm_compose(g, trans[q]))
        _pr_group_add!(K, s, budget)
        budget.stopped === :none || return nothing
    end
    return K
end

function _pr_group_fix(H, points, budget)
    for b in points
        H = _pr_group_stabilizer(H, b, budget)
        H === nothing && return nothing
    end
    return H
end

"""Orbit labels under a certified subgroup; useful for branching on representatives."""
function _pr_group_orbits(H::_PRPermutationGroup, budget)
    labels = zeros(Int, H.degree)
    queue = Int[]
    for b = 1:H.degree
        labels[b] == 0 || continue
        empty!(queue); push!(queue, b); labels[b] = b
        head = 1
        while head <= length(queue)
            _pr_check!(budget) || return nothing
            q = queue[head]
            for g in H.strong
                r = g[q]
                labels[r] == 0 || continue
                labels[r] = b
                push!(queue, r)
            end
            head += 1
        end
    end
    return labels
end
