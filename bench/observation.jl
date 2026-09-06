"""Optional search events used to measure existing APIs without changing their search order."""
module BenchObservation

using VBF
export Observation, observed_call, observation_metrics

mutable struct Observation
    start::UInt64
    first_apn::Union{Nothing,Float64}
    candidates::Int
    final_tests::Int
    apns::Vector{SBox}
end
Observation() = Observation(0, nothing, 0, 0, SBox[])

"""Record a completed candidate, a final APN check, or an APN before algorithm deduplication."""
function (o::Observation)(event, value)
    if event === :candidate
        o.candidates += 1
    elseif event === :final_test
        o.final_tests += 1
    elseif event === :apn
        o.first_apn === nothing && (o.first_apn = (time_ns() - o.start) / 1e9)
        push!(o.apns, value)
    end
    nothing
end

"""Reset the observation for every call, including warm-up and allocation calls."""
function observed_call(f, payload)
    o = payload.observation
    o.first_apn = nothing
    o.candidates = o.final_tests = 0
    empty!(o.apns)
    o.start = time_ns()
    f(payload.input, o)
end

"""Metrics refer to completed candidates, not partial assignments in a backtracking tree."""
function observation_metrics(payload, value, seconds)
    o = payload.observation
    (; apns = o.apns, time_to_first_apn_seconds = o.first_apn,
       candidates_processed = o.candidates, candidates_final_apn_test = o.final_tests)
end

end
