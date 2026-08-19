@testitem "search_outcome" begin
using VBF
using Test

# These tests are written to FAIL if the Exhausted/BudgetHit distinction is ever
# collapsed back — including by a well-meaning future edit that adds a
# convenience fallback method. Each testset names the collapse it blocks.

const REG = SearchRegion(:hyperplane, "test/H0"; size = 1024)
const STOP = StopPoint(:time, "300 s wall clock"; resume_key = Dict{String,Any}("node" => 17))

@testset "the three cases are distinct types" begin
    f = Found([1, 2], REG)
    e = Exhausted(REG, Int[])
    b = BudgetHit(STOP, REG, Int[])
    @test f isa SearchOutcome
    @test e isa SearchOutcome
    @test b isa SearchOutcome
    @test typeof(f) !== typeof(e) !== typeof(b)
    @test outcome_tag(f) === :found
    @test outcome_tag(e) === :exhausted
    @test outcome_tag(b) === :budget_hit
    @test is_exhausted(e) && !is_exhausted(b) && !is_exhausted(f)
    @test is_budget_hit(b) && !is_budget_hit(e)
end

# The core defect: an empty solution list from a timeout and an empty solution
# list from a completed walk used to be the same value.
@testset "empty-from-timeout is NOT equal to empty-from-exhaustion" begin
    e = Exhausted(REG, Int[])
    b = BudgetHit(STOP, REG, Int[])
    @test search_solutions(e) == search_solutions(b)   # the OLD return values agree …
    @test e != b                                        # … but the outcomes do not
    @test typeof(e) !== typeof(b)
    @test proves_emptiness(e)
    @test !proves_emptiness(b)                          # <- the whole point
end

@testset "proves_emptiness is false for every non-Exhausted case" begin
    @test !proves_emptiness(BudgetHit(STOP, REG, Int[]))
    @test !proves_emptiness(Found(Int[], REG))
    @test !proves_emptiness(Exhausted(REG, [1]))        # exhausted but non-empty
    @test proves_emptiness(Exhausted(REG, Int[]))
end

# Dispatch, not code review, is what stops the misuse.
@testset "certified_region / certified_empty_region reject a BudgetHit at dispatch" begin
    b = BudgetHit(STOP, REG, Int[])
    f = Found(Int[], REG)
    @test_throws MethodError certified_region(b)
    @test_throws MethodError certified_empty_region(b)
    @test_throws MethodError certified_region(f)
    @test_throws MethodError certified_empty_region(f)
    e = Exhausted(REG, Int[])
    @test certified_region(e) === REG
    @test certified_empty_region(e) === REG
end

# Guards against a future edit that "helpfully" adds a generic fallback.
@testset "no ::SearchOutcome fallback may be added for the certifying accessors" begin
    @test !applicable(certified_region, BudgetHit(STOP, REG, Int[]))
    @test !applicable(certified_region, Found(Int[], REG))
    @test !applicable(certified_empty_region, BudgetHit(STOP, REG, Int[]))
    @test !applicable(certified_empty_region, Found(Int[], REG))
    @test applicable(certified_region, Exhausted(REG, Int[]))
    @test applicable(certified_empty_region, Exhausted(REG, Int[]))
end

@testset "certified_empty_region refuses a non-empty exhausted region" begin
    @test_throws ArgumentError certified_empty_region(Exhausted(REG, [1, 2]))
end

@testset "assert_exhausted throws on BudgetHit and names the stop point" begin
    b = BudgetHit(STOP, REG, Int[]; nodes_visited = 42, elapsed_seconds = 300.0)
    err = try
        assert_exhausted(b; context = "phase 4")
        nothing
    catch ex
        ex
    end
    @test err !== nothing
    msg = sprint(showerror, err)
    @test occursin("NOT exhausted", msg)
    @test occursin("time", msg)
    @test occursin("phase 4", msg)
    @test occursin("not a proof of emptiness", msg)
    e = Exhausted(REG, Int[])
    @test assert_exhausted(e) === e
end

@testset "assert_exhausted throws on Found (an early stop is not coverage)" begin
    @test_throws ErrorException assert_exhausted(Found([1], REG))
end

@testset "isempty is refused on outcomes, with a message naming the fix" begin
    for o in (Exhausted(REG, Int[]), BudgetHit(STOP, REG, Int[]), Found(Int[], REG))
        err = try
            isempty(o)
            nothing
        catch ex
            ex
        end
        @test err !== nothing
        @test occursin("proves_emptiness", sprint(showerror, err))
    end
    @test isempty(search_solutions(BudgetHit(STOP, REG, Int[])))   # the safe spelling
end

@testset "coverage_note wording can never call a BudgetHit region empty" begin
    b = BudgetHit(STOP, REG, Int[])
    note = coverage_note(b)
    @test occursin("BUDGET HIT", note)
    @test occursin("UNKNOWN", note)
    @test !occursin("proof of emptiness", note)
    e = coverage_note(Exhausted(REG, Int[]))
    @test occursin("proof of emptiness", e)
    @test note != e
    # show() must not launder a BudgetHit either
    @test occursin("BUDGET HIT", sprint(show, b))
end

@testset "a BudgetHit carries where it stopped, so a run can resume" begin
    b = BudgetHit(STOP, REG, Int[])
    @test b.where_it_stopped.reason === :time
    @test b.where_it_stopped.resume_key["node"] == 17
end

# Regression test for the exact shape of the old defect: a searcher that walks a
# region containing solutions but is stopped by a budget before reaching them
# must return BudgetHit, not an empty Exhausted.
@testset "regression: budget-stopped walk over a NON-empty region" begin
    function walk(; node_budget::Int)
        found = Int[]
        reg = SearchRegion(:subspace, "1:10"; size = 10)
        for (i, x) in enumerate(1:10)
            if i > node_budget
                return BudgetHit(
                    StopPoint(:nodes, "node budget $node_budget";
                              resume_key = Dict{String,Any}("next" => x)),
                    reg, found; nodes_visited = i - 1)
            end
            x in (7, 9) && push!(found, x)
        end
        return Exhausted(reg, found; nodes_visited = 10)
    end

    capped = walk(node_budget = 3)
    @test capped isa BudgetHit
    @test isempty(search_solutions(capped))   # looks exactly like the old empty result
    @test !proves_emptiness(capped)           # but is not a proof of emptiness
    @test_throws MethodError certified_empty_region(capped)
    @test capped.where_it_stopped.resume_key["next"] == 4

    full = walk(node_budget = 10)
    @test full isa Exhausted
    @test search_solutions(full) == [7, 9]
    @test !proves_emptiness(full)
    @test certified_region(full).id == "1:10"
end

@testset "a genuinely empty region still certifies as empty" begin
    reg = SearchRegion(:subspace, "empty5"; size = 5)
    r = Exhausted(reg, Int[]; nodes_visited = 5)
    @test r isa Exhausted
    @test proves_emptiness(r)
    @test certified_empty_region(r).id == "empty5"
end
end
