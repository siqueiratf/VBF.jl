# Implements the status and novelty reports of the B6 = 52 extension search
# Study: B6 = 52 extension search (census/quadratic_apn8/search_b52)
#
# Math:
#   A search-new function is certified as a new CCZ class when (1) it is APN
#   (differential uniformity 2), (2) its recomputed sigma equals the recorded sigma, and
#   (3) the sigma is absent from ccz_sigma_index (fresh SQL lookup, not the cache) and from
#   the 553 census classes. Distinct sigma are distinct CCZ classes, so the number of
#   distinct certified sigma is a lower bound on the number of new classes found.
#
# Pseudocode:
#   status(outdir): counts from done.tsv, found.tsv, keys.tsv and the end of log.txt
#   novelty(outdirs): merge found.tsv by sigma (first occurrence wins); recheck every
#     search-new row; histogram of B6 and generation; optional P6 profiles (bminK) of the
#     first k new functions; write <out>/novelty_new.tsv and <out>/summary.toml
# VBF API used: SBox, differential_uniformity
# VBFCatalog API used: sigma_hash, _open_sigma_index

isdefined(@__MODULE__, :run_search) || include(joinpath(@__DIR__, "search.jl"))
using TOML
isdefined(@__MODULE__, :Profiles) ||
    include(joinpath(CENSUS_DIR, "reports", "properties", "profiles_lib.jl"))

function search_status(outdir::AbstractString; io::IO = stdout, seeds = joinpath(RESULTS_DIR, "seeds_b52.tsv"))
    isdir(outdir) || (println(io, "no run in $outdir"); return nothing)
    done = read_tsv(joinpath(outdir, "done.tsv"))
    found = read_tsv(joinpath(outdir, "found.tsv"))
    nkeys = length(read_tsv(joinpath(outdir, "keys.tsv")))
    nseed0 = length(read_tsv(seeds))
    st = Dict{String,Int}()
    for r in found; st[r[2]] = get(st, r[2], 0) + 1; end
    b6 = Dict{Int,Int}()
    for r in found
        r[2] == "search" && (k = parse(Int, r[5]); b6[k] = get(b6, k, 0) + 1)
    end
    secs = sum((parse(Float64, r[12]) for r in done); init = 0.0)
    nS = sum((parse(Int, r[7]) for r in done); init = 0)
    nsf = sum((parse(Int, r[11]) for r in done); init = 0)
    gen = Dict{Int,Int}()
    for r in done; g = parse(Int, r[2]); gen[g] = get(gen, g, 0) + 1; end
    println(io, "run: $outdir")
    println(io, @sprintf("  seeds done %d (by generation %s); initial seeds %d; enqueued search-new with B6=52: %d",
                         length(done), string(sort(collect(gen))), nseed0, get(b6, 52, 0)))
    println(io, @sprintf("  pending seeds about %d", nseed0 + get(b6, 52, 0) - length(done)))
    println(io, @sprintf("  distinct sigma found %d: known %d, census %d, search-new %d", length(found),
                         get(st, "known", 0), get(st, "census", 0), get(st, "search", 0)))
    println(io, "  search-new by B6: ", sort(collect(b6)))
    println(io, @sprintf("  class keys %d; S per seed %.1f; search-new (first) per seed %.2f; thread-seconds per seed %.1f",
                         nkeys, nS / max(1, length(done)), nsf / max(1, length(done)), secs / max(1, length(done))))
    logf = joinpath(outdir, "log.txt")
    if isfile(logf)
        ls = readlines(logf)
        println(io, "  log (last lines):")
        for l in ls[max(1, end - 2):end]; println(io, "    ", l); end
    end
    (; done = length(done), found = length(found), status = st, b6)
end

function novelty_report(outdirs::Vector{String}; out::AbstractString = joinpath(first(outdirs), "novelty"),
                        profiles::Int = 10, io::IO = stdout)
    G = geometry(8)
    rows = Dict{String,Vector{SubString{String}}}(); order = String[]
    nseeds = 0; secs = 0.0
    for d in outdirs
        for r in read_tsv(joinpath(d, "found.tsv"))
            haskey(rows, r[1]) && continue
            rows[r[1]] = r; push!(order, r[1])
        end
        dn = read_tsv(joinpath(d, "done.tsv"))
        nseeds += length(dn); secs += sum((parse(Float64, r[12]) for r in dn); init = 0.0)
    end
    idx = VBFCatalog._open_sigma_index()
    c553 = Set(split(l, '\t')[1] for l in eachline(NEW553) if !isempty(l))
    st = Dict{String,Int}(); b6 = Dict{Int,Int}(); gen = Dict{Int,Int}()
    verified = String[]; failed = String[]
    t = @elapsed for h in order
        r = rows[h]
        st[r[2]] = get(st, r[2], 0) + 1
        r[2] == "search" || continue
        c = coeffs_from_hex(r[6])
        F = SBox{8}(UInt8.(lut_from_coeffs(G, c)))
        ok = differential_uniformity(F) == 2 && VBFCatalog.sigma_hash(F) == h && !(h in c553) &&
             isempty(collect(DBI.execute(idx, "SELECT 1 FROM ccz_sigma_index WHERE sigma_hash = '$h' LIMIT 1")))
        if ok
            push!(verified, h)
            k = parse(Int, r[5]); b6[k] = get(b6, k, 0) + 1
            g = parse(Int, r[3]); gen[g] = get(gen, g, 0) + 1
        else
            push!(failed, h)
        end
    end
    close(idx)
    mkpath(out)
    open(joinpath(out, "novelty_new.tsv"), "w") do f
        println(f, "sigma\tb6\tgen\tparent\tcoeffs")
        for h in verified
            r = rows[h]; println(f, h, '\t', r[5], '\t', r[3], '\t', r[4], '\t', r[6])
        end
    end
    profs = Dict{String,Int}()
    for h in verified[1:min(profiles, end)]
        C = Profiles.coeff_matrix(String(rows[h][6]))
        p, _ = Profiles.profile_pk(Profiles.component_alphas(Profiles.component_ranks(C)), 6; order = :bminK)
        k = Profiles.fmt_profile(p[6:7]); profs[k] = get(profs, k, 0) + 1
    end
    println(io, "novelty report over ", join(outdirs, ", "))
    println(io, @sprintf("  seeds done %d, thread-hours %.2f", nseeds, secs / 3600))
    println(io, @sprintf("  distinct sigma %d: known %d, census %d, search-new %d", length(order),
                         get(st, "known", 0), get(st, "census", 0), get(st, "search", 0)))
    println(io, @sprintf("  search-new verified (APN, sigma recomputed, absent from the index and the 553): %d; failed: %d (%.0f s)",
                         length(verified), length(failed), t))
    println(io, "  verified new by B6: ", sort(collect(b6)), "; by generation: ", sort(collect(gen)))
    isempty(profs) || println(io, "  P6 levels 5-6 (bminK) of the first $(min(profiles, length(verified))) new: ", sort(collect(profs)))
    println(io, @sprintf("  new classes per thread-hour: %.0f", length(verified) / max(secs / 3600, 1e-9)))
    println(io, "  wrote ", joinpath(out, "novelty_new.tsv"))
    open(joinpath(out, "summary.toml"), "w") do f
        TOML.print(f, Dict("outdirs" => outdirs, "seeds_done" => nseeds, "thread_seconds" => secs,
                           "distinct_sigma" => length(order), "known" => get(st, "known", 0),
                           "census" => get(st, "census", 0), "search_new" => get(st, "search", 0),
                           "verified_new" => length(verified), "failed" => length(failed),
                           "new_by_b6" => Dict(string(k) => v for (k, v) in b6),
                           "profiles_sample" => profs, "date" => now_str()))
    end
    isempty(failed)
end
