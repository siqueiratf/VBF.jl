include("helpers.jl")

using VBF: SearchOutcome, Found, Exhausted, BudgetHit, SearchRegion, StopPoint,
           search_solutions, proves_emptiness, is_exhausted, coverage_note,
           outcome_tag

# ---------------------------------------------------------------------------
# Search infrastructure
# ---------------------------------------------------------------------------
#
# WHY THE RETURN TYPE IS NOT A Vector
#
# `context.timed_out` used to be computed by `search_timed_out!` and then
# dropped: `APNSearch` returned `context.solutions` and the context went out of
# scope. With the Makefile's default `timeout_seconds = 300`, a class whose
# deadline expired returned `Vector{Int}[]` — byte-for-byte what a class whose
# tree was walked to the end and shown to hold no APN permutation returned.
# Table 1's "no (Alg. 1)" column and Theorems 1, 3 and 4 are exactly that
# distinction, so the two had to stop being the same value.
#
# The entry points now return a `VBF.SearchOutcome`:
#
#   Exhausted  — the tree was walked to the end. The solution list is complete
#                for this (A, B), so an empty one PROVES no APN permutation
#                with that self-equivalence exists.
#   Found      — stopped at `max_solutions`. Nothing is claimed about the rest.
#   BudgetHit  — `timeout_seconds` expired. Proves nothing.
#
# Note on the missing reductions: this implementation lacks the paper's Lemma 5
# (isSmallest / commutant quotient) and Lemma 6 (extendability seeding) search
# -space reductions. Those are *reductions* — they shrink the walk without
# removing solutions — so their absence costs time, not soundness. An
# `Exhausted` returned here is therefore still a sound proof of emptiness; it is
# simply much harder to reach than it would be with the reductions in place.

mutable struct APNSearchContext
    n::Int
    space_size::Int
    ord_A::Vector{Int}
    ord_B::Vector{Int}
    apply_A::Vector{Int}
    apply_B::Vector{Int}
    visit_order::Vector{Int}
    used_outputs::BitVector
    solutions::Vector{Vector{Int}}
    max_solutions::Int
    on_solution::Function
    deadline::Union{Nothing, Float64}
    timed_out::Bool
    verify_apn_on_solution::Bool
end

function search_solution_callback(n::Int, on_solution::Function;
                                  save_results::Bool = false,
                                  class_index::Union{Nothing, Int} = nothing,
                                  save_result::Function = save_search_result_constant)::Function
    !save_results || class_index !== nothing || error("class_index is required when save_results is true")

    if save_results
        return solution -> begin
            on_solution(solution)
            save_result(solution, n, class_index)
            nothing
        end
    end

    return solution -> begin
        on_solution(solution)
        nothing
    end
end

function APNSearchContext(n::Int, apply_A::Vector{Int}, apply_B::Vector{Int};
                          max_solutions::Int = typemax(Int),
                          on_solution::Function = sbox -> nothing,
                          save_results::Bool = false,
                          class_index::Union{Nothing, Int} = nothing,
                          save_result::Function = save_search_result_constant,
                          visit_order::Vector{Int} = c_reference_visit_order(n, class_index),
                          timeout_seconds::Union{Nothing, Real} = nothing,
                          verify_apn_on_solution::Bool = true)
    field_size = 1 << n
    @assert length(apply_A) == field_size "apply_A must have 2^n entries"
    @assert length(apply_B) == field_size "apply_B must have 2^n entries"
    @assert length(visit_order) == field_size "visit_order must have 2^n entries"
    deadline = timeout_seconds === nothing ? nothing : time() + Float64(timeout_seconds)
    callback = search_solution_callback(
        n,
        on_solution,
        save_results = save_results,
        class_index = class_index,
        save_result = save_result,
    )

    return APNSearchContext(
        n,
        field_size,
        orbit_orders(apply_A),
        orbit_orders(apply_B),
        apply_A,
        apply_B,
        visit_order,
        falses(field_size),
        Vector{Vector{Int}}(),
        max_solutions,
        callback,
        deadline,
        false,
        verify_apn_on_solution,
    )
end

function APNSearchContext(n::Int;
                          ord_A::Function,
                          ord_B::Function,
                          apply_A::Function,
                          apply_B::Function,
                          max_solutions::Int = typemax(Int),
                          on_solution::Function = sbox -> nothing,
                          save_results::Bool = false,
                          class_index::Union{Nothing, Int} = nothing,
                          save_result::Function = save_search_result_constant,
                          visit_order::Vector{Int} = c_reference_visit_order(n, class_index),
                          timeout_seconds::Union{Nothing, Real} = nothing,
                          verify_apn_on_solution::Bool = true)
    field_size = 1 << n
    callback = search_solution_callback(
        n,
        on_solution,
        save_results = save_results,
        class_index = class_index,
        save_result = save_result,
    )

    apply_A_values = Vector{Int}(undef, field_size)
    apply_B_values = Vector{Int}(undef, field_size)
    ord_A_values   = Vector{Int}(undef, field_size)
    ord_B_values   = Vector{Int}(undef, field_size)

    @inbounds for x in 0:(field_size - 1)
        apply_A_values[x + 1] = apply_A(x)
        apply_B_values[x + 1] = apply_B(x)
        ord_A_values[x + 1]   = ord_A(x)
        ord_B_values[x + 1]   = ord_B(x)
    end

    @assert length(visit_order) == field_size "visit_order must have 2^n entries"
    deadline = timeout_seconds === nothing ? nothing : time() + Float64(timeout_seconds)

    return APNSearchContext(
        n,
        field_size,
        ord_A_values,
        ord_B_values,
        apply_A_values,
        apply_B_values,
        visit_order,
        falses(field_size),
        Vector{Vector{Int}}(),
        max_solutions,
        callback,
        deadline,
        false,
        verify_apn_on_solution,
    )
end

function seed_used_outputs!(context::APNSearchContext, sbox::Vector{Int})
    length(sbox) == context.space_size ||
        error("sbox must have $(context.space_size) entries for n = $(context.n)")
    fill!(context.used_outputs, false)

    @inbounds for y in sbox
        y == -1 && continue
        context.used_outputs[y + 1] && error("Initial sbox is not injective")
        context.used_outputs[y + 1] = true
    end
end

function search_timed_out!(context::APNSearchContext)::Bool
    context.deadline === nothing && return false
    time() <= context.deadline && return false

    context.timed_out = true
    return true
end

"""
    apn_search_region(n; class_index = nothing) -> VBF.SearchRegion

The region an `APNSearch` run covers: the APN permutations `F` with
`F(Bx) = A F(x)` and `F(0) = 0` for the given tuple. Its cardinality is not
known in advance, so `size` is `nothing` — which is itself the honest statement
that no coverage fraction can be computed for a partial run.
"""
apn_search_region(n::Int; class_index::Union{Nothing,Int} = nothing) = SearchRegion(
    :le_automorphism_class,
    class_index === nothing ? "BBL2021/n=$n/tuple=unnamed" : "BBL2021/n=$n/class=$class_index";
    size = nothing,
    params = Dict{String,Any}("n" => n, "class_index" => class_index),
)

"""
    search_outcome(context, region, elapsed) -> VBF.SearchOutcome

Turn a finished search context into the three-case outcome. This is the single
place where `context.timed_out` is read — it used to be read nowhere.
"""
function search_outcome(context::APNSearchContext, region::SearchRegion, elapsed::Float64)
    sols = context.solutions
    if context.timed_out
        return BudgetHit(
            StopPoint(
                :time,
                "timeout_seconds expired";
                resume_key = Dict{String,Any}("class_index" => region.params["class_index"]),
            ),
            region, sols; elapsed_seconds = elapsed,
        )
    elseif length(sols) >= context.max_solutions
        return Found(sols, region; elapsed_seconds = elapsed)
    end
    return Exhausted(region, sols; elapsed_seconds = elapsed)
end

function record_complete_solution!(context::APNSearchContext, sbox::Vector{Int})
    solution = copy(sbox)
    solution_is_apn = _is_apn(solution)

    if context.verify_apn_on_solution && !solution_is_apn
        error("Completed S-box is not APN")
    end

    push!(context.solutions, solution)
    context.on_solution(solution)

    return context.solutions
end

function assign_orbit!(start_x::Int, start_y::Int, orbit_length::Int,
                       sbox::Vector{Int}, ddt::Matrix{Int},
                       context::APNSearchContext)::Tuple{Bool, Vector{Int}}
    current_x = start_x
    current_y = start_y
    assigned_inputs = Int[]

    for _ in 1:orbit_length
        if sbox[current_x + 1] != -1 || context.used_outputs[current_y + 1]
            return false, assigned_inputs
        end

        sbox[current_x + 1] = current_y
        context.used_outputs[current_y + 1] = true
        push!(assigned_inputs, current_x)

        if !addDDTInformationUnchecked(current_x, sbox, ddt)
            return false, assigned_inputs
        end

        current_x = context.apply_A[current_x + 1]
        current_y = context.apply_B[current_y + 1]
    end

    return true, assigned_inputs
end

function rollback_orbit!(assigned_inputs::Vector{Int}, sbox::Vector{Int},
                         ddt::Matrix{Int}, context::APNSearchContext)
    for assigned_x in Iterators.reverse(assigned_inputs)
        removeDDTInformationUnchecked(assigned_x, sbox, ddt)
        context.used_outputs[sbox[assigned_x + 1] + 1] = false
        sbox[assigned_x + 1] = -1
    end
end

function nextVal(depth::Int, sbox::Vector{Int}, ddt::Matrix{Int}, context::APNSearchContext)
    length(sbox) == context.space_size && size(ddt, 1) == context.space_size ||
        error("sbox and ddt sizes must match context.space_size")
    length(context.solutions) >= context.max_solutions && return context.solutions
    search_timed_out!(context) && return context.solutions

    if isComplete(sbox)
        return record_complete_solution!(context, sbox)
    end

    x = nextFreePosition(sbox, context.visit_order)
    x == -1 && return context.solutions
    ord_x = context.ord_A[x + 1]

    @inbounds for y in 0:(context.space_size - 1)
        length(context.solutions) >= context.max_solutions && break
        context.used_outputs[y + 1] && continue
        ord_x == context.ord_B[y + 1] || continue

        assignment_is_valid, assigned_inputs = assign_orbit!(x, y, ord_x, sbox, ddt, context)

        if assignment_is_valid
            nextVal(depth + 1, sbox, ddt, context)
        end

        rollback_orbit!(assigned_inputs, sbox, ddt, context)
    end

    return context.solutions
end

function nextVal(depth::Int, sbox::Vector{Int}, ddt::Matrix{Int};
                 ord_A::Function,
                 ord_B::Function,
                 apply_A::Function,
                 apply_B::Function,
                 max_solutions::Int = typemax(Int),
                 on_solution::Function = sbox -> nothing,
                 save_results::Bool = false,
                 class_index::Union{Nothing, Int} = nothing,
                 save_result::Function = save_search_result_constant,
                 visit_order::Union{Nothing, Vector{Int}} = nothing,
                 timeout_seconds::Union{Nothing, Real} = nothing,
                 verify_apn_on_solution::Bool = true)
    n = trailing_zeros(length(sbox))
    1 << n == length(sbox) || error("sbox length must be a power of 2")
    selected_visit_order = visit_order === nothing ? c_reference_visit_order(n, class_index) : visit_order

    context = APNSearchContext(
        n,
        ord_A = ord_A,
        ord_B = ord_B,
        apply_A = apply_A,
        apply_B = apply_B,
        max_solutions = max_solutions,
        on_solution = on_solution,
        save_results = save_results,
        class_index = class_index,
        save_result = save_result,
        visit_order = selected_visit_order,
        timeout_seconds = timeout_seconds,
        verify_apn_on_solution = verify_apn_on_solution,
    )
    seed_used_outputs!(context, sbox)

    t0 = time()
    nextVal(depth, sbox, ddt, context)
    return search_outcome(context, apn_search_region(n; class_index), time() - t0)
end

@doc"""
    APNSearch(n::Int, A, B; kwargs...) -> VBF.SearchOutcome{Vector{Int}}

Run Algorithm 1 from the linearly self-equivalent APN permutations experiment
for the matrix pair `(A, B)`. The solutions (via `search_solutions`) are
complete S-box lookup tables satisfying `F(Bx) = A F(x)` and the APN constraint.

Returns a three-case [`VBF.SearchOutcome`], **not** a bare vector:

  * `Exhausted` — the tree was walked to the end; the solution list is complete
    for this tuple, so an empty one proves no such APN permutation exists.
  * `Found` — stopped at `max_solutions`; the rest of the tree is unexamined.
  * `BudgetHit` — `timeout_seconds` expired; nothing is proved.

Use `proves_emptiness(result)`, never `isempty(result)`. A `Vector`-returning
version of this function could not tell a 300 s timeout from a proof, which is
precisely the distinction Table 1's "no (Alg. 1)" column rests on.

!!! note "Convention vs. paper"
    The paper's Corollary 1 uses `F ∘ A = B ∘ F`, i.e. `F(Ax) = BF(x)`.
    This function's signature `APNSearch(n, A, B)` instead satisfies
    `F(Bx) = AF(x)`, so the code's `(A, B)` corresponds to the paper's
    `(B, A)`.  Internally the arguments are swapped when creating the
    search context (B → apply_A, A → apply_B) to match the internal
    orbit-assignment logic.
"""
function APNSearch(n::Int, A, B;
                   max_solutions::Int = typemax(Int),
                   on_solution::Function = sbox -> nothing,
                   sbox::Vector{Int} = fill(-1, 1 << n),
                   ddt::Matrix{Int} = zeros(Int, 1 << n, 1 << n),
                   save_results::Bool = false,
                   class_index::Union{Nothing, Int} = nothing,
                   save_result::Function = save_search_result_constant,
                   visit_order::Vector{Int} = c_reference_visit_order(n, class_index),
                   timeout_seconds::Union{Nothing, Real} = nothing,
                   seed_zero::Bool = true,
                   verify_apn_on_solution::Bool = true)
    length(sbox) == 1 << n ||
        error("sbox must have 2^n entries for n = $n")
    length(sbox) == size(ddt, 1) == size(ddt, 2) ||
        error("sbox and ddt sizes must be consistent")

    if seed_zero
        sbox[1] in (-1, 0) || error("C reference search requires sbox[0] to be 0")
        if sbox[1] == -1
            sbox[1] = 0
        end
        addDDTInformation(0, sbox, ddt)
    end

    # NOTE: A/B are swapped here relative to the function signature.
    # The paper's Corollary 1 has F(Ax)=BF(x), but the code's signature is
    # APNSearch(n, A, B) with F(Bx)=AF(x).  The search context's apply_A
    # receives B's LUT and apply_B receives A's LUT to match the internal
    # orbit-assignment convention.
    context = APNSearchContext(
        n,
        linear_map_lut(B, n),   # apply_A ← B (paper's A)
        linear_map_lut(A, n),   # apply_B ← A (paper's B)
        max_solutions = max_solutions,
        on_solution = on_solution,
        save_results = save_results,
        class_index = class_index,
        save_result = save_result,
        visit_order = visit_order,
        timeout_seconds = timeout_seconds,
        verify_apn_on_solution = verify_apn_on_solution,
    )
    seed_used_outputs!(context, sbox)

    t0 = time()
    nextVal(0, sbox, ddt, context)
    return search_outcome(context, apn_search_region(n; class_index), time() - t0)
end

@doc"""
    APNSearchClasses(n::Int, class_indices="all"; kwargs...) -> Dict{Int, VBF.SearchOutcome}

Run [`APNSearch`](@ref) for precomputed tuple classes of the
linearly self-equivalent APN permutations experiment.

Each value is a three-case outcome, so a class that ran out of `timeout_seconds`
is distinguishable from one proved to hold no APN permutation. Summarise a run
with `apn_search_summary`.
"""
function APNSearchClasses(n::Int, class_indices = "all";
                          excluded_class_indices = Int[],
                          max_solutions::Int = 1,
                          on_solution::Function = (class_index, sbox) -> nothing,
                          save_results::Bool = true,
                          save_result::Function = save_search_result_constant,
                          timeout_seconds::Union{Nothing, Real} = nothing,
                          seed_zero::Bool = true,
                          verify_apn_on_solution::Bool = true,
                          tuples_dir::String = joinpath(@__DIR__, "tuples"))
    classes = normalize_precomputed_tuple_classes(
        n,
        class_indices,
        excluded_class_indices = excluded_class_indices,
        tuples_dir = tuples_dir,
    )
    results = Dict{Int, SearchOutcome}()

    for class_index in classes
        A, B = precomputed_tuple_matrices(n, class_index, tuples_dir = tuples_dir)
        results[class_index] = APNSearch(
            n,
            A,
            B,
            max_solutions = max_solutions,
            on_solution = sbox -> on_solution(class_index, sbox),
            save_results = save_results,
            class_index = class_index,
            save_result = save_result,
            visit_order = c_reference_visit_order(n, class_index),
            timeout_seconds = timeout_seconds,
            seed_zero = seed_zero,
            verify_apn_on_solution = verify_apn_on_solution,
        )
    end

    return results
end

@doc"""
    apn_search_summary(results::Dict{Int, VBF.SearchOutcome}) -> NamedTuple

Split an [`APNSearchClasses`](@ref) run into what it actually established.

  * `admissible`     — classes with at least one APN permutation found.
  * `proved_empty`   — classes walked to the end with nothing in them. Only
                       these may be reported as "no (Alg. 1)".
  * `budget_hit`     — classes whose `timeout_seconds` expired. These are the
                       paper's "?" and must never be reported as empty.
  * `stopped_early`  — classes that hit `max_solutions` before finishing.

The point of the split is that `proved_empty` and `budget_hit` used to be the
same set.
"""
function apn_search_summary(results::Dict{Int, SearchOutcome})
    admissible    = Int[]
    proved_empty  = Int[]
    budget_hit    = Int[]
    stopped_early = Int[]
    for class_index in sort(collect(keys(results)))
        outcome = results[class_index]
        if !isempty(search_solutions(outcome))
            push!(admissible, class_index)
        elseif proves_emptiness(outcome)
            push!(proved_empty, class_index)
        elseif outcome isa BudgetHit
            push!(budget_hit, class_index)
        else
            push!(stopped_early, class_index)
        end
    end
    (; admissible, proved_empty, budget_hit, stopped_early,
       n_classes = length(results))
end

@doc"""
    print_apn_search_summary(results; io = stdout)

Print an [`apn_search_summary`](@ref) with wording that cannot launder a
timeout into an emptiness result.
"""
function print_apn_search_summary(results::Dict{Int, SearchOutcome}; io::IO = stdout)
    s = apn_search_summary(results)
    println(io, "classes run                       : ", s.n_classes)
    println(io, "admissible (APN permutation found): ", isempty(s.admissible) ? "none" : s.admissible)
    println(io, "PROVED empty (exhaustive, sound)  : ", isempty(s.proved_empty) ? "none" : s.proved_empty)
    println(io, "BUDGET HIT (nothing proved)       : ", isempty(s.budget_hit) ? "none" : s.budget_hit)
    println(io, "stopped early at max_solutions    : ", isempty(s.stopped_early) ? "none" : s.stopped_early)
    if !isempty(s.budget_hit)
        println(io, "  NOTE: the budget-hit classes are NOT empty regions. They are unexamined.")
    end
    s
end
