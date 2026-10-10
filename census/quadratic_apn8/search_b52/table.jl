# Implements the Walsh table fhat of the flat indicator on Alt(8) = F_2^28 and its checks
# Study: B6 = 52 extension search (census/quadratic_apn8/search_b52)
#
# Math:
#   f = indicator of the 10,795 flats (decomposable bivectors) in V = F_2^28.
#   fhat(s) = sum_v f(v) (-1)^{v . s}, |fhat| <= 10,795 (Int16; 2^28 entries = 512 MB).
#   GL(8) acts on forms and bivectors and preserves the pairing; it is transitive on the
#   forms of a given rank. So fhat(s) = phi(rank s) takes 5 values, and
#   sigma_U(t) = sum_{u in U} fhat(t+u) depends only on the rank distribution of t + U.
#   The search uses the equivalent restricted transform g on V/U (VBF.QuadraticExtensions), because
#   sigma_U(t) = 2^6 g(tau(t)) and g needs 22 x 2^22 operations instead of 2^28 reads.
#   The table is the reference for that identity. The same sweep checks
#   beta(r) = Bhat(rank r) (bent indicator), used for the coset bent counts.
#
# Pseudocode:
#   a = indicator of the flats on 2^28 Int16; fwht!(a)
#   check a[s] == phi(rank s) for every s (threaded); count the forms of each rank
#   check beta (bent_fourier) == BETA8
#   for a few U with 52 bent of the seeds and 2,000 random t:
#       sum_{u in U} a[t+u] == 2^6 g(tau(t))
#   write results/tables/fhat8.bin (raw Int16, little endian) and rank_fourier.toml
# VBF API used: none

isdefined(@__MODULE__, :run_search) || include(joinpath(@__DIR__, "search.jl"))
using TOML, Random

function build_table(; dir::AbstractString = joinpath(RESULTS_DIR, "tables"), io::IO = stdout,
                     write_table::Bool = true)
    G = geometry(8)
    mkpath(dir)
    a = zeros(Int16, 1 << 28)
    for w in G.flats; a[w+1] = Int16(1); end
    tw = @elapsed fwht!(a)
    println(io, @sprintf("fhat: FWHT of 2^28 Int16 entries in %.1f s (%.0f MB)", tw, sizeof(a) / 2^20)); flush(io)
    phi = flat_fourier(G)
    nch = 1024; step = (1 << 28) ÷ nch
    bad = zeros(Int, nch); rc = [zeros(Int, 5) for _ in 1:nch]
    tc = @elapsed Threads.@threads for ci in 1:nch
        for s in UInt32((ci - 1) * step):UInt32(ci * step - 1)
            k = (form_rank(G, s) >> 1) + 1
            rc[ci][k] += 1
            @inbounds a[s+1] == phi[k] || (bad[ci] += 1)
        end
    end
    nbad = sum(bad); counts = sum(rc)
    println(io, @sprintf("fhat(s) = phi(rank s) for all 2^28 s: %s (%d mismatches, %.1f s); phi = %s",
                         nbad == 0 ? "PASS" : "FAIL", nbad, tc, string(phi)))
    println(io, "forms by rank 0,2,4,6,8: ", counts)
    tb = @elapsed beta = bent_fourier(G)
    println(io, @sprintf("beta = %s: %s BETA8 (%.1f s)", string(beta), beta == BETA8 ? "PASS, equal to" : "FAIL, differs from", tb))
    # sigma_U identity on seeds
    seeds = read_tsv(joinpath(RESULTS_DIR, "seeds_b52.tsv"))
    isempty(seeds) && (write_seeds(); seeds = read_tsv(joinpath(RESULTS_DIR, "seeds_b52.tsv")))
    rng = Xoshiro(28); w = ExtWork(22); nchk = 0; nok = 0
    for r in seeds[1:3]
        comp = comp_forms(coord_forms(coeffs_from_hex(r[4]), 8)); bent = bent_mask(G, comp)
        for U in subspaces_of_comp(comp, bent, 6; keep = ==(52))[1:2]
            e = extensions(G, U.forms, w; du_filter = false)
            R, piv = rref(e.R)
            Uel = [reduce(⊻, (R[i] for i in 1:6 if (m >> (i - 1)) & 1 == 1); init = UInt32(0)) for m in 0:63]
            for _ in 1:2000
                t = rand(rng, UInt32) & 0x0fffffff
                tr = t
                for (rr, p) in zip(R, piv); (tr >> p) & 1 == 1 && (tr ⊻= rr); end
                tau = Ext.pext(tr, e.Qmask)
                sig = sum(Int(a[(t ⊻ u)+1]) for u in Uel)
                nchk += 1
                sig == 64 * Int(w.buf[tau+1]) && (nok += 1)
            end
        end
    end
    println(io, "sigma_U(t) from the table = 2^6 g(tau(t)): ", nok == nchk ? "PASS" : "FAIL", " ($nok / $nchk)")
    # cost of the table route for one U (all 2^22 cosets, 2^28 reads) vs the 22-bit FWHT
    comp = comp_forms(coord_forms(coeffs_from_hex(seeds[1][4]), 8))
    U = subspaces_of_comp(comp, bent_mask(G, comp), 6; keep = ==(52))[1]
    e = extensions(G, U.forms, w; du_filter = false)
    Uel = [reduce(⊻, (e.R[i] for i in 1:6 if (m >> (i - 1)) & 1 == 1); init = UInt32(0)) for m in 0:63]
    sig = zeros(Int32, 1 << 22)
    ttab = @elapsed for tau in UInt32(0):UInt32((1 << 22) - 1)
        t = lift(tau, e.Qmask); s = 0
        @inbounds for u in Uel; s += a[(t ⊻ u)+1]; end
        sig[tau+1] = s
    end
    tfw = @elapsed for _ in 1:5; extensions(G, U.forms, w; du_filter = false); end
    println(io, @sprintf("one U: sigma_U from the table %.2f s; restricted FWHT + extension step %.1f ms; equal: %s",
                         ttab, 1e3tfw / 5, all(sig[i] == 64 * Int(w.buf[i]) for i in eachindex(sig))))
    path = joinpath(dir, "fhat8.bin")
    if write_table
        open(f -> write(f, a), path, "w")
        println(io, "wrote $path ($(filesize(path)) bytes)")
    end
    open(joinpath(dir, "rank_fourier.toml"), "w") do f
        TOML.print(f, Dict("n" => 8, "ranks" => [0, 2, 4, 6, 8], "forms_by_rank" => counts,
                           "phi_flats" => phi, "beta_bent" => beta, "fhat_table" => path,
                           "fhat_check_mismatches" => nbad, "sigma_identity_checks" => nchk,
                           "sigma_identity_pass" => nok, "date" => now_str()))
    end
    ok = nbad == 0 && beta == BETA8 && nok == nchk
    println(io, ok ? "TABLE: ALL PASS" : "TABLE: FAILURES")
    ok
end
