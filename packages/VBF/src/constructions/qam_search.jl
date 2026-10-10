"""
The QAM construction method — searching for quadratic APN functions with
coefficients in a subfield ([Ichanska, Berg, Kaleyski and Yu, 2025](@cite Ichanska_202400)).

Quadratic APN functions over `GF(2ⁿ)` whose univariate coefficients lie in the
subfield `GF(2ᵐ)` (`m ∣ n`) have a **cyclic derivative matrix**: in a normal
basis the Frobenius `x ↦ x^(2ᵐ)` shifts indices by `m`, so

    M[i+m, j+m] = M[i, j]^(2ᵐ)   (indices mod n).

The off-diagonal positions therefore split into orbits under
`(i, j) ↦ (i+m, j+m) (mod n)`, and `M` is determined by one **free field
element per orbit** ([`qam_cyclic_orbits`](@ref) / [`qam_from_cyclic`](@ref) —
the general form of the reference's per-`(n,m)` `Assign` routines). The QAM
search assigns these free variables and keeps the assignments for which `M` is a
QAM ([`is_qam`](@ref)), recovering each solution as a quadratic APN function
([`qam_to_sbox`](@ref)). Theorem 1 of the reference restricts the leading
variable to the elements whose `m`-spaced conjugates are linearly independent
([`independent_conjugate_elements`](@ref)).

[`search_qam`](@ref) runs this for a given `(n, m)`, deterministically, returning
quadratic APN representatives (one per invariant bucket by default, or per
proved EA-class with `confirm=true`). The reference accelerates the search with a
linear-permutation-group orbit reduction over each variable and Theorem-3
submatrix pruning; this port instead relies on the exact `is_qam` oracle and the
invariant bucketing of the results, which is reuse-faithful but heavier per
candidate — practical for small `(n, m)`.
"""

# Frobenius `x ↦ x^(2^t)` in GF(2ⁿ), by repeated squaring (handles x = 0).
@inline function _frobenius(x::Int, t::Int, n::Int)
    @inbounds for _ = 1:t
        x = Int(gf_pow(x, 2, n))
    end
    x
end

"""
    qam_cyclic_orbits(n, m) -> Vector{Vector{Tuple{Int,Int}}}

The orbits of the off-diagonal positions `{i,j}` (1-indexed) of an `n×n` matrix
under the index shift `(i,j) ↦ (i+m, j+m) (mod n)`. One orbit per free variable
of a `GF(2ᵐ)`-coefficient QAM; within an orbit the entries are Frobenius
conjugates (the `k`-th entry is the rep raised to `2^{m·k}`). Reproduces the
reference's per-`(n,m)` `Assign` structure.
"""
function qam_cyclic_orbits(n::Integer, m::Integer)
    m >= 1 && n % m == 0 ||
        throw(ArgumentError("qam_cyclic_orbits: need m ≥ 1 and m ∣ n"))
    key(i, j) = i < j ? (i, j) : (j, i)
    seen = Set{Tuple{Int,Int}}()
    orbits = Vector{Vector{Tuple{Int,Int}}}()
    for i = 0:(n-1), j = (i+1):(n-1)
        key(i, j) in seen && continue
        orb = Tuple{Int,Int}[]
        ci, cj = i, j
        while !(key(ci, cj) in seen)
            k = key(ci, cj)
            push!(seen, k)
            push!(orb, (k[1] + 1, k[2] + 1))         # 1-indexed
            ci = (ci + m) % n
            cj = (cj + m) % n
        end
        push!(orbits, orb)
    end
    orbits
end

"""
    qam_from_cyclic(n, m, values) -> Matrix{Int}

Build the `n×n` symmetric, zero-diagonal derivative matrix of a
`GF(2ᵐ)`-coefficient QAM from one free field element per orbit of
[`qam_cyclic_orbits`](@ref): along each orbit the entry at step `k` is the
free value raised to `2^{m·k}` (Frobenius).
"""
function qam_from_cyclic(
    n::Integer,
    m::Integer,
    values::AbstractVector{<:Integer},
)
    orbits = qam_cyclic_orbits(n, m)
    length(values) == length(orbits) || throw(
        ArgumentError(
            "qam_from_cyclic: expected $(length(orbits)) values, got $(length(values))",
        ),
    )
    M = zeros(Int, n, n)
    @inbounds for (vi, orb) in enumerate(orbits)
        v = Int(values[vi])
        for (k, (i, j)) in enumerate(orb)
            val = _frobenius(v, m * (k - 1), Int(n))
            M[i, j] = val
            M[j, i] = val
        end
    end
    M
end

"""
    independent_conjugate_elements(n, m) -> Vector{Int}

Theorem 1 of Ivković–Nikova (the set `Cat^m_I`): the nonzero `a ∈ GF(2ⁿ)` whose
`m`-spaced conjugates `a, a^(2ᵐ), …, a^(2^{m(n/m-1)})` are linearly independent
over `GF(2)`. Used to restrict the leading free variable of the QAM search.
"""
function independent_conjugate_elements(n::Integer, m::Integer)
    n % m == 0 ||
        throw(ArgumentError("independent_conjugate_elements: need m ∣ n"))
    r = n ÷ m
    out = Int[]
    conj = Vector{UInt}(undef, r)
    for a = 1:((1<<n)-1)
        x = a
        @inbounds for k = 1:r
            conj[k] = UInt(x)
            x = Int(gf_pow(x, 1 << m, Int(n)))       # x^(2ᵐ)
        end
        rank_f2(conj; nbits = Int(n)) == r && push!(out, a)
    end
    out
end

"""
    cyclic_qam_subset_representatives(n, m) -> Vector{Int}

Theorem 3 of Ivković–Nikova: one representative bitmask per orbit of the nonempty
subsets of `{1,…,n}` under the cyclic shift `i ↦ (i mod n) + ` (by `m`). For a
cyclic (`GF(2ᵐ)`-coefficient) derivative matrix the QAM condition on a row-subset
`S` and on its `m`-shift are Frobenius images of each other (equal rank), so the
QAM test need only check these representatives — the basis of the accelerated
test [`is_qam`](@ref)`(M; shift=m)`.
"""
function cyclic_qam_subset_representatives(n::Integer, m::Integer)
    nn = Int(n)
    # rotate left by m within nn bits
    shift(mask) = ((mask << m) | (mask >> (nn - m))) & ((1 << nn) - 1)
    seen = falses(1 << nn)
    reps = Int[]
    for mask = 1:((1<<nn)-1)
        seen[mask+1] && continue
        push!(reps, mask)
        s = mask
        while !seen[s+1]
            seen[s+1] = true
            s = shift(s)
        end
    end
    reps
end

# Rank of the n field elements ⊕_{j∈S} M[i,j] (rows i), over GF(2).
@inline function _qam_subset_rank(M, n::Int, mask::Int, vec::Vector{UInt})
    @inbounds for i = 1:n
        acc = 0
        s = mask
        while s != 0
            acc ⊻= M[i, trailing_zeros(s)+1]
            s &= s - 1
        end
        vec[i] = UInt(acc)
    end
    rank_f2(vec; nbits = n)
end

"""
    is_cyclic_qam(M, m) -> Bool

The Theorem-3-accelerated QAM test for a cyclic (`GF(2ᵐ)`-coefficient) derivative
matrix `M`: check the QAM rank condition only on the shift-orbit representatives
([`cyclic_qam_subset_representatives`](@ref)) rather than all `2ⁿ-1` row-subsets.
Equal to [`is_qam`](@ref)`(M)` when `M` has the cyclic structure.
"""
function is_cyclic_qam(M::AbstractMatrix{<:Integer}, m::Integer)
    n = size(M, 1)
    size(M, 2) == n ||
        throw(ArgumentError("is_cyclic_qam: matrix must be square"))
    vec = Vector{UInt}(undef, n)
    for mask in cyclic_qam_subset_representatives(n, m)
        _qam_subset_rank(M, n, mask, vec) < n - 1 && return false
    end
    true
end

# Return :added/:duplicate/:inconclusive. Equal invariants are filters only.
function _qam_add_candidate!(reps,buckets,S;confirm,timeout_seconds,max_nodes)
    mug=apn_ea_mugshot(S)
    bucket=get!(() -> eltype(reps)[],buckets,mug)
    if !isempty(bucket)
        confirm || return :duplicate
        for old in bucket
            S.lut==old.lut && return :duplicate
            outcome=partition_refinement_equivalence(S,old;relation=:ea,
                timeout_seconds,max_nodes)
            outcome isa BudgetHit && return :inconclusive
            outcome isa Found && return :duplicate
        end
    end
    push!(bucket,S);push!(reps,S)
    :added
end

function _qam_bounds(limit,max_evaluations,timeout_seconds)
    limit>=0 || throw(ArgumentError("limit must be nonnegative"))
    max_evaluations>=0 || throw(ArgumentError("max_evaluations must be nonnegative"))
    timeout_seconds>=0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
end

"""
    search_qam(n, m; limit=typemax(Int), max_evaluations=1<<22,
               confirm=false, timeout_seconds=Inf,
               equivalence_timeout_seconds=60, max_equivalence_nodes=10^6, observer=nothing)

Optional `observer(event, value)` reports `:candidate`, `:final_test` (the QAM
rank criterion), and `:apn` before deduplication. Only `:apn` carries an SBox;
observers must not mutate it.
        -> SearchOutcome{SBox{n}}

Search for quadratic APN functions over `GF(2ⁿ)` with `GF(2ᵐ)` coefficients by
the QAM method: enumerate the cyclic derivative matrices ([`qam_from_cyclic`](@ref))
— each free variable ranges over the subfield its orbit closes into — keep those
that are QAMs ([`is_qam`](@ref)), and recover each as a function
([`qam_to_sbox`](@ref)).

# Return value

A [`SearchOutcome`](@ref), **not** a bare vector — the three ways this scan can
stop are not interchangeable:

  * [`Exhausted`](@ref) — the odometer rolled all the way over. The result is
    complete under the declared deduplication policy for the cyclic subspace,
    so an empty one is a proof that
    the subspace holds no quadratic APN function.
  * [`Found`](@ref) — stopped at `limit` results. The rest of the space is
    unexamined.
  * [`BudgetHit`](@ref) — a candidate, time, or equivalence-decision budget
    was reached. Proves nothing about the remainder.

Use [`search_solutions`](@ref) to get the functions, and
[`proves_emptiness`](@ref) rather than `isempty` to ask whether the region was
shown to be empty. Reading the old bare vector could not tell a completed sweep
from a truncated one.

# Deduplication, and what the result count means

By default the results are deduplicated by [`apn_ea_mugshot`](@ref), which is
**necessary but not sufficient** for EA-equivalence. Gold `x³` and `x⁵` over `F₂⁵`
share a mugshot while being EA- and CCZ-**inequivalent**, as do `x³` and `x⁹` over
`F₂⁷` — and no cheaper invariant separates them either (their Γ- and Δ-ranks
coincide too). So the default result is **one function per mugshot**, and
`length(search_solutions(search_qam(n, m)))` is a **lower bound** on the number of
EA-classes, not a count of them — even when the outcome is `Exhausted`. At
`n = 7, m = 1` it reports 14 where the truth is 15.

Pass `confirm = true` to split each mugshot bucket with [`partition_refinement_equivalence`](@ref) at `relation=:ea`.
Only a verified witness or exhaustive negative decision can merge/split a bucket;
a confirmation budget hit yields `BudgetHit` instead of a class decision.
The retained functions represent distinct EA-classes; an `Exhausted` outcome
contains every class encountered in this declared space. Confirmation
costs an EA decision per colliding candidate, so it is affordable only for small
`(n, m)` — an exhaustive `n = 7` sweep produces ~30k candidates over 14 mugshots
and would pay tens of thousands of decisions.

Practical for small `(n,m)`; see the module docstring for the acceleration the
reference uses at `n = 8, 10`.
"""
function search_qam(
    n::Integer,
    m::Integer;
    limit::Integer = typemax(Int),
    max_evaluations::Integer = 1 << 22,
    confirm::Bool = false,
    timeout_seconds::Real = Inf,
    equivalence_timeout_seconds::Real = 60,
    max_equivalence_nodes::Int = 10^6,
    observer = nothing,
)
    _qam_bounds(limit,max_evaluations,timeout_seconds)
    _qam_bounds(typemax(Int),max_equivalence_nodes,equivalence_timeout_seconds)
    nn = Int(n)
    2<=nn<=16 || throw(ArgumentError("QAM dimensions must be between 2 and 16"))
    orbits = qam_cyclic_orbits(nn, m)
    k = length(orbits)
    # each free variable lies in the subfield GF(2^d) its orbit closes into
    subfields = Vector{Vector{Int}}(undef, k)
    for (oi, orb) in enumerate(orbits)
        d = gcd(m * length(orb), nn)
        subfields[oi] = [x for x = 0:((1<<nn)-1) if _frobenius(x, d, nn) == x]
    end
    sizes = length.(subfields)

    found = SBox{nn,_storage_for(nn)}[]
    # mugshot ⇒ the classes already found under it. With `confirm=false` a bucket
    # holds at most one function (mugshot-dedup); with `confirm=true` it holds one
    # per proved EA-class, split by the bounded exact quadratic-APN decision.
    buckets = Dict{APNEAMugshot,Vector{SBox{nn,_storage_for(nn)}}}()
    vals = zeros(Int, k)
    counter = zeros(Int, k)
    evals = 0
    # Which of the three exits fired. `:complete` means the odometer rolled all
    # the way over — the only exit that licenses an Exhausted result.
    stop = :complete
    region = SearchRegion(
        :cyclic_qam,
        "cyclic_qam(n=$nn, m=$(Int(m)))";
        size = prod(BigInt.(sizes)),
        params = Dict{String,Any}(
            "n" => nn,
            "m" => Int(m),
            "free_variables" => k,
            "subfield_sizes" => sizes,
            "confirm" => confirm,
            "solution_unit" => confirm ? "ea_class" : "mugshot_bucket",
            "equivalence_timeout_seconds" => Float64(equivalence_timeout_seconds),
            "max_equivalence_nodes" => max_equivalence_nodes,
        ),
    )
    t0 = time()
    reason=:nodes
    while true
        if time()-t0>=timeout_seconds
            stop=:budget;reason=:time;break
        elseif length(found)>=limit
            stop=:limit;break
        elseif evals>=max_evaluations
            stop=:budget;break
        end
        @inbounds for vi = 1:k
            vals[vi] = subfields[vi][counter[vi]+1]
        end
        M = qam_from_cyclic(nn, m, vals)
        observer === nothing || observer(:candidate, nothing)
        observer === nothing || observer(:final_test, nothing)
        if is_cyclic_qam(M, m)  # Theorem-3-accelerated test
            S = qam_to_sbox(M)
            observer === nothing || observer(:apn, S)
            status=_qam_add_candidate!(found,buckets,S;confirm,
                timeout_seconds=min(equivalence_timeout_seconds,max(0,timeout_seconds-(time()-t0))),
                max_nodes=max_equivalence_nodes)
            if status===:inconclusive
                evals+=1;stop=:budget;reason=:external;break
            end
        end
        evals += 1
        # odometer increment over the per-variable subfields
        p = 1
        while p <= k
            counter[p] += 1
            counter[p] < sizes[p] && break
            counter[p] = 0
            p += 1
        end
        p > k && break          # odometer rolled over ⇒ stop stays :complete
    end
    el = time() - t0
    if stop === :budget
        return BudgetHit(
            StopPoint(
                reason,
                reason===:external ? "EA confirmation inconclusive" : reason===:time ? "timeout_seconds reached" : "max_evaluations = $(Int(max_evaluations)) reached";
                resume_key = Dict{String,Any}("counter" => copy(counter)),
            ),
            region,
            found;
            nodes_visited = evals,
            elapsed_seconds = el,
        )
    elseif stop === :limit
        return Found(found, region; nodes_visited = evals, elapsed_seconds = el)
    end
    return Exhausted(region, found; nodes_visited = evals, elapsed_seconds = el)
end

"""
    search_qam_full(n; limit=typemax(Int), max_evaluations=1<<24,
                    modulus=conway_polynomial(n), confirm=false,
                    timeout_seconds=Inf, max_nodes=typemax(Int),
                    equivalence_timeout_seconds=60, max_equivalence_nodes=10^6)
        -> SearchOutcome{SBox{n}}

Construct quadratic APN functions on `F₂ⁿ` by the "guess and determine" search of
[Yu, Wang and Li (2014)](@cite Yu_201411) over the **full** symmetric QAM
space (their Algorithm 1) — distinct from [`search_qam`](@ref), which only sweeps
the much narrower cyclic subspace.
The strictly upper-triangular entries of the symmetric, zero-diagonal matrix are
filled column by column over `GF(2ⁿ)`; a partial branch is pruned the moment a
leading submatrix fails to be **proper** (every nonzero `GF(2)`-combination of
its `c` rows has rank `≥ c-1`, Cor. 2 — the necessary condition for any submatrix
of a QAM). Each completed matrix passing [`is_qam`](@ref) yields an APN function
([`qam_to_sbox`](@ref)); results are deduplicated by [`apn_ea_mugshot`](@ref) into
one representative per mugshot bucket by default. `confirm=true` uses proved
EA decisions to retain every encountered EA-class (and CCZ-class for quadratic
APNs). A failed equivalence budget returns `BudgetHit`, never a class decision.

Optional `observer(event, value)` reports completed matrices (`:candidate`),
QAM rank tests (`:final_test`), and `:apn` SBoxes before deduplication. Observers
must not mutate the SBoxes.

Returns a [`SearchOutcome`](@ref): [`Exhausted`](@ref) when the tree was walked
to the end (the representative list is complete under the declared deduplication
policy; an empty one proves emptiness),
[`Found`](@ref) when `limit` representatives under that policy were reached first, or
[`BudgetHit`](@ref) when a candidate, node, time, or equivalence budget is reached. Take the functions with
[`search_solutions`](@ref); ask [`proves_emptiness`](@ref), never `isempty`.

A full walk certifies only this symmetric zero-diagonal QAM space. It is not a
classification of arbitrary APN functions. `max_nodes` and `timeout_seconds`
bound tree traversal, including branches pruned before a completed matrix.
`modulus` records a basis label; full QAM tests use only GF(2) ranks and XOR.
"""
function search_qam_full(
    n::Integer;
    limit::Integer = typemax(Int),
    max_evaluations::Integer = 1 << 24,
    confirm::Bool = false,
    timeout_seconds::Real = Inf,
    max_nodes::Int = typemax(Int),
    equivalence_timeout_seconds::Real = 60,
    max_equivalence_nodes::Int = 10^6,
    modulus::Integer = conway_polynomial(n),
    observer = nothing,
)
    _qam_bounds(limit,max_evaluations,timeout_seconds)
    _qam_bounds(typemax(Int),max_nodes,equivalence_timeout_seconds)
    max_equivalence_nodes>=0 || throw(ArgumentError("max_equivalence_nodes must be nonnegative"))
    nn = Int(n)
    2<=nn<=16 || throw(ArgumentError("QAM dimensions must be between 2 and 16"))
    M = [zeros(Int, nn) for _ = 1:nn]            # symmetric, zero diagonal
    reps = SBox{nn,_storage_for(nn)}[]
    buckets=Dict{APNEAMugshot,Vector{SBox{nn,_storage_for(nn)}}}()
    evals = Ref(0)
    vecbuf = zeros(UInt, nn)
    started=time();nodes=Ref(0);stop=Ref(:complete)
    function done()
        stop[]!==:complete && return true
        if time()-started>=timeout_seconds;stop[]=:time
        elseif length(reps)>=limit;stop[]=:limit
        elseif evals[]>=max_evaluations;stop[]=:evaluations
        elseif nodes[]>=max_nodes;stop[]=:nodes
        end
        stop[]!==:complete
    end
    function visit()
        done() && return false
        nodes[]+=1
        true
    end

    # Is the c×c leading submatrix proper (nonzero row-sums have rank ≥ c-1)?
    proper = function (c::Int)
        @inbounds for mask = 1:((1<<c)-1)
            for i = 1:c
                v = UInt(0)
                s = mask
                while s != 0
                    r = trailing_zeros(s) + 1
                    v ⊻= UInt(M[r][i])
                    s &= s - 1
                end
                vecbuf[i] = v
            end
            rank_f2(view(vecbuf, 1:c); nbits = nn) < c - 1 && return false
        end
        true
    end

    local fill_col
    fill_entry = function (c::Int, r::Int)
        visit() || return
        if r == c
            proper(c) && fill_col(c + 1)
            return
        end
        @inbounds for v = 0:((1<<nn)-1)
            M[r][c] = v
            M[c][r] = v
            fill_entry(c, r + 1)
            done() && return
        end
    end
    fill_col = function (c::Int)
        visit() || return
        if c > nn
            evals[] += 1
            observer === nothing || observer(:candidate, nothing)
            Mat = Matrix{Int}(undef, nn, nn)
            @inbounds for i = 1:nn, j = 1:nn
                Mat[i, j] = M[i][j]
            end
            observer === nothing || observer(:final_test, nothing)
            if is_qam(Mat)
                F = qam_to_sbox(Mat)
                observer === nothing || observer(:apn, F)
                status=_qam_add_candidate!(reps,buckets,F;confirm,
                    timeout_seconds=min(equivalence_timeout_seconds,max(0,timeout_seconds-(time()-started))),
                    max_nodes=max_equivalence_nodes)
                status===:inconclusive && (stop[]=:external)
            end
            return
        end
        fill_entry(c, 1)
    end
    t0 = time()
    fill_col(2)
    el = time() - t0

    # The full symmetric zero-diagonal space: nn·(nn-1)/2 free entries over GF(2ⁿ).
    region = SearchRegion(
        :full_qam,
        "full_qam(n=$nn)";
        size = BigInt(1) << (nn * div(nn * (nn - 1), 2)),
        params = Dict{String,Any}("n" => nn, "modulus" => Int(modulus),
            "confirm"=>confirm,"solution_unit"=>confirm ? "ea_class" : "mugshot_bucket",
            "completed_matrices"=>evals[],"max_equivalence_nodes"=>max_equivalence_nodes,
            "equivalence_timeout_seconds"=>Float64(equivalence_timeout_seconds)),
    )
    if stop[] in (:evaluations,:nodes,:time,:external)
        return BudgetHit(
            StopPoint(stop[]===:evaluations ? :nodes : stop[],
                stop[]===:external ? "EA confirmation inconclusive" : "$(stop[]) budget reached"),
            region,
            reps;
            nodes_visited = nodes[],
            elapsed_seconds = el,
        )
    elseif stop[]===:limit
        return Found(reps, region; nodes_visited = nodes[], elapsed_seconds = el)
    end
    return Exhausted(region, reps; nodes_visited = nodes[], elapsed_seconds = el)
end
