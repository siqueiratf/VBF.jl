using VBF
# Implements exact masses sum_{classes} 1/|Stab| for small n from the catalog
# Study: census of quadratic APN functions on F_2^8 (data/apn/archive/census)
#
# Math:
#   GL(n,2) x GL(n,2) acts on pure quadratic APN (n,n)-functions F -> A o F o B.  By the
#   orbit-stabilizer theorem, T(n,n) / |GL(n,2)|^2 = sum_{classes K} 1/|Stab(K)|.  For a
#   quadratic APN class, CCZ = EA (Yoshiara), and the linear self-equivalences counted by
#   VBF.automorphisms_from_ortho_derivative include 2^n of them per element of Stab, so
#   |Stab| = |Aut(F)| / 2^n and the mass is sum 2^n / |Aut(F)|.
#   The catalog holds the classified quadratic APN CCZ classes for 4 <= n <= 7 (1, 2, 13
#   and 488 classes), so the mass is exact there; validate.jl confirms (6,6) and (7,7)
#   independently.  The catalog has no n = 3 representative (mass 1/168 = T(3,3)/|GL(3,2)|^2).
#
# Pseudocode:
#   for n in nmin:nmax:
#     reps = CCZ class representatives of dimension n in the VBFCatalog catalog
#     for F in reps with is_quadratic_apn(F): a = |Aut(F)|; mass += 2^n // a; hist[a] += 1
#     print classes, exact rational mass, float mass, histogram of |Aut|
# VBF API used: SBox, is_quadratic_apn, automorphisms_from_ortho_derivative
# VBFCatalog API used: load_catalog, DBInterface (equivalence_classes, functions tables)

isdefined(@__MODULE__, :encode_coeffs) || include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

"""
    exact_masses(nmin, nmax; io = stdout) -> Dict{Int,NamedTuple}

Exact `sum 2^n/|Aut(F)|` over the quadratic APN CCZ class representatives of the
catalog for `n in nmin:nmax`. Cost grows fast with `n` (n = 7 takes minutes).
"""
function exact_masses(nmin::Int, nmax::Int; io::IO = stdout)
    db = VBFCatalog.load_catalog()
    out = Dict{Int,Any}()
    for n in nmin:nmax
        q = "SELECT f.id, f.lut_blob FROM equivalence_classes e JOIN functions f " *
            "ON f.id = e.canonical_id WHERE e.kind='CCZ' AND e.n=$n"
        reps = [(Int(r.id), Vector{UInt8}(r.lut_blob)) for r in VBFCatalog.DBInterface.execute(db, q)]
        mass = big(0) // big(1)
        hist = Dict{Int,Int}()
        t = @elapsed for (_, blob) in reps
            lut = n <= 8 ? blob : reinterpret(UInt16, blob)
            F = SBox{n}(collect(lut))
            is_quadratic_apn(F) || continue          # skip non-quadratic representatives
            a = length(automorphisms_from_ortho_derivative(F))
            hist[a] = get(hist, a, 0) + 1
            mass += big(2)^n // a
        end
        classes = sum(values(hist); init = 0)
        r = (classes = classes, mass = mass, mass_float = Float64(mass),
             aut_hist = sort(collect(hist)), seconds = t)
        out[n] = r
        @printf(io, "n=%d quadratic APN classes=%d  sum 2^n/|Aut| = %s = %.6f  [%.1fs]\n",
                n, classes, string(mass), Float64(mass), t)
        println(io, "    |Aut| histogram: ", string(r.aut_hist))
        if haskey(EXACT_MASS, (n, n))
            println(io, "    stored EXACT_MASS[(", n, ",", n, ")] matches: ", mass == EXACT_MASS[(n, n)])
        end
        flush(io)
    end
    out
end
