# Streaming pilot check: process the hits of a running gpu/scan_anchors.jl job
# as they arrive. Every `poll` seconds it reads only the new bytes of the remote
# hit file, applies the delta-8 prefilter and ISD to the new hits, and tests each
# APN extension against the catalog by sigma. A sigma outside the catalog is
# printed as a NEW line at once and appended to <name>.new (sigma and LUT).
# The byte offset is saved in <name>.offset, so a restart continues from there.
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/pilot_stream.jl \
#       <file.anchors> <host> <remote dir> <name> [poll seconds] [isd iters]
# Example:
#   ... pilot_stream.jl results/n10_BeierleLeander2022_3.anchors tiago@100.75.124.3 vbf-n10/results BL3
include(joinpath(@__DIR__, "pilot_check.jl"))           # lut_of, isd_fast.jl, VBF, VBFCatalog
using Dates

remote(host, cmd) = readchomp(`ssh -o BatchMode=yes -o ConnectTimeout=15 $host $cmd`)

function pilot_stream(anchorfile, host, rdir, name; poll = 60, iters = 30_000)
    anchors = [[parse(UInt64, x; base = 16) for x in split(l)[2:end]] for l in readlines(anchorfile)]
    nanchors = length(anchors)
    flats = all_flats(); pts = flat_points()
    db = load_catalog()
    known = Set(sigma_hash(F) for F in (load_sbox(db, r.id) for r in list_functions(db; n = 10))
                if VBF.algebraic_degree(F) == 2)
    local_dir = joinpath(@__DIR__, "results")
    offfile = joinpath(local_dir, "$name.offset"); newfile = joinpath(local_dir, "$name.new")
    offset = isfile(offfile) ? parse(Int, readchomp(offfile)) : 0
    seen = Set{String}()                                # sigma of every extension found in this run
    if isfile(newfile)
        foreach(l -> push!(seen, split(l)[1]), readlines(newfile))
    end
    hitsdone = 0; passed = 0; spaces = 0; knownhits = 0; lastanchor = 0
    println(now(), " stream start: offset = $offset, known sigma = ", length(known)); flush(stdout)
    while true
        size = parse(Int, remote(host, "stat -c %s $rdir/$name.hits"))
        scanned = parse(Int, remote(host, "grep -c '^anchor' $rdir/pilot.log || true"))
        if size > offset
            nbytes = min(size - offset, 60_000)             # about 2,000 hits per batch
            chunk = remote(host, "tail -c +$(offset + 1) $rdir/$name.hits | head -c $nbytes")
            cut = findlast('\n', chunk)
            if cut !== nothing
                body = chunk[1:cut]
                offset += ncodeunits(body)
                hits = [(parse(Int, f[1]), parse(UInt64, f[3]; base = 16)) for f in split.(split(body, '\n'; keepempty = false))]
                ok = Threads.Atomic{Int}(0)
                found = [Set{Vector{UInt64}}() for _ in 1:Threads.maxthreadid()]
                Threads.@threads :dynamic for (a, q) in hits
                    U = vcat(anchors[a], q)
                    passes_delta8(U, flats, pts) || continue
                    Threads.atomic_add!(ok, 1)
                    sols, _, _ = extensions_fast(U, flats; iters, rng = Xoshiro(hash(q)))
                    union!(found[Threads.threadid()], sols)
                end
                S = reduce(union, found)
                hitsdone += length(hits); passed += ok[]; spaces += length(S)
                lastanchor = maximum(first, hits)
                for s in S
                    lut = lut_of(s)
                    F = SBox{10}(lut)
                    VBF.differential_uniformity(F) == 2 || error("an extension is not APN")
                    h = sigma_hash(F)
                    if h in known
                        knownhits += 1
                    elseif !(h in seen)
                        push!(seen, h)
                        open(io -> println(io, h, " ", join(Int.(lut), ",")), newfile, "a")
                        println(now(), " NEW class sigma = ", h[1:16], "... (anchor ", lastanchor, ")"); flush(stdout)
                    end
                end
                write(offfile, string(offset))
                println(now(), " progress: anchors scanned $scanned/$nanchors, hits checked $hitsdone ",
                        "(up to anchor $lastanchor), prefilter passed $passed, APN spaces $spaces, ",
                        "known $knownhits, new classes ", length(seen)); flush(stdout)
                continue                                    # read again at once: more may be waiting
            end
        end
        if scanned == nanchors && offset >= size
            println(now(), " done: hits checked $hitsdone, new classes ", length(seen)); flush(stdout)
            return
        end
        sleep(poll)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    pilot_stream(ARGS[1], ARGS[2], ARGS[3], ARGS[4];
                 poll = length(ARGS) > 4 ? parse(Int, ARGS[5]) : 60,
                 iters = length(ARGS) > 5 ? parse(Int, ARGS[6]) : 30_000)
end
