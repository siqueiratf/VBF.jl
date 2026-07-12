include("helpers.jl")

# ---------------------------------------------------------------------------
# Search infrastructure
# ---------------------------------------------------------------------------

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

    return nextVal(depth, sbox, ddt, context)
end

@doc"""
    APNSearch(n::Int, A, B; kwargs...) -> Vector{Vector{Int}}

Run Algorithm 1 from the linearly self-equivalent APN permutations experiment
for the matrix pair `(A, B)`. The returned values are complete S-box lookup
tables satisfying `F(Bx) = A F(x)` and the APN constraint.

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

    return nextVal(0, sbox, ddt, context)
end

@doc"""
    APNSearchClasses(n::Int, class_indices="all"; kwargs...) -> Dict{Int, Vector{Vector{Int}}}

Run [`APNSearch`](@ref) for precomputed tuple classes of the
linearly self-equivalent APN permutations experiment.
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
    results = Dict{Int, Vector{Vector{Int}}}()

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
