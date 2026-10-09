# Cross-check of every record of the Langevin n = 8 APN data files against the σ index.
#
# Usage:
#   julia -t 5 --project=$ROOT crosscheck.jl [options] FILE...
#   julia      --project=$ROOT crosscheck.jl --union [options]
# Options:
#   --outdir DIR       output directory (default: the directory of this script)
#   --statedir DIR     checkpoint directory (default: OUTDIR/state; about 150 MB per file)
#   --limit N          stop after N records per file (0 = all)
#   --ckpt N           checkpoint every N records (default 1_000_000)
#   --batch N          records per threaded batch (default 20_000)
#   --spot K           compare the fast σ with VBFCatalog.sigma_hash on every K-th
#                      quadratic APN record (default 997)
#   --union            only merge the per-file states and print the union counts
#
# File formats (detected from the name):
#   *.out         64-byte records: 8 little-endian UInt64; word k is coordinate k as a
#                 28-bit mask over the monomials x_i x_j (i < j) in colex order.
#   *.txt.gz      text, one "TT= v0 ... v255" line per record (via `gzip -dc`).
#   *.txt         same, plain.
#   *.tar         (plain or gzip-compressed) tar of sage files, one "[v0,...,v255]," line
#                 per record (via `tar -xf --to-command`, which adds "#MEMBER name" lines).
#
# Record id: the 1-based record number for *.out, the 1-based line number for *.txt(.gz),
# and "member:line" for *.tar.
#
# Outputs in OUTDIR (FILE = basename):
#   STATEDIR/FILE.jls            checkpoint (resumable; marked complete at the end)
#   results/FILE.toml            per-file counters
#   not_in_index_FILE.tsv        quadratic APN records whose σ is absent from the index
#   coincide553_FILE.tsv         records whose σ equals one of the 553 "new" σ
#   results/summary.tsv          one line per file

using VBF, VBFCatalog, Serialization, Printf, Dates
const SHA = VBFCatalog.SHA
const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface

const SCRIPT_DIR = @__DIR__
const ROOT = normpath(joinpath(SCRIPT_DIR, "..", "..", ".."))
const NEW553 = joinpath(ROOT, "census", "quadratic_apn8", "new_classes_553.tsv")

const Digest = NTuple{4,UInt64}
const STATEDIR = Ref("")   # checkpoint directory (--statedir, default OUTDIR/state)

digest_from_bytes(b::AbstractVector{UInt8}) =
    (length(b) == 32 || error("digest length $(length(b))");
     v = reinterpret(UInt64, Vector{UInt8}(b)); (v[1], v[2], v[3], v[4]))
digest_from_hex(h::AbstractString) = digest_from_bytes(hex2bytes(h))
digest_hex(d::Digest) = bytes2hex(reinterpret(UInt8, collect(d)))

# --------------------------------------------------------------------------------------
# Fast σ. It computes the same string as VBFCatalog.sigma_key and the same SHA-256 as
# VBFCatalog.sigma_hash. The ortho-derivative is VBF.ortho_derivative itself; only the
# two spectra use count arrays instead of Dict-backed Spectrum objects.
# --------------------------------------------------------------------------------------

struct Work
    cnt::Vector{Int}      # DDT row counts
    dsp::Vector{Int}      # differential spectrum histogram, index value+1
    wsp::Vector{Int}      # absolute Walsh spectrum histogram, index value+1
    v::Vector{Int32}      # FWHT buffer
end
Work() = Work(zeros(Int, 256), zeros(Int, 257), zeros(Int, 257), zeros(Int32, 256))

@inline function fwht256!(v::Vector{Int32})
    block = 1
    @inbounds while block < 256
        step = 2block
        for start = 0:step:255
            @simd for i = 1:block
                a = v[start+i]; b = v[start+i+block]
                v[start+i] = a + b; v[start+i+block] = a - b
            end
        end
        block = step
    end
    v
end

function hist_pairs(h::Vector{Int})
    out = Pair{Int,Int}[]
    @inbounds for i in eachindex(h)
        h[i] == 0 || push!(out, (i - 1) => h[i])
    end
    out
end

# Differential uniformity (as VBF.differential_uniformity) with a reusable buffer.
function du_fast(w::Work, lut::Vector{UInt8})
    cnt = w.cnt; u = 0
    @inbounds for a = 1:255
        fill!(cnt, 0)
        for x = 0:255
            cnt[(lut[x+1] ⊻ lut[(x⊻a)+1])+1] += 1
        end
        m = maximum(cnt); m > u && (u = m)
    end
    u
end

# Returns nothing when the ortho-derivative is undefined.
function sigma_fast(w::Work, F::SBox{8,UInt8})
    P = VBF.ortho_derivative(F)
    P === nothing && return nothing
    p = P.lut
    cnt = w.cnt; dsp = w.dsp; wsp = w.wsp; v = w.v
    fill!(dsp, 0); fill!(wsp, 0)
    @inbounds for a = 1:255
        fill!(cnt, 0)
        for x = 0:255
            cnt[(p[x+1] ⊻ p[(x⊻a)+1])+1] += 1
        end
        for b = 1:256
            dsp[cnt[b]+1] += 1
        end
    end
    @inbounds for b = 0:255
        bb = UInt8(b)
        for x = 0:255
            v[x+1] = Int32(1) - Int32(2) * Int32(count_ones(bb & p[x+1]) & 1)
        end
        fwht256!(v)
        for a = 0:255
            (a == 0 && b == 0) && continue
            wsp[abs(v[a+1])+1] += 1
        end
    end
    key = (hist_pairs(dsp), hist_pairs(wsp))
    digest_from_bytes(SHA.sha256(string(key)))
end

# --------------------------------------------------------------------------------------
# Decoding
# --------------------------------------------------------------------------------------

# Quadratic monomials x_i x_j (i < j) in colex order: (0,1),(0,2),(1,2),(0,3),...
const COLEX = [(i, j) for j in 0:7 for i in 0:j-1]
const QMON = UInt32[sum(UInt32(((x >> i) & 1) & ((x >> j) & 1)) << (t - 1)
                       for (t, (i, j)) in enumerate(COLEX)) for x in 0:255]

function lut_from_masks!(lut::Vector{UInt8}, masks::NTuple{8,UInt64})
    @inbounds for x = 0:255
        q = QMON[x+1]; y = 0x00
        for k = 0:7
            y |= UInt8(count_ones(UInt32(masks[k+1] & 0x0fffffff) & q) & 1) << k
        end
        lut[x+1] = y
    end
    lut
end

# Parses all decimal integers of a line into lut. Returns the number of integers found
# (-1 if one exceeds 255). Only the first 256 are stored.
function parse_ints!(lut::Vector{UInt8}, s::AbstractString)
    n = 0; cur = 0; indig = false; bad = false
    @inbounds for c in codeunits(s)
        if 0x30 <= c <= 0x39
            cur = 10cur + (c - 0x30); indig = true
            cur > 255 && (bad = true; cur = 0)
        elseif indig
            n += 1; n <= 256 && (lut[n] = UInt8(cur)); cur = 0; indig = false
        end
    end
    if indig
        n += 1; n <= 256 && (lut[n] = UInt8(cur))
    end
    bad ? -1 : n
end

# --------------------------------------------------------------------------------------
# Record stream: batches of (id, lut, parse_ok)
# --------------------------------------------------------------------------------------

mutable struct Batch
    ids::Vector{String}
    luts::Vector{Vector{UInt8}}
    ok::Vector{Bool}
    nother::Int                       # non-record lines in this batch
    other_samples::Vector{String}
end
Batch() = Batch(String[], Vector{UInt8}[], Bool[], 0, String[])

function fmt_of(path)
    b = basename(path)
    endswith(b, ".out") && return :bin
    endswith(b, ".txt.gz") && return :gztext
    endswith(b, ".txt") && return :text
    endswith(b, ".tar") && return :tar
    error("unknown format: $path")
end

function open_stream(path, fmt)
    fmt === :bin && return open(path, "r")
    fmt === :text && return open(path, "r")
    fmt === :gztext && return open(`gzip -dc $path`, "r")
    fmt === :tar && return open(`tar -xf $path --to-command='printf "#MEMBER %s\n" "$TAR_FILENAME"; cat; printf "\n"'`, "r")
end

# Producer: puts batches into ch. Skips the first `skip` records (resume).
function produce!(ch::Channel{Batch}, path, fmt, skip::Int, limit::Int, bsize::Int)
    io = open_stream(path, fmt)
    nrec = 0
    b = Batch()
    flush!() = (put!(ch, b); b = Batch())
    try
        if fmt === :bin
            buf = Vector{UInt8}(undef, 64)
            while !eof(io)
                (limit > 0 && nrec >= limit) && break
                nb = readbytes!(io, buf, 64)
                nrec += 1
                if nb < 64
                    nrec > skip && (push!(b.ids, string(nrec)); push!(b.luts, zeros(UInt8, 256)); push!(b.ok, false))
                    break
                end
                nrec <= skip && continue
                w = reinterpret(UInt64, buf)
                m = ntuple(k -> ltoh(w[k]), 8)
                push!(b.ids, string(nrec)); push!(b.luts, lut_from_masks!(Vector{UInt8}(undef, 256), m)); push!(b.ok, true)
                length(b.ids) >= bsize && flush!()
            end
        else
            member = ""; ln = 0
            for line in eachline(io)
                if fmt === :tar && startswith(line, "#MEMBER ")
                    member = line[9:end]; ln = 0; continue
                end
                ln += 1
                s = lstrip(line)
                isrec = startswith(s, "TT=") || startswith(s, "[")
                if !isrec
                    # Lines without a record marker: count them; flag long numeric lines.
                    lut = Vector{UInt8}(undef, 256)
                    k = parse_ints!(lut, s)
                    if k >= 100
                        isrec = true
                    else
                        b.nother += 1
                        length(b.other_samples) < 5 && push!(b.other_samples, first(line, 80))
                        continue
                    end
                end
                (limit > 0 && nrec >= limit) && break
                nrec += 1
                nrec <= skip && continue
                lut = Vector{UInt8}(undef, 256)
                k = parse_ints!(lut, startswith(s, "TT=") ? s[4:end] : s)
                id = fmt === :tar ? string(member, ":", ln) : string(ln)
                push!(b.ids, id); push!(b.luts, lut); push!(b.ok, k == 256)
                length(b.ids) >= bsize && flush!()
            end
        end
        put!(ch, b)
    finally
        close(io)
        # A broken pipe from an early stop (limit) is expected; ignore it.
        if io isa Base.Process
            try; kill(io); catch; end
        end
    end
    nothing
end

# --------------------------------------------------------------------------------------
# State
# --------------------------------------------------------------------------------------

mutable struct State
    file::String
    size::Int
    done::Int                  # records processed
    complete::Bool
    parse_errors::Int
    other_lines::Int
    other_samples::Vector{String}
    non_apn::Int
    non_quadratic::Int         # degree != 2 (counted for every parsed record)
    od_errors::Int             # quadratic APN but ortho-derivative undefined
    qapn::Int                  # quadratic APN records
    rec_in_index::Int
    rec_not_in_index::Int
    spot_checked::Int
    spot_mismatch::Int
    sigmas::Set{Digest}        # distinct σ of the file
    misses::Vector{Tuple{String,String,String}}   # (id, sigma hex, lut hex)
    coincide::Vector{Tuple{String,String,String}} # (id, sigma hex, lut hex)
    examples::Vector{Tuple{String,String}}        # (kind, id) first bad records
    seconds::Float64
end
State(file, size) = State(file, size, 0, false, 0, 0, String[], 0, 0, 0, 0, 0, 0, 0, 0,
                          Set{Digest}(), Tuple{String,String,String}[],
                          Tuple{String,String,String}[], Tuple{String,String}[], 0.0)

function save_state(st::State, path)
    tmp = path * ".tmp"
    open(io -> serialize(io, st), tmp, "w")
    mv(tmp, path; force = true)
end

# --------------------------------------------------------------------------------------
# Index
# --------------------------------------------------------------------------------------

function load_index()
    p = VBFCatalog.sigma_index_path()
    db = SQLite.DB("file:" * p * "?mode=ro"; )
    srcs = String[]; srcid = Dict{String,Int}()
    idx = Dict{Digest,UInt16}()
    sizehint!(idx, 4_000_000)
    for r in DBInterface.execute(db, "SELECT sigma_hash, source FROM ccz_sigma_index WHERE n = 8")
        s = String(r.source)
        k = get!(srcid, s) do
            push!(srcs, s); length(srcs)
        end
        d = digest_from_hex(String(r.sigma_hash))
        idx[d] = get(idx, d, 0x0000) | (UInt16(1) << (k - 1))
    end
    close(db)
    idx, srcs
end

function load_553()
    d = Dict{Digest,String}()
    for l in eachline(NEW553)
        isempty(strip(l)) && continue
        f = split(l, '\t')
        length(f[1]) == 64 || continue
        d[digest_from_hex(f[1])] = length(f) >= 2 ? f[2] : ""
    end
    d
end

# --------------------------------------------------------------------------------------
# Main per-file loop
# --------------------------------------------------------------------------------------

# Worker: one contiguous range of a batch. A separate function, so that no local
# variable is shared between threads through a closure.
function work_chunk!(w::Work, b::Batch, rng, du, deg, sig, spotdone, spotbad, base, spot)
    for i in rng
        b.ok[i] || continue
        F = SBox{8,UInt8}(b.luts[i])
        du[i] = du_fast(w, b.luts[i])
        deg[i] = algebraic_degree(F)
        (du[i] == 2 && deg[i] == 2) || continue
        s = sigma_fast(w, F)
        sig[i] = s
        if s !== nothing && (base + i) % spot == 0
            spotdone[i] = true
            spotbad[i] = digest_from_hex(VBFCatalog.sigma_hash(F)) == s ? 0 : 1
        end
    end
    nothing
end

function process_file(path, idx, srcs, new553, outdir; limit = 0, ckpt = 1_000_000,
                      bsize = 20_000, spot = 997)
    name = basename(path)
    fmt = fmt_of(path)
    statedir = STATEDIR[]; mkpath(statedir)
    resdir = joinpath(outdir, "results"); mkpath(resdir)
    spath = joinpath(statedir, name * ".jls")
    fsize = filesize(path)
    st = if isfile(spath)
        s = deserialize(spath)
        s.size == fsize || error("$name: size changed since the checkpoint")
        s
    else
        State(name, fsize)
    end
    if st.complete
        @printf("%s: complete in checkpoint (%d records), skipped\n", name, st.done)
        return st
    end
    st.done > 0 && @printf("%s: resume after %d records\n", name, st.done)
    srcmask = Dict{UInt16,Int}()
    nt = Threads.nthreads()
    works = [Work() for _ in 1:nt]
    ch = Channel{Batch}(3)
    prod = Threads.@spawn produce!(ch, path, fmt, st.done, limit, bsize)
    bind(ch, prod)
    t0 = time(); t_last = t0; done0 = st.done; last_ckpt = st.done
    for b in ch
        n = length(b.ids)
        st.other_lines += b.nother
        for s in b.other_samples
            length(st.other_samples) < 10 && push!(st.other_samples, s)
        end
        n == 0 && continue
        du = zeros(Int, n); deg = zeros(Int, n)
        sig = Vector{Union{Nothing,Digest}}(nothing, n)
        spotbad = zeros(Int, n); spotdone = zeros(Bool, n)
        base = st.done
        chunks = collect(Iterators.partition(1:n, cld(n, nt)))
        @sync for (ci, rng) in enumerate(chunks)
            Threads.@spawn work_chunk!(works[ci], b, rng, du, deg, sig, spotdone, spotbad, base, spot)
        end
        for i in 1:n
            st.done += 1
            if !b.ok[i]
                st.parse_errors += 1
                length(st.examples) < 20 && push!(st.examples, ("parse_error", b.ids[i]))
                continue
            end
            du[i] == 2 || (st.non_apn += 1; length(st.examples) < 20 && push!(st.examples, ("non_apn du=$(du[i])", b.ids[i])))
            deg[i] == 2 || (st.non_quadratic += 1; length(st.examples) < 20 && push!(st.examples, ("degree=$(deg[i])", b.ids[i])))
            (du[i] == 2 && deg[i] == 2) || continue
            s = sig[i]
            if s === nothing
                st.od_errors += 1
                length(st.examples) < 20 && push!(st.examples, ("od_undefined", b.ids[i]))
                continue
            end
            st.qapn += 1
            spotdone[i] && (st.spot_checked += 1; st.spot_mismatch += spotbad[i])
            push!(st.sigmas, s)
            if haskey(idx, s)
                st.rec_in_index += 1
            else
                st.rec_not_in_index += 1
                length(st.misses) < 2_000_000 ||
                    error("$name: more than 2,000,000 misses; the decoding is probably wrong")
                push!(st.misses, (b.ids[i], digest_hex(s), bytes2hex(b.luts[i])))
            end
            if haskey(new553, s)
                push!(st.coincide, (b.ids[i], digest_hex(s), bytes2hex(b.luts[i])))
            end
        end
        now = time()
        if now - t_last > 60
            rate = (st.done - done0) / (now - t0)
            @printf("[%s] %s: %d records, %.0f rec/s, miss %d, 553-hits %d, distinct σ %d\n",
                    Dates.format(Dates.now(), "HH:MM:SS"), name, st.done, rate,
                    st.rec_not_in_index, length(st.coincide), length(st.sigmas))
            flush(stdout); t_last = now
        end
        if st.done - last_ckpt >= ckpt
            st.seconds += time() - t0
            save_state(st, spath)
            t0 = time(); done0 = st.done
            last_ckpt = st.done
        end
    end
    wait(prod)
    st.seconds += time() - t0
    st.complete = true
    save_state(st, spath)
    write_outputs(st, idx, srcs, outdir)
    st
end

safe(name) = replace(name, r"[^A-Za-z0-9._-]" => "_")

function write_outputs(st::State, idx, srcs, outdir)
    name = st.file
    # σ found in index, by source
    found = 0; notfound = 0; bysrc = zeros(Int, length(srcs))
    for s in st.sigmas
        m = get(idx, s, nothing)
        if m === nothing
            notfound += 1
        else
            found += 1
            for k in 1:length(srcs)
                (m >> (k - 1)) & 1 == 1 && (bysrc[k] += 1)
            end
        end
    end
    open(joinpath(outdir, "not_in_index_" * safe(name) * ".tsv"), "w") do io
        println(io, "record\tsigma_hash\tlut_hex")
        for (a, b, c) in st.misses; println(io, a, '\t', b, '\t', c); end
    end
    open(joinpath(outdir, "coincide553_" * safe(name) * ".tsv"), "w") do io
        println(io, "record\tsigma_hash\tlut_hex")
        for (a, b, c) in st.coincide; println(io, a, '\t', b, '\t', c); end
    end
    c553 = length(unique(x[2] for x in st.coincide))
    open(joinpath(outdir, "results", safe(name) * ".toml"), "w") do io
        println(io, "file = \"", name, "\"")
        println(io, "bytes = ", st.size)
        println(io, "records = ", st.done)
        println(io, "other_lines = ", st.other_lines)
        println(io, "parse_errors = ", st.parse_errors)
        println(io, "non_apn = ", st.non_apn)
        println(io, "non_quadratic = ", st.non_quadratic)
        println(io, "od_undefined = ", st.od_errors)
        println(io, "quadratic_apn = ", st.qapn)
        println(io, "distinct_sigma = ", length(st.sigmas))
        println(io, "distinct_sigma_in_index = ", found)
        println(io, "distinct_sigma_not_in_index = ", notfound)
        println(io, "records_in_index = ", st.rec_in_index)
        println(io, "records_not_in_index = ", st.rec_not_in_index)
        println(io, "distinct_sigma_in_553 = ", c553)
        println(io, "records_in_553 = ", length(st.coincide))
        println(io, "spot_checked = ", st.spot_checked)
        println(io, "spot_mismatch = ", st.spot_mismatch)
        println(io, "seconds = ", round(st.seconds; digits = 1))
        println(io, "other_line_samples = ", repr(st.other_samples))
        println(io, "examples = ", repr(st.examples))
        println(io, "[distinct_sigma_by_source]")
        for k in 1:length(srcs); println(io, srcs[k], " = ", bysrc[k]); end
    end
    # summary.tsv: rewrite from all result files
    rows = String[]
    for f in sort(readdir(STATEDIR[]))
        endswith(f, ".jls") || continue
        s = deserialize(joinpath(STATEDIR[], f))
        s.complete || continue
        nf = count(x -> !haskey(idx, x), s.sigmas)
        push!(rows, join(Any[s.file, s.done, s.parse_errors, s.non_apn, s.non_quadratic,
                             s.od_errors, length(s.sigmas), length(s.sigmas) - nf, nf,
                             s.rec_not_in_index, length(unique(x[2] for x in s.coincide)),
                             s.spot_checked, s.spot_mismatch, round(s.seconds; digits = 1)], '\t'))
    end
    open(joinpath(outdir, "results", "summary.tsv"), "w") do io
        println(io, join(["file", "records", "parse_errors", "non_apn", "non_quadratic",
                          "od_undefined", "distinct_sigma", "sigma_in_index",
                          "sigma_not_in_index", "records_not_in_index", "sigma_in_553",
                          "spot_checked", "spot_mismatch", "seconds"], '\t'))
        foreach(r -> println(io, r), rows)
    end
    @printf("%s: records %d, parse errors %d, non-APN %d, non-quadratic %d, distinct σ %d, in index %d, NOT in index %d, in 553 %d, spot %d/%d mismatches, %.0f s\n",
            name, st.done, st.parse_errors, st.non_apn, st.non_quadratic, length(st.sigmas),
            found, notfound, c553, st.spot_mismatch, st.spot_checked, st.seconds)
end

function union_report(outdir, idx, srcs)
    U = Set{Digest}()
    for f in sort(readdir(STATEDIR[]))
        endswith(f, ".jls") || continue
        s = deserialize(joinpath(STATEDIR[], f))
        union!(U, s.sigmas)
        @printf("%-36s complete=%s records=%d distinct σ=%d\n", s.file, s.complete, s.done, length(s.sigmas))
    end
    nin = count(x -> haskey(idx, x), U)
    bysrc = zeros(Int, length(srcs)); only_simon = 0
    for s in U
        m = get(idx, s, nothing); m === nothing && continue
        for k in 1:length(srcs); (m >> (k - 1)) & 1 == 1 && (bysrc[k] += 1); end
    end
    missing_from_raw = length(idx) - nin
    open(joinpath(outdir, "results", "union.toml"), "w") do io
        println(io, "union_distinct_sigma = ", length(U))
        println(io, "union_in_index = ", nin)
        println(io, "union_not_in_index = ", length(U) - nin)
        println(io, "index_distinct_sigma_n8 = ", length(idx))
        println(io, "index_sigma_absent_from_langevin_files = ", missing_from_raw)
        println(io, "[union_by_source]")
        for k in 1:length(srcs); println(io, srcs[k], " = ", bysrc[k]); end
    end
    print(read(joinpath(outdir, "results", "union.toml"), String))
end

function main(args)
    outdir = SCRIPT_DIR; statedir = ""; limit = 0; ckpt = 1_000_000; bsize = 20_000; spot = 997
    files = String[]; dounion = false
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--outdir"; outdir = args[i+1]; i += 2
        elseif a == "--statedir"; statedir = args[i+1]; i += 2
        elseif a == "--limit"; limit = parse(Int, args[i+1]); i += 2
        elseif a == "--ckpt"; ckpt = parse(Int, args[i+1]); i += 2
        elseif a == "--batch"; bsize = parse(Int, args[i+1]); i += 2
        elseif a == "--spot"; spot = parse(Int, args[i+1]); i += 2
        elseif a == "--union"; dounion = true; i += 1
        else push!(files, a); i += 1
        end
    end
    STATEDIR[] = isempty(statedir) ? joinpath(outdir, "state") : statedir
    mkpath(outdir); mkpath(joinpath(outdir, "results")); mkpath(STATEDIR[])
    @printf("threads=%d outdir=%s limit=%d ckpt=%d\n", Threads.nthreads(), outdir, limit, ckpt)
    t = @elapsed (idx, srcs) = load_index()
    @printf("index: %d distinct n=8 σ from %d sources (%.0f s)\n", length(idx), length(srcs), t)
    if dounion
        union_report(outdir, idx, srcs); return
    end
    new553 = load_553()
    @printf("553 file: %d distinct σ\n", length(new553))
    length(new553) == 553 || error("expected 553 σ in $NEW553")
    n553_in_index = count(k -> haskey(idx, k), keys(new553))
    @printf("553 σ present in the index: %d (expected 0)\n", n553_in_index)
    flush(stdout)
    for f in files
        process_file(f, idx, srcs, new553, outdir; limit, ckpt, bsize, spot)
        flush(stdout)
    end
end

abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
