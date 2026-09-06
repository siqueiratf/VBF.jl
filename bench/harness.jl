# bench/harness.jl — the timing engine and the case registry for the VBF suite.
#
# The harness has no dependencies outside the standard library and the root
# project. It repeats the pattern that bench/calibrate.jl already uses: one
# warm-up call, then N timed repetitions, then report the minimum. The minimum
# is the statistic of record, because it is the least sensitive to scheduler
# noise on a loaded machine.
#
# A suite file adds cases through `bench!` and never times anything itself.
module BenchHarness

using Printf, Statistics, Random

export BenchCase, BenchResult, Registry, bench!, run_case, run_registry

"""
    BenchCase

One measured operation. `setup` builds the payload and the harness does not time
it. `call` receives that payload and the harness times it.

Fields:
- `group`: the tier of the library, for example "spectra".
- `name`: the operation, for example "walsh_transform".
- `n`: the input bit-width that the case exercises. Use 0 when no width applies.
- `cost`: 1 for a fast case, 2 for a medium case, 3 for a heavy case.
  The runner skips a case when its cost is above the requested level.
- `reps`: 0 asks the harness to choose the count. A positive value fixes it.
- `note`: one short line for the reader of the table.
- `approach`, `parameters`: grouping and reproducible case parameters.
- `metrics`: optional `(payload, value, seconds)` callback, outside timing.
"""
struct BenchCase
    group::String
    name::String
    n::Int
    cost::Int
    setup::Function
    call::Function
    reps::Int
    note::String
    approach::String
    parameters::NamedTuple
    metrics::Function
end

"""
    BenchResult

The measurement of one `BenchCase`. Every time is in seconds.
"""
struct BenchResult
    group::String
    name::String
    n::Int
    cost::Int
    reps::Int
    min_seconds::Float64
    median_seconds::Float64
    mean_seconds::Float64
    std_seconds::Float64
    bytes::Int
    note::String
end

const Registry = Vector{BenchCase}

"""
    bench!(reg; group, name, n, cost, setup, call, reps=0, note="")

Add one case to the registry. A suite file calls this and nothing else.

The `setup` argument must be a zero-argument function that returns the payload.
The `call` argument must accept that payload. Keep every allocation that the
case does not measure inside `setup`.
"""
function bench!(reg::Registry; group::AbstractString, name::AbstractString,
                n::Integer = 0, cost::Integer = 1,
                setup::Function = () -> nothing, call::Function,
                reps::Integer = 0, note::AbstractString = "",
                approach::AbstractString = group, parameters::NamedTuple = (;),
                metrics::Function = (payload, value, seconds) -> (;))
    1 <= cost <= 3 || throw(ArgumentError("cost must be 1, 2 or 3; got $cost"))
    push!(reg, BenchCase(String(group), String(name), Int(n), Int(cost),
                         setup, call, Int(reps), String(note), String(approach),
                         parameters, metrics))
    return reg
end

# The harness aims for this much wall time per case when it chooses the count.
const TARGET_SECONDS = Ref(1.0)
const MIN_REPS = 3
const MAX_REPS = 500

"""
    choose_reps(first_call_seconds) -> Int

Return the repetition count for a case whose single call took the given time.
The count keeps the total near TARGET_SECONDS and stays inside [3, 500].
"""
function choose_reps(t::Float64)
    t <= 0 && return MAX_REPS
    k = floor(Int, TARGET_SECONDS[] / t)
    return clamp(k, MIN_REPS, MAX_REPS)
end

"""
    run_case(c::BenchCase; on_execution=nothing) -> BenchResult

Measure one case. The function seeds the global random number generator before
`setup`, so a case that draws random objects gives the same payload on every
run of the suite.
`on_execution(case, payload, value, seconds, repetition, reps, seed)` runs after
each timed call, before the next repetition. It does not observe warm-up/probes.
"""
function run_case(c::BenchCase; on_execution = nothing)
    seed = 0x5EED0000 + hash((c.group, c.name, c.n)) % 0xFFFF
    Random.seed!(seed)
    payload = c.setup()

    GC.gc()
    warm = @elapsed c.call(payload)          # warm-up; it also compiles the call
    reps = c.reps > 0 ? c.reps : choose_reps(warm)

    bytes = @allocated c.call(payload)

    times = Vector{Float64}(undef, reps)
    for i in 1:reps
        start = time_ns()
        value = c.call(payload)
        times[i] = (time_ns() - start) / 1e9
        on_execution === nothing || on_execution(c, payload, value, times[i],
                                                 i, reps, seed)
    end
    sort!(times)

    return BenchResult(c.group, c.name, c.n, c.cost, reps,
                       times[1],
                       times[(reps + 1) ÷ 2],
                       mean(times),
                       reps > 1 ? std(times) : 0.0,
                       Int(bytes), c.note)
end

"""
    run_registry(reg; level=2, groups=nothing, dims=nothing, io=stdout)

Measure every case that passes the filters and return the results.

- `level`: run a case only when `cost <= level`.
- `groups`: a collection of group names, or `nothing` for every group.
- `dims`: a collection of `n` values, or `nothing` for every value.
"""
function run_registry(reg::Registry; level::Integer = 2,
                      groups = nothing, dims = nothing, io::IO = stdout,
                      on_execution = nothing)
    selected = filter(reg) do c
        c.cost <= level &&
            (groups === nothing || c.group in groups) &&
            (dims === nothing || c.n == 0 || c.n in dims)
    end

    results = BenchResult[]
    total = length(selected)
    for (i, c) in enumerate(selected)
        label = c.n > 0 ? "$(c.group)/$(c.name) n=$(c.n)" : "$(c.group)/$(c.name)"
        @printf(io, "[%3d/%3d] %-52s ", i, total, label)
        flush(io)
        try
            r = run_case(c; on_execution)
            push!(results, r)
            @printf(io, "min=%.3e s  median=%.3e s  reps=%d\n",
                    r.min_seconds, r.median_seconds, r.reps)
        catch err
            @printf(io, "FAILED: %s\n", sprint(showerror, err))
            rethrow()
        end
        flush(io)
    end
    return results
end

end # module
