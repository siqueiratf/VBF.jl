# Pilot step 2 (GPU): full 2^38 scan of every anchor in a file written by
# ../pilot_export.jl. Writes one line per hit: anchor index, coset index and the
# form q (hex), so the CPU side does not depend on the complement basis.
# Run:
#   N10_BACKEND=amdgpu julia -O3 --project=amd scan_anchors.jl <file.anchors> <out.hits> [first] [last]
include(joinpath(@__DIR__, "coset_scan.jl"))

function scan_anchor_file(infile, outfile; first = 1, last = typemax(Int), loglaunch = 34, logK = 8)
    lines = readlines(infile)
    open(outfile, "a") do io
        for (a, line) in enumerate(lines)
            first <= a <= last || continue
            f = split(line)
            need = parse(Int, f[1])
            V7 = [parse(UInt64, x; base = 16) for x in f[2:end]]
            Vs = span(V7); Cb = complement_basis(V7)
            length(Cb) == 38 || error("anchor $a is not 7-dimensional")
            vs_d = devarray(slice_forms(Vs)); cr_d = devarray(reduce(vcat, form_rows.(Cb)))
            nt = 1 << (loglaunch - logK); total = 0
            t = @elapsed for base in UInt64(0):UInt64(1 << loglaunch):UInt64(2)^38-1
                _, hits, nh = scan(vs_d, cr_d, base, nt, logK, need; kernel = :sliced)
                nh > length(hits) && error("hit buffer overflow at anchor $a")
                for idx in hits
                    println(io, a, " ", idx, " ", string(coset_rep(idx, Cb); base = 16))
                end
                total += nh
            end
            flush(io)
            println("anchor $a: need = $need, hits = $total, ", round(t / 60, digits = 1), " min"); flush(stdout)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    scan_anchor_file(ARGS[1], ARGS[2];
                     first = length(ARGS) > 2 ? parse(Int, ARGS[3]) : 1,
                     last = length(ARGS) > 3 ? parse(Int, ARGS[4]) : typemax(Int))
end
