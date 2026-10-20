# Streaming, auditable check of the hits of a running gpu/scan_anchors.jl job.
#
# Every `poll` seconds it reads only the new bytes of the remote hit file (at most
# 60 KB, about 2,000 hits per batch), applies the delta-8 prefilter and ISD to the
# new hits, and classifies every APN extension. All results are written at once to
# results/<name>/, so they can be inspected while the search runs:
#
#   occurrences.tsv  batch, anchor, q, space   one row per validated (hit, extension)
#   spaces.tsv       batch, space, sigma, class, seed_space, anchor, q
#                                              one row per distinct APN space
#                                              (canonical RREF basis of C2)
#   classes.tsv      batch, class, sigma, label, ea_confirmed, anchor, q
#                                              one row per distinct EA class
#   batches.tsv      batch, end_offset, time, then the cumulative counters
#                                              (the commit marker of a batch)
#   summary.txt      the latest counters, rewritten after every batch
#   new/<class>.lut  the LUT of every class outside the catalog
#
# A class is known if its sigma is in the catalog and one exact EA test against
# that catalog function confirms it. Equal sigma never merges classes without that
# test. A space is a seed space if its canonical basis equals that of C2(seed).
#
# Resume: rows with a batch number above the last line of batches.tsv belong to an
# unfinished batch; they are removed, and the scan continues from its end_offset.
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/pilot_stream.jl \
#       <file.anchors> <host> <remote dir> <name> <seed catalog name> [poll s] [isd iters]
include(joinpath(@__DIR__, "pilot_check.jl"))           # lut_of, isd_fast.jl, VBF, VBFCatalog
using Dates, SHA

remote(host, cmd) = readchomp(`ssh -o BatchMode=yes -o ConnectTimeout=15 $host $cmd`)
space_id(S) = bytes2hex(sha256(reinterpret(UInt8, canon(S))))[1:16]
qhex(q) = string(q; base = 16)

const COUNTERS = (:hits, :passed, :hits_with_ext, :occurrences, :spaces, :seed_spaces,
                  :classes, :known_classes, :new_classes)

mutable struct StreamState
    batch::Int
    offset::Int
    count::Dict{Symbol,Int}
    spaces::Dict{String,String}                         # space id -> class id
    classes::Dict{String,Tuple{String,String,Vector{UInt16}}}   # class id -> (sigma, label, lut)
end

# Keep only the rows of committed batches; return the parsed rows.
function committed_rows(path, header, lastbatch)
    isfile(path) || (write(path, header * "\n"); return Vector{SubString{String}}[])
    lines = readlines(path)
    rows = [split(l, '\t') for l in lines[2:end] if !isempty(l)]
    keep = [r for r in rows if parse(Int, r[1]) <= lastbatch]
    if length(keep) < length(rows)
        open(path, "w") do io
            println(io, lines[1])
            foreach(r -> println(io, join(r, '\t')), keep)
        end
    end
    keep
end

function load_state(dir)
    mkpath(joinpath(dir, "new"))
    bfile = joinpath(dir, "batches.tsv")
    st = StreamState(0, 0, Dict(c => 0 for c in COUNTERS), Dict(), Dict())
    if isfile(bfile) && countlines(bfile) > 1
        last = split(readlines(bfile)[end], '\t')
        st.batch = parse(Int, last[1]); st.offset = parse(Int, last[2])
        for (i, c) in enumerate(COUNTERS)
            st.count[c] = parse(Int, last[3+i])
        end
    else
        write(bfile, join(["batch", "end_offset", "time", string.(COUNTERS)...], '\t') * "\n")
    end
    committed_rows(joinpath(dir, "occurrences.tsv"), "batch\tanchor\tq\tspace", st.batch)
    for r in committed_rows(joinpath(dir, "classes.tsv"), "batch\tclass\tsigma\tlabel\tea_confirmed\tanchor\tq", st.batch)
        lutfile = joinpath(dir, "new", "$(r[2]).lut")
        lut = isfile(lutfile) ? parse.(UInt16, split(readchomp(lutfile), ',')) : UInt16[]
        st.classes[r[2]] = (r[3], r[4], lut)
    end
    for r in committed_rows(joinpath(dir, "spaces.tsv"), "batch\tspace\tsigma\tclass\tseed_space\tanchor\tq", st.batch)
        st.spaces[r[2]] = r[4]
    end
    st
end

function write_summary(dir, st, scanned, nanchors, lastanchor)
    c = st.count
    text = """
    updated            $(now())
    batches            $(st.batch)   (remote offset $(st.offset) bytes)
    anchors scanned    $scanned / $nanchors on the GPU; checked up to anchor $lastanchor
    raw hits           $(c[:hits])
    prefilter passed   $(c[:passed])
    hits with an APN extension      $(c[:hits_with_ext])
    validated APN occurrences       $(c[:occurrences])
    distinct APN spaces             $(c[:spaces])   (identical to the seed space: $(c[:seed_spaces]))
    distinct EA classes             $(c[:classes])   (known: $(c[:known_classes]), NEW: $(c[:new_classes]))
    """
    for (id, (sigma, label, _)) in sort(collect(st.classes); by = first)
        text *= "  class $id  $label  sigma $(sigma[1:16])...\n"
    end
    tmp = joinpath(dir, "summary.txt.tmp"); write(tmp, text); mv(tmp, joinpath(dir, "summary.txt"); force = true)
end

function pilot_stream(anchorfile, host, rdir, name, seedname; poll = 60, iters = 120_000)  # E1: 30k missed 3 of 24 certain extensions
    anchors = [[parse(UInt64, x; base = 16) for x in split(l)[2:end]] for l in readlines(anchorfile)]
    nanchors = length(anchors)
    flats = all_flats(); pts = flat_points()
    db = load_catalog()
    catalog = Dict{String,Tuple{String,SBox{10,UInt16}}}()          # sigma -> (name, function)
    for r in list_functions(db; n = 10)
        F = load_sbox(db, r.id)
        VBF.algebraic_degree(F) == 2 || continue
        get!(catalog, sigma_hash(F), (r.canonical_name, F))
    end
    seed = load_sbox(db, seedname)
    seed_space = canon(comp_basis(Int.(seed.lut)))
    dir = joinpath(@__DIR__, "results", name)
    st = load_state(dir)
    println(now(), " stream start: batch $(st.batch), offset $(st.offset), catalog classes ", length(catalog),
            ", seed $seedname (sigma ", sigma_hash(seed)[1:16], "...)"); flush(stdout)

    while true
        size = parse(Int, remote(host, "stat -c %s $rdir/$name.hits"))
        scanned = parse(Int, remote(host, "grep -c '^anchor' $rdir/pilot.log || true"))
        if size > st.offset
            nbytes = min(size - st.offset, 60_000)
            # read, not readchomp: the final newline marks the last complete hit
            chunk = read(`ssh -o BatchMode=yes -o ConnectTimeout=15 $host "tail -c +$(st.offset + 1) $rdir/$name.hits | head -c $nbytes"`, String)
            cut = findlast('\n', chunk)
            if cut !== nothing
                body = chunk[1:cut]
                hits = [(parse(Int, f[1]), parse(UInt64, f[3]; base = 16)) for f in split.(split(body, '\n'; keepempty = false))]
                b = st.batch + 1
                # 1. prefilter + ISD in parallel; every result keeps its hit
                res = Vector{Vector{Vector{UInt64}}}(undef, length(hits))
                ok = falses(length(hits))
                Threads.@threads :dynamic for i in eachindex(hits)
                    a, q = hits[i]
                    U = vcat(anchors[a], q)
                    if passes_delta8(U, flats, pts)
                        ok[i] = true
                        sols, _, _ = extensions_fast(U, flats; iters, rng = Xoshiro(hash(q)))
                        res[i] = collect(sols)
                    else
                        res[i] = Vector{UInt64}[]
                    end
                end
                # 2. classify serially; append every row before the commit marker
                occ = open(joinpath(dir, "occurrences.tsv"), "a")
                spc = open(joinpath(dir, "spaces.tsv"), "a")
                cls = open(joinpath(dir, "classes.tsv"), "a")
                c = st.count
                c[:hits] += length(hits); c[:passed] += count(ok)
                for (i, (a, q)) in enumerate(hits)
                    isempty(res[i]) || (c[:hits_with_ext] += 1)
                    for S in res[i]
                        sid = space_id(S)
                        c[:occurrences] += 1
                        println(occ, b, '\t', a, '\t', qhex(q), '\t', sid)
                        haskey(st.spaces, sid) && continue
                        lut = lut_of(S); F = SBox{10}(lut)
                        VBF.differential_uniformity(F) == 2 || error("extension $sid is not APN")
                        sigma = sigma_hash(F)
                        is_seed = canon(S) == seed_space
                        # class: a catalog class (EA-confirmed), an earlier class, or NEW
                        cid = nothing
                        for (id, (s2, label, lut2)) in st.classes
                            s2 == sigma || continue
                            ref = startswith(label, "NEW") ? SBox{10}(lut2) : catalog[sigma][2]
                            are_ea_equivalent(F, ref) && (cid = id; break)
                        end
                        if cid === nothing
                            cid = "C" * lpad(length(st.classes) + 1, 4, '0')
                            confirmed = haskey(catalog, sigma) && are_ea_equivalent(F, catalog[sigma][2])
                            label = confirmed ? catalog[sigma][1] : "NEW-" * cid
                            st.classes[cid] = (sigma, label, confirmed ? UInt16[] : lut)
                            c[:classes] += 1
                            if confirmed
                                c[:known_classes] += 1
                            else
                                c[:new_classes] += 1
                                write(joinpath(dir, "new", "$cid.lut"), join(Int.(lut), ','))
                                println(now(), " NEW class $cid sigma ", sigma[1:16], "... at anchor $a, q ", qhex(q)); flush(stdout)
                            end
                            println(cls, b, '\t', cid, '\t', sigma, '\t', label, '\t', confirmed, '\t', a, '\t', qhex(q))
                        end
                        st.spaces[sid] = cid
                        c[:spaces] += 1; is_seed && (c[:seed_spaces] += 1)
                        println(spc, b, '\t', sid, '\t', sigma, '\t', cid, '\t', is_seed, '\t', a, '\t', qhex(q))
                    end
                end
                close(occ); close(spc); close(cls)
                st.batch = b; st.offset += ncodeunits(body)
                open(joinpath(dir, "batches.tsv"), "a") do io             # commit marker
                    println(io, join([b, st.offset, now(), (c[k] for k in COUNTERS)...], '\t'))
                end
                lastanchor = maximum(first, hits)
                write_summary(dir, st, scanned, nanchors, lastanchor)
                println(now(), " progress: anchors $scanned/$nanchors scanned (checked to $lastanchor) | hits $(c[:hits]) ",
                        "| prefilter $(c[:passed]) | hits with ext $(c[:hits_with_ext]) | occurrences $(c[:occurrences]) ",
                        "| spaces $(c[:spaces]) (seed $(c[:seed_spaces])) | classes $(c[:classes]) ",
                        "(known $(c[:known_classes]), NEW $(c[:new_classes]))"); flush(stdout)
                continue
            end
        end
        if scanned == nanchors && st.offset >= size
            println(now(), " done: batches $(st.batch), classes ", st.count[:classes], " (NEW ", st.count[:new_classes], ")"); flush(stdout)
            return
        end
        sleep(poll)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    pilot_stream(ARGS[1], ARGS[2], ARGS[3], ARGS[4], ARGS[5];
                 poll = length(ARGS) > 5 ? parse(Int, ARGS[6]) : 60,
                 iters = length(ARGS) > 6 ? parse(Int, ARGS[7]) : 120_000)
end
