# anf.jl — compact lossless storage for quadratic vectorial functions over F₂⁸.
#
# A quadratic F: F₂⁸→F₂⁸ is determined by its degree-≤2 ANF: 1 constant + 8 linear
# + 28 quadratic monomials = 37 byte-coefficients (bit b of coeff k = the k-th
# monomial's coefficient in output bit b). The Möbius transform reconstructs the
# 256-byte LUT exactly, so this is ~7× smaller than raw LUTs and ~24× smaller than
# the decimal-text catalogs — small enough to share a multi-million-function
# catalog as a ~139 MB file.
#
# File format ".anf": magic "QAPN8\0" | version u8=1 | bytes_per u8=37 |
#                     count u32(LE) | count × 37 bytes.
module ANF
export anf_pack, anf_unpack, write_anf, read_anf_luts, foreach_anf_lut, parse_lut_line

# 37 low-degree monomial masks for n=8: const, 8 singletons, 28 pairs
const MASKS = let m = UInt8[0]
    for i in 0:7; push!(m, UInt8(1) << i); end
    for i in 0:7, j in (i+1):7; push!(m, UInt8((1 << i) | (1 << j))); end
    m
end
const MAGIC = b"QAPN8\0"
const NB    = 37

# parse one LUT line, delimiter-agnostic: handles [0,1,..] (2025) and {0, 1, ..} (2021)
parse_lut_line(ln::AbstractString) =
    UInt8[parse(Int, m.match) for m in eachmatch(r"-?\d+", ln)]

# pack a quadratic LUT (256 UInt8) -> 37 ANF coeff bytes; nothing if deg > 2
function anf_pack(lut::AbstractVector{UInt8})
    coeff = zeros(UInt8, NB)
    f = Vector{Bool}(undef, 256)
    for b in 0:7
        @inbounds for x in 0:255; f[x+1] = ((lut[x+1] >> b) & 1) == 1; end
        # in-place Möbius (ANF) transform
        for i in 0:7
            s = 1 << i
            @inbounds for x in 0:255
                (x & s) != 0 && (f[x+1] ⊻= f[(x ⊻ s)+1])
            end
        end
        @inbounds for x in 0:255
            (f[x+1] && count_ones(UInt8(x)) > 2) && return nothing   # not quadratic
        end
        @inbounds for k in 1:NB
            f[Int(MASKS[k])+1] && (coeff[k] |= UInt8(1) << b)
        end
    end
    coeff
end

# reconstruct the 256-byte LUT from 37 ANF coeff bytes
function anf_unpack(coeff::AbstractVector{UInt8})
    lut = zeros(UInt8, 256)
    @inbounds for x in 0:255
        acc = UInt8(0); xb = UInt8(x)
        for k in 1:NB
            (xb & MASKS[k]) == MASKS[k] && (acc ⊻= coeff[k])
        end
        lut[x+1] = acc
    end
    lut
end

# stream a line-based decimal-LUT text file (one JSON array per line) -> .anf
# returns (count, n_skipped_nonquadratic)
function pack_text_file(in_path::AbstractString, out_path::AbstractString)
    count = 0; skipped = 0
    open(out_path, "w") do io
        write(io, MAGIC); write(io, UInt8(1)); write(io, UInt8(NB))
        write(io, UInt32(0))                       # placeholder count
        for ln in eachline(in_path)
            isempty(strip(ln)) && continue
            lut = parse_lut_line(ln)
            length(lut) == 256 || continue
            c = anf_pack(lut)
            c === nothing && (skipped += 1; continue)
            write(io, c); count += 1
        end
        seek(io, length(MAGIC) + 2)
        write(io, UInt32(count))
    end
    (count, skipped)
end

function _open_anf(io)
    magic = read(io, length(MAGIC)); magic == MAGIC || error("bad .anf magic")
    read(io, UInt8); nb = read(io, UInt8); nb == NB || error("unexpected bytes/func $nb")
    Int(read(io, UInt32))
end

# call f(lut::Vector{UInt8}) for each function, streaming (no full-file materialize)
function foreach_anf_lut(f, path::AbstractString)
    open(path) do io
        n = _open_anf(io); buf = Vector{UInt8}(undef, NB)
        for _ in 1:n
            read!(io, buf); f(anf_unpack(buf))
        end
    end
end

function read_anf_luts(path::AbstractString)
    out = Vector{Vector{UInt8}}()
    foreach_anf_lut(lut -> push!(out, lut), path)
    out
end

write_anf = pack_text_file
end # module
