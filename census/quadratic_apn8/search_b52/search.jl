# Implements the resumable, multi-threaded extension search of the B6 = 52 branch
# Study: B6 = 52 extension search (census/quadratic_apn8/search_b52)
#
# Math (see extlib.jl for the extension step):
#   A seed F is a quadratic APN function on F_2^8 with P6 profile B6 = 52. Comp(F) is an
#   8-dim subspace of Alt(8).
#   mode = comp (the literal method): every 6-dim U < Comp(F) with b(U) = 52 bent
#     elements; all APN S > U (Fourier extension, extensions()).
#   mode = v5 (default): every 5-dim V5 < Comp(F) with the maximal bent count b5 of the
#     seed (30 for the (30,34) profile, 28 for (28,40)); every x in V/V5 with
#     b5 + #bent(x + V5) = 52 (coset bent counts by one 23-bit FWHT); all APN
#     S > U = V5 + <x> (v5_extensions()). U need not lie in Comp(F), so S can be far from
#     F. In mode comp almost every U has the unique extension Comp(F) (README).
#   Each S gives a function (basis = RREF rows of S); differential uniformity 2 is checked;
#   sigma classifies it: known (sigma index), census (the 553 new census classes), or
#   search-new. A search-new function with B6 = enqueue_b6 becomes a new seed (BFS).
#   Class keys skip repeated work: V5 key = hash of the histograms of the coset bent counts
#   and of g5 (mode v5); U key = hash of the histogram of g (mode comp). Both are
#   EA-invariants of the subspace, computed as a by-product of the transforms.
#
# Pseudocode:
#   state = load(outdir)  (done seeds, found sigma, keys); queue = seeds file + search-new
#   spawn `threads` workers; each: take next seed; process_seed; append results atomically
#   process_seed: for each V5 (or U): skip if key seen; collect the S set
#                 for each S: DU check, sigma, classify; new search-new -> queue
#   stop at max_seeds completed seeds, at timeout_seconds (the current seeds are dropped
#   and redone on resume), or when the queue is empty.
#
# Output files in outdir (TSV with header; appended, one block per completed seed):
#   found.tsv  first occurrence of each sigma: sigma, status, gen, parent, b6, coeffs
#   done.tsv   one line per completed seed: counts and seconds
#   keys.tsv   processed V5/U class keys
#   log.txt    progress lines
# VBF API used: SBox, differential_uniformity
# VBFCatalog API used: sigma_hash (and the index helpers in common.jl)

isdefined(@__MODULE__, :index_set) || include(joinpath(@__DIR__, "common.jl"))
using Base.Threads

Base.@kwdef struct SearchOpts
    outdir::String = joinpath(RESULTS_DIR, "run")
    seeds::String = joinpath(RESULTS_DIR, "seeds_b52.tsv")
    mode::Symbol = :v5
    max_seeds::Int = typemax(Int)          # completed seeds in this invocation
    max_u_per_seed::Int = typemax(Int)     # U (= x) per seed, over all V5
    timeout_seconds::Float64 = Inf
    target_b6::Int = 52
    v5_bent::String = "max"                # "max" or a list such as "30,28"
    enqueue_b6::Int = 52                   # -1: enqueue every search-new function
    dedupe::Bool = true
    max_kernel::Int = 12
    progress_seconds::Float64 = 60.0
    max_queue::Int = 5_000_000             # memory guard on the seed queue
end

struct SeedItem
    sigma::String
    gen::Int
    coeffs::String
end

const FOUND_HDR = "sigma\tstatus\tgen\tparent\tb6\tcoeffs"
const DONE_HDR = "sigma\tgen\tunits\tunits_skipped\tnU\tnT\tnS\tknown\tcensus\tsearch\tsearch_first\tseconds"

function read_tsv(path)
    isfile(path) || return Vector{Vector{SubString{String}}}()
    rows = [split(l, '\t') for l in eachline(path)]
    isempty(rows) && return rows
    n = length(rows[1])
    filter(r -> length(r) == n, rows[2:end])        # drop a torn last line
end

function ensure_header(path, hdr)
    if !isfile(path) || filesize(path) == 0
        open(io -> println(io, hdr), path, "w")
    end
end

"Seeds file: sigma, status, profile, coeffs (written by write_seeds)."
function write_seeds(path::AbstractString = joinpath(RESULTS_DIR, "seeds_b52.tsv"); b6::Int = 52)
    rows = seed_rows(; b6)
    mkpath(dirname(path))
    seen = Set{String}()
    open(path, "w") do io
        println(io, "sigma\tstatus\tprofile\tcoeffs")
        for r in rows
            r.sigma in seen && continue
            push!(seen, r.sigma)
            println(io, r.sigma, '\t', r.status, '\t', r.profile, '\t', r.coeffs)
        end
    end
    nnew = count(r -> r.status == "new", rows)
    println("seeds: $(length(seen)) distinct (new $(nnew), known $(length(rows) - nnew)) -> $path")
    path
end

mutable struct SearchState
    queue::Vector{SeedItem}
    qpos::Int
    done::Set{String}
    inqueue::Set{String}
    seen::Set{SigmaBits}            # every sigma met so far (seeds and found)
    keys::Set{NTuple{2,UInt64}}
    claimed::Int
    completed::Int
    busy::Int
    stats::Dict{Symbol,Int}
end

function load_state(opts::SearchOpts)
    mkpath(opts.outdir)
    for (f, h) in (("found.tsv", FOUND_HDR), ("done.tsv", DONE_HDR), ("keys.tsv", "key"))
        ensure_header(joinpath(opts.outdir, f), h)
    end
    seeds = read_tsv(opts.seeds)
    isempty(seeds) && error("no seeds in $(opts.seeds) (run make seeds)")
    done = Set(String(r[1]) for r in read_tsv(joinpath(opts.outdir, "done.tsv")))
    found = read_tsv(joinpath(opts.outdir, "found.tsv"))
    keys = Set{NTuple{2,UInt64}}()
    for r in read_tsv(joinpath(opts.outdir, "keys.tsv"))
        length(r[1]) == 32 || continue
        push!(keys, (parse(UInt64, r[1][1:16], base = 16), parse(UInt64, r[1][17:32], base = 16)))
    end
    queue = SeedItem[]; inq = Set{String}(); seen = Set{SigmaBits}()
    for r in seeds
        push!(seen, sigma_bits(r[1]))
        r[1] in inq && continue
        push!(queue, SeedItem(r[1], 0, r[4])); push!(inq, r[1])
    end
    stats = Dict(:known => 0, :census => 0, :search => 0, :enqueued => 0)
    for r in found
        push!(seen, sigma_bits(r[1]))
        st = Symbol(r[2]); stats[st] = get(stats, st, 0) + 1
        if r[2] == "search" && (opts.enqueue_b6 < 0 || parse(Int, r[5]) == opts.enqueue_b6) &&
           !(r[1] in inq) && length(queue) < opts.max_queue
            push!(queue, SeedItem(r[1], parse(Int, r[3]), r[6])); push!(inq, r[1])
            stats[:enqueued] += 1
        end
    end
    filter!(s -> !(s.sigma in done), queue)
    SearchState(queue, 1, done, inq, seen, keys, 0, 0, 0, stats)
end

keyhex(k) = string(k[1], base = 16, pad = 16) * string(k[2], base = 16, pad = 16)

"""
Process one seed. Returns a NamedTuple with the S set and counters, or `nothing` when the
deadline passed (the seed is then redone on resume).
"""
function process_seed(item::SeedItem, G::Geometry, opts::SearchOpts, w5::V5Work, w6::ExtWork,
                      claim::Function, deadline::Float64)
    c = coeffs_from_hex(item.coeffs)
    f = coord_forms(c, 8); comp = comp_forms(f); bent = bent_mask(G, comp)
    Ss = Set{Vector{UInt32}}()
    units = 0; skipped = 0; nU = 0; nT = 0
    budget = opts.max_u_per_seed
    newkeys = NTuple{2,UInt64}[]
    if opts.mode === :v5
        b5max, _ = max_bent_dim(comp, bent, 5)
        want = opts.v5_bent == "max" ? Set([b5max]) : Set(parse.(Int, split(opts.v5_bent, ',')))
        V5s = subspaces_of_comp(comp, bent, 5; keep = nb -> nb in want)
        for V in V5s
            time() > deadline && return nothing
            budget <= 0 && break
            need = opts.target_b6 - V.nbent
            need < 0 && continue
            units += 1
            r = v5_extensions(G, V.forms, need, w5; beta = BETA8, max_kernel = opts.max_kernel,
                              max_x = budget,
                              should_skip = k -> (opts.dedupe && !claim(k)))
            if r.skipped
                skipped += 1; continue
            end
            push!(newkeys, r.key)
            budget -= r.nX_used; nU += r.nX_used - r.du_reject; nT += r.nT
            union!(Ss, r.Ss)
        end
    elseif opts.mode === :comp
        Us = subspaces_of_comp(comp, bent, 6; keep = ==(opts.target_b6))
        for U in Us
            time() > deadline && return nothing
            budget <= 0 && break
            units += 1; budget -= 1
            e = extensions(G, U.forms, w6; key = opts.dedupe, max_kernel = opts.max_kernel)
            if opts.dedupe && e.key !== nothing
                claim(e.key) || (skipped += 1; continue)
                push!(newkeys, e.key)
            end
            nU += 1; nT += length(e.Ts)
            for (u, v) in e.Ts
                push!(Ss, s_key(vcat(e.R, lift(u, e.Qmask), lift(v, e.Qmask))))
            end
        end
    else
        error("mode must be v5 or comp")
    end
    # functions, sigma (distinct within the seed)
    out = Dict{SigmaBits,Tuple{String,Int}}()      # sigma -> (coeffs hex, b6)
    for S in Ss
        cS, F = function_of(G, S)
        differential_uniformity(F) == 2 || error("extension is not APN (seed $(item.sigma))")
        h = sigma_bits(VBFCatalog.sigma_hash(F))
        haskey(out, h) && continue
        out[h] = (hex_from_coeffs(cS), -1)
    end
    (; Ss, out, units, skipped, nU, nT, newkeys)
end

"""
Command-line entry: arguments `key=value` (outdir, seeds, mode, max_seeds, max_u_per_seed,
timeout_seconds, v5_bent, enqueue_b6, dedupe, progress_seconds). 0 means no limit for
max_seeds, max_u_per_seed and timeout_seconds.
"""
function cli_search(args::Vector{String})
    kv = Dict(String(split(a, '=', limit = 2)[1]) => String(split(a, '=', limit = 2)[2]) for a in args)
    lim(k) = (v = parse(Int, get(kv, k, "0")); v <= 0 ? typemax(Int) : v)
    ts = parse(Float64, get(kv, "timeout_seconds", "0"))
    opts = SearchOpts(; outdir = get(kv, "outdir", joinpath(RESULTS_DIR, "run")),
        seeds = get(kv, "seeds", joinpath(RESULTS_DIR, "seeds_b52.tsv")),
        mode = Symbol(get(kv, "mode", "v5")), max_seeds = lim("max_seeds"),
        max_u_per_seed = lim("max_u_per_seed"), timeout_seconds = ts <= 0 ? Inf : ts,
        v5_bent = get(kv, "v5_bent", "max"), enqueue_b6 = parse(Int, get(kv, "enqueue_b6", "52")),
        dedupe = parse(Bool, get(kv, "dedupe", "true")),
        progress_seconds = parse(Float64, get(kv, "progress_seconds", "60")))
    run_search(opts)
end

"B6 of a function given by its coefficient string."
function b6_of(G::Geometry, coeffs::AbstractString)
    comp = comp_forms(coord_forms(coeffs_from_hex(coeffs), 8))
    max_bent_dim(comp, bent_mask(G, comp), 6)[1]
end

function run_search(opts::SearchOpts; io::IO = stdout)
    G = geometry(8)
    idx = index_set(; io)
    c553 = census_new_set()
    st = load_state(opts)
    lk = ReentrantLock()
    t0 = time()
    deadline = t0 + opts.timeout_seconds
    logio = open(joinpath(opts.outdir, "log.txt"), "a")
    say(msg) = (s = "[$(now_str())] " * msg; println(io, s); println(logio, s); flush(io); flush(logio))
    say("start: mode=$(opts.mode) threads=$(nthreads()) max_seeds=$(opts.max_seeds) " *
        "max_u_per_seed=$(opts.max_u_per_seed) timeout=$(opts.timeout_seconds) s " *
        "queue=$(length(st.queue)) done=$(length(st.done)) keys=$(length(st.keys)) outdir=$(opts.outdir)")
    found_io = open(joinpath(opts.outdir, "found.tsv"), "a")
    done_io = open(joinpath(opts.outdir, "done.tsv"), "a")
    keys_io = open(joinpath(opts.outdir, "keys.tsv"), "a")
    last_print = Ref(time())
    tot = Dict(:seeds => 0, :units => 0, :skipped => 0, :nU => 0, :nT => 0, :nS => 0,
               :known => 0, :census => 0, :search => 0, :search_first => 0)
    claim = k -> lock(lk) do
        k in st.keys && return false
        push!(st.keys, k); true
    end
    function next_item()
        lock(lk) do
            st.claimed >= opts.max_seeds && return :stop
            time() > deadline && return :stop
            while st.qpos <= length(st.queue) && st.queue[st.qpos].sigma in st.done
                st.qpos += 1
            end
            if st.qpos <= length(st.queue)
                it = st.queue[st.qpos]; st.qpos += 1
                st.claimed += 1; st.busy += 1
                return it
            end
            st.busy == 0 ? :stop : :wait
        end
    end
    function report_progress(force = false)
        (force || time() - last_print[] >= opts.progress_seconds) || return
        last_print[] = time()
        el = time() - t0
        say(@sprintf("seeds %d (%.2f/min) queue %d left | units %d skipped %d | U %d T %d S %d | known %d census %d search %d (first %d, %.1f/min) | rss %.0f MB",
            tot[:seeds], 60tot[:seeds] / el, length(st.queue) - st.qpos + 1, tot[:units], tot[:skipped],
            tot[:nU], tot[:nT], tot[:nS], tot[:known], tot[:census], tot[:search], tot[:search_first],
            60tot[:search_first] / el, Sys.maxrss() / 2^20))
    end
    worker = function ()
        w5 = V5Work(23); w6 = ExtWork(22)
        while true
            it = next_item()
            it === :stop && break
            if it === :wait
                sleep(0.5); continue
            end
            t1 = time()
            r = try
                process_seed(it, G, opts, w5, w6, claim, deadline)
            catch err
                lock(lk) do; st.busy -= 1; end
                say("ERROR seed $(it.sigma): $(sprint(showerror, err))")
                rethrow()
            end
            lock(lk) do
                st.busy -= 1
                if r === nothing
                    return
                end
                nk = 0; nc = 0; ns = 0; nf = 0
                for (h, (cs, _)) in r.out
                    status = h in idx ? "known" : h in c553 ? "census" : "search"
                    status == "known" ? (nk += 1) : status == "census" ? (nc += 1) : (ns += 1)
                    h in st.seen && continue
                    push!(st.seen, h)
                    b6 = status == "search" ? b6_of(G, cs) : -1
                    hx = sigma_hex(h)
                    println(found_io, hx, '\t', status, '\t', it.gen + 1, '\t', it.sigma, '\t', b6, '\t', cs)
                    if status == "search"
                        nf += 1
                        if (opts.enqueue_b6 < 0 || b6 == opts.enqueue_b6) && !(hx in st.inqueue) &&
                           length(st.queue) < opts.max_queue
                            push!(st.queue, SeedItem(hx, it.gen + 1, cs)); push!(st.inqueue, hx)
                        end
                    end
                end
                for k in r.newkeys; println(keys_io, keyhex(k)); end
                println(done_io, join((it.sigma, it.gen, r.units, r.skipped, r.nU, r.nT, length(r.Ss),
                                       nk, nc, ns, nf, round(time() - t1, digits = 2)), '\t'))
                flush(found_io); flush(keys_io); flush(done_io)
                push!(st.done, it.sigma); st.completed += 1
                tot[:seeds] += 1; tot[:units] += r.units; tot[:skipped] += r.skipped
                tot[:nU] += r.nU; tot[:nT] += r.nT; tot[:nS] += length(r.Ss)
                tot[:known] += nk; tot[:census] += nc; tot[:search] += ns; tot[:search_first] += nf
                report_progress()
            end
        end
    end
    tasks = [Threads.@spawn worker() for _ in 1:nthreads()]
    foreach(wait, tasks)
    report_progress(true)
    reason = st.claimed >= opts.max_seeds ? "max_seeds" : time() > deadline ? "timeout" : "queue empty"
    say("stop ($reason): completed $(tot[:seeds]) seeds in $(round(time() - t0, digits = 1)) s")
    close(found_io); close(done_io); close(keys_io); close(logio)
    tot
end
