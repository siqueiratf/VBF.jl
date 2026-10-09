# Self-test of crosscheck.jl.
#   julia --project=$ROOT selftest.jl OUTFILE [TXTFILE] [N]
# 1. The fast σ and the fast differential uniformity are equal to VBFCatalog.sigma_hash
#    and VBF.differential_uniformity on the first N records of OUTFILE (.out format), and
#    on N random LUTs (non-APN control: both must report "not APN").
# 2. If TXTFILE (plain "TT=" text) is given: record i of OUTFILE has the same LUT as
#    line i of TXTFILE, for all lines of TXTFILE.
include(joinpath(@__DIR__, "crosscheck.jl"))
using Random

function selftest(outfile, txtfile, N)
    io = open(outfile, "r"); buf = Vector{UInt8}(undef, 64)
    luts = Vector{UInt8}[]
    while !eof(io) && length(luts) < max(N, txtfile === nothing ? 0 : 200_000)
        readbytes!(io, buf, 64)
        w = reinterpret(UInt64, buf)
        push!(luts, lut_from_masks!(Vector{UInt8}(undef, 256), ntuple(k -> w[k], 8)))
    end
    close(io)
    w = Work(); bad = 0; t_fast = 0.0; t_ref = 0.0
    for i in 1:N
        F = SBox{8,UInt8}(luts[i])
        t_fast += @elapsed (d1 = du_fast(w, luts[i]); s1 = sigma_fast(w, F))
        t_ref += @elapsed (d2 = differential_uniformity(F); s2 = digest_from_hex(VBFCatalog.sigma_hash(F)))
        (d1 == d2 == 2 && s1 == s2 && algebraic_degree(F) == 2) || (bad += 1)
    end
    @printf("decoded .out records: %d checked, %d disagreements (APN, degree 2, fast σ = sigma_hash)\n", N, bad)
    @printf("time per record: fast %.3f ms, reference %.3f ms\n", 1e3t_fast / N, 1e3t_ref / N)
    rng = Xoshiro(1); badr = 0
    for i in 1:N
        L = rand(rng, UInt8, 256)
        F = SBox{8,UInt8}(L)
        du_fast(w, L) == differential_uniformity(F) || (badr += 1)
        (VBF.ortho_derivative(F) === nothing) || (badr += 1)
    end
    @printf("random LUTs: %d checked, %d disagreements\n", N, badr)
    if txtfile !== nothing
        k = 0; mism = 0; lut = Vector{UInt8}(undef, 256)
        for l in eachline(txtfile)
            startswith(l, "TT=") || continue
            parse_ints!(lut, l[4:end]) == 256 || break   # last line of a truncated prefix
            k += 1
            k > length(luts) && break
            lut == luts[k] || (mism += 1)
        end
        @printf("TT lines vs .out records: %d compared, %d mismatches\n", k, mism)
    end
end

selftest(ARGS[1], length(ARGS) >= 2 ? ARGS[2] : nothing, length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 2000)
