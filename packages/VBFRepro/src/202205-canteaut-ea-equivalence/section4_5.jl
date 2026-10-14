# Section 4.5 — reproduce the 21,102-member eight-bit corpus experiment.
# Input: VBFCatalog's two named, content-addressed side stores.
# Output: full invariant tuples and coverage; equal tuples are not equivalence proofs.
# VBF API: is_quadratic_apn, absolute_walsh_spectrum, sigma_key.
include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog
using SHA
using TOML

const SECTION45_CORPORA = ["yuwangli2014_qam_n8", "beierleleander2022_n8"]
const SECTION45_PUBLISHED_WALSH = [
    ((0,16320),(16,43520),(32,5440)),
    ((0,15600),(16,44544),(32,5120),(64,16)),
    ((0,14880),(16,45568),(32,4800),(64,32)),
    ((0,14160),(16,46592),(32,4480),(64,48)),
    ((0,13440),(16,47616),(32,4160),(64,64)),
    ((0,12540),(16,48640),(32,4096),(128,4)),
]

"Paper's extended Walsh histogram, restricted to nonzero output masks."
function section45_extended_walsh(F::SBox{N}) where N
    histogram = Dict(VBF.sorted_pairs(absolute_walsh_spectrum(F)))
    # The public histogram excludes (0,0), but includes 2^N-1 zero entries at b=0.
    histogram[0] = get(histogram, 0, 0) - ((1 << N) - 1)
    histogram[0] == 0 && delete!(histogram, 0)
    Tuple(sort!(collect(histogram); by = first) .|> p -> (first(p), last(p)))
end

"""
    section4_5_report(; limit=16, full_search=false, check_ortho=false,
                        max_evaluations=typemax(Int), timeout_seconds=60, io=stdout)

Validate members of the two published corpora, retaining exact invariant tuples.
`full_search=true` selects all registered members; a budget can still interrupt it.
Only an exhausted, APN-verified full scan may compare the published total. Distinct
ortho-derivative signatures prove inequivalence for quadratic APNs; equal ones
remain unresolved. This makes no claim about functions outside these corpora.
"""
function section4_5_report(; limit::Int=16, full_search::Bool=false,
        check_ortho::Bool=false, max_evaluations::Int=typemax(Int),
        timeout_seconds::Real=60, corpora=SECTION45_CORPORA,
        save_results::Bool=false, io::IO=stdout)
    limit >= 0 && max_evaluations >= 0 && timeout_seconds >= 0 ||
        throw(ArgumentError("limits must be nonnegative"))
    db = load_catalog()
    started = time_ns()
    elapsed() = (time_ns() - started) / 1e9
    records = NamedTuple[]
    inputs = NamedTuple[]
    missing = String[]
    counts = Dict{Any,Int}()
    signatures = Set{Any}()
    available = 0
    invalid = 0
    stop = nothing
    try
        for name in corpora
            info = corpus_info(db, name)
            # corpus_store_path throws for an unknown corpus, so check info first.
            path = info === nothing ? nothing : VBFCatalog.corpus_store_path(name)
            if path === nothing || !isfile(path)
                push!(missing, name)
                continue
            end
            available += Int(info.member_count)
            push!(inputs, (; name, member_count=Int(info.member_count),
                sha256=bytes2hex(open(SHA.sha256, path))))
        end
        region = SearchRegion(:published_corpus, "Canteaut-2022-section4.5";
            size=available, params=Dict{String,Any}("corpora"=>collect(corpora),
                "input_sha256"=>[r.sha256 for r in inputs]))
        for input in inputs
            for index in 1:input.member_count
                if length(records) >= max_evaluations || elapsed() >= timeout_seconds ||
                        (!full_search && length(records) >= limit)
                    stop = StopPoint(elapsed() >= timeout_seconds ? :time : :nodes,
                        "Unprocessed corpus members remain")
                    break
                end
                F = corpus_function(db, input.name, index)
                verified = is_quadratic_apn(F)
                invalid += !verified
                spectrum = section45_extended_walsh(F)
                counts[spectrum] = get(counts, spectrum, 0) + 1
                signature = check_ortho && verified ? sigma_key(F) : nothing
                signature === nothing || push!(signatures, signature)
                push!(records, (; corpus=input.name, index, quadratic_apn=verified,
                    extended_walsh=spectrum, signature))
            end
            stop === nothing || break
        end
        if !isempty(missing)
            stop = StopPoint(:external, "Missing required corpus: $(join(missing, ", "))")
        end
        outcome = stop === nothing ?
            Exhausted(region, records; nodes_visited=length(records), elapsed_seconds=elapsed()) :
            BudgetHit(stop, region, records; nodes_visited=length(records), elapsed_seconds=elapsed())
        complete = outcome isa Exhausted && isempty(missing)
        published_scope = collect(corpora) == SECTION45_CORPORA
        table_reproduced = complete && published_scope && available == 21_102 && invalid == 0 &&
            Set(keys(counts)) == Set(SECTION45_PUBLISHED_WALSH)
        pairwise_distinguished = complete && invalid == 0 && check_ortho &&
            length(signatures) == length(records)
        print_section("Section 4.5 — eight-bit corpus experiment", io)
        print_kv("coverage", "$(length(records)) / $available registered members", io)
        for input in inputs
            print_kv("input $(input.name)", "$(input.member_count) members, SHA256=$(input.sha256)", io)
        end
        print_kv("missing corpora", missing, io)
        print_kv("invalid quadratic APNs", invalid, io)
        print_kv("distinct extended Walsh spectra", length(counts), io)
        print_kv("published six-spectrum experiment reproduced", table_reproduced, io)
        print_kv("pairwise inequivalence certified by distinct exact signatures", pairwise_distinguished, io)
        print_kv("scope", "these side stores only; matching invariants are unresolved", io)
        if save_results
            directory = joinpath(@__DIR__, "results")
            mkpath(directory)
            data = Dict("schema_version"=>1, "complete"=>complete,
                "table_reproduced"=>table_reproduced, "pairwise_distinguished"=>pairwise_distinguished,
                "available"=>available, "processed"=>length(records), "invalid"=>invalid,
                "elapsed_seconds"=>elapsed(), "scope"=>"explicit named side stores only",
                "inputs"=>[Dict("name"=>r.name,"member_count"=>r.member_count,"sha256"=>r.sha256) for r in inputs],
                "records"=>[Dict("corpus"=>r.corpus,"index"=>r.index,"quadratic_apn"=>r.quadratic_apn,
                    "extended_walsh"=>[Int[a,b] for (a,b) in r.extended_walsh],
                    "sigma_differential"=>r.signature === nothing ? Vector{Int}[] : [Int[a,b] for (a,b) in r.signature[1]],
                    "sigma_walsh"=>r.signature === nothing ? Vector{Int}[] : [Int[a,b] for (a,b) in r.signature[2]]) for r in records])
            path = joinpath(directory, "section4_5.toml")
            open(path * ".tmp", "w") do file
                TOML.print(file, data; sorted=true)
            end
            mv(path * ".tmp", path; force=true)
            print_kv("saved exact invariant evidence", path, io)
        end
        return (; outcome, complete, table_reproduced, pairwise_distinguished,
            records, inputs, missing, available, invalid, spectrum_counts=counts,
            distinct_signatures=length(signatures), elapsed_seconds=elapsed())
    finally
        close(db)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_5_report()
end
