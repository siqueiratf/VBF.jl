"""
Stream public quadratic APN records in decimal-LUT, gzip, tar or colex-mask format.
Only decodes original bytes; malformed/truncated records retain explicit flags.
This tools module does not verify APN or classify equivalence.
"""
module RawAPNReaders
# Quadratic monomials x_i x_j (i < j) in colex order: (0,1),(0,2),(1,2),(0,3),...
const COLEX = [(i, j) for j in 0:7 for i in 0:j-1]
const QMON = UInt32[sum(UInt32(((x >> i) & 1) & ((x >> j) & 1)) << (t - 1)
                       for (t, (i, j)) in enumerate(COLEX)) for x in 0:255]

function lut_from_masks!(lut::Vector{UInt8}, masks::NTuple{8,UInt64})
    length(lut)==256 && all(x->x>>28==0,masks) || throw(ArgumentError("expected eight 28-bit quadratic masks and 256-entry LUT"))
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
    occursin(r"-\s*\d",s) && return -1
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
                push!(b.ids, string(nrec)); push!(b.luts, lut_from_masks!(zeros(UInt8,256), m)); push!(b.ok, true)
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
                    lut = zeros(UInt8,256)
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
                lut = zeros(UInt8,256)
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


end
