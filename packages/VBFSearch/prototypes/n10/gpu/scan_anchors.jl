# Pilot step 2 (GPU): scan the cosets of every anchor in a file written by
# ../pilot_export.jl. Writes one line per hit: anchor index, coset index and the
# form q (hex), so the CPU side does not depend on the complement basis.
#
# Options (environment):
#   N10_WINDOW=lo:hi    keep cosets whose bent count is in lo:hi (default: the
#                       need of the anchor file)
#   N10_LOG_COSETS=k    scan the first 2^k cosets only (default 38 = all)
#   N10_HIST=1          also print the exact histogram of the coset counts
#                       (slower: no early exit)
# Run:
#   N10_BACKEND=amdgpu julia -O3 --project=amd scan_anchors.jl <file.anchors> <out.hits> [first] [last]
include(joinpath(@__DIR__, "coset_scan.jl"))

function parse_window(s, need)
    isempty(s) && return need:need
    lo, hi = parse.(Int, split(s, ':'))
    lo:hi
end

function scan_anchor_file(infile, outfile; first = 1, last = typemax(Int), logK = 8)
    lines = readlines(infile)
    logc = parse(Int, get(ENV, "N10_LOG_COSETS", "38"))
    hist_mode = get(ENV, "N10_HIST", "0") == "1"
    loglaunch = min(logc, hist_mode ? 30 : 32)
    open(outfile, "a") do io
        for (a, line) in enumerate(lines)
            first <= a <= last || continue
            f = split(line)
            window = parse_window(get(ENV, "N10_WINDOW", ""), parse(Int, f[1]))
            V7 = [parse(UInt64, x; base = 16) for x in f[2:end]]
            Vs = span(V7); Cb = complement_basis(V7)
            length(Cb) == 38 || error("anchor $a is not 7-dimensional")
            vs_d = devarray(slice_forms(Vs)); cr_d = devarray(reduce(vcat, form_rows.(Cb)))
            nt = 1 << (loglaunch - logK); total = 0; hist = zeros(Int, 129)
            t = @elapsed for base in UInt64(0):UInt64(1 << loglaunch):UInt64(2)^logc-1
                h, hits, nh = scan(vs_d, cr_d, base, nt, logK, window; exact = hist_mode, maxhits = 1 << 20, kernel = :sliced)
                nh > length(hits) && error("hit buffer overflow at anchor $a")
                hist_mode && (hist .+= h)
                for idx in hits
                    println(io, a, " ", idx, " ", string(coset_rep(idx, Cb); base = 16))
                end
                total += nh
            end
            flush(io)
            println("anchor $a: window = $window, cosets = 2^$logc, hits = $total, ", round(t / 60, digits = 1), " min")
            if hist_mode
                nz = findall(!iszero, hist)
                println("  histogram (count => cosets): ", join(["$(i-1)=>$(hist[i])" for i in nz], " "))
            end
            flush(stdout)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    scan_anchor_file(ARGS[1], ARGS[2];
                     first = length(ARGS) > 2 ? parse(Int, ARGS[3]) : 1,
                     last = length(ARGS) > 3 ? parse(Int, ARGS[4]) : typemax(Int))
end
