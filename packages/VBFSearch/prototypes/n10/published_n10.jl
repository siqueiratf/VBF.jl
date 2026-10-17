# Build the published quadratic APN functions on F_2^10 that we can reconstruct,
# group them by sigma, and test the exchange candidate against all of them.
include(joinpath(@__DIR__, "check_extensions.jl"))           # sols, sig, lut_of, known (catalog n = 10)
include(joinpath(@__DIR__, "..", "..", "..", "VBFRepro", "tools", "catalog_proposals.jl"))

# GF(2^k) arithmetic with an explicit modulus.
function fmul(a, b, k, mod)
    r = 0
    while b != 0
        (b & 1 == 1) && (r ⊻= a); b >>= 1; a <<= 1
        (a >> k) & 1 == 1 && (a ⊻= mod)
    end
    r
end
fpow(a, e, k, mod) = (r = 1; b = a; while e > 0; (e & 1 == 1) && (r = fmul(r, b, k, mod)); b = fmul(b, b, k, mod); e >>= 1; end; r)
ftr(x, k, mod) = (t = 0; y = x; for _ in 1:k; t ⊻= y; y = fmul(y, y, k, mod); end; t)
finv(a, k, mod) = fpow(a, (1 << k) - 2, k, mod)

const M10 = 1135                      # Conway polynomial x^10+x^6+x^5+x^3+x^2+x+1 (Magma default)
p(e) = fpow(2, e, 10, M10)
poly(terms) = SBox{10}([UInt16(reduce(⊻, (fmul(c, fpow(x, e, 10, M10), 10, M10) for (c, e) in terms); init = 0)) for x in 0:1023])
tr10(x) = ftr(x, 10, M10)

rows = Pair{String,SBox{10,UInt16}}[]
# UiB wiki "CCZ-inequivalent representatives ... up to 11", quadratic n = 10 rows.
push!(rows, "UiB10.5 x6+x33+p31x192" => poly([(1, 6), (1, 33), (p(31), 192)]))
push!(rows, "UiB10.6 x33+x72+p31x258" => poly([(1, 33), (1, 72), (p(31), 258)]))
push!(rows, "UiB10.7 x3+Tr(x9)" => SBox{10}([UInt16(fpow(x, 3, 10, M10) ⊻ tr10(fpow(x, 9, 10, M10))) for x in 0:1023]))
let a = p(1), ai = finv(p(1), 10, M10), a3 = fpow(p(1), 3, 10, M10)
    push!(rows, "UiB10.8 x3+a^-1Tr(a3x9)" => SBox{10}([UInt16(fpow(x, 3, 10, M10) ⊻ fmul(ai, tr10(fmul(a3, fpow(x, 9, 10, M10), 10, M10)), 10, M10)) for x in 0:1023]))
end
push!(rows, "UiB10.9 BHK" => poly([(1, 3), (p(341), 9), (p(682), 96), (1, 288)]))
push!(rows, "UiB10.10 BHK" => poly([(1, 3), (p(341), 129), (p(682), 96), (1, 36)]))
push!(rows, "UiB10.17 x3+p341x36" => poly([(1, 3), (p(341), 36)]))
# Beierle-Leander 2022, Zenodo 10.5281/zenodo.4738942 v2.1, apn_10bit.txt.
# Download once: curl -L https://zenodo.org/api/records/4738942/files/apn_10bit.txt/content -o results/apn_10bit.txt
const BL_FILE = get(ENV, "APN10_BL_FILE", joinpath(@__DIR__, "results", "apn_10bit.txt"))
for (i, line) in enumerate(eachline(BL_FILE))
    push!(rows, "BeierleLeander2022_$i" => SBox{10}(UInt16.(parse.(Int, filter(!isempty, split(replace(line, r"[{}\s]" => ""), ","))))))
end
# Li-Zhou-Li-Qu 2022 bivariate, m = 5: (x^3+xy^2+y^3+xy, x^5+x^4y+y^5+xy+x^2y^2).
let k = 5, md = 37, m(a, b) = fmul(a, b, k, md), pw(a, e) = fpow(a, e, k, md)
    lut = zeros(UInt16, 1024)
    for x in 0:31, y in 0:31
        u = pw(x, 3) ⊻ m(x, pw(y, 2)) ⊻ pw(y, 3) ⊻ m(x, y)
        v = pw(x, 5) ⊻ m(pw(x, 4), y) ⊻ pw(y, 5) ⊻ m(x, y) ⊻ m(pw(x, 2), pw(y, 2))
        lut[(x | y << 5) + 1] = UInt16(u | v << 5)
    end
    push!(rows, "LiZhouLiQu2022_m5" => SBox{10}(lut))
end
# Repo proposals (BHK C3/C7, Gologlu F2/F3, Zheng, Yu short form).
for r in catalog_proposal_candidates()
    r.F isa SBox{10} && push!(rows, r.name => r.F)
end

cand = setdiff(unique(sig), [sigma_hash(SBox{10}(lut_of(comp_basis(gold_lut(3)))))])
groups = Dict{String,Vector{String}}()
for (name, F) in rows
    d = VBF.differential_uniformity(F)
    s = sigma_hash(F)
    push!(get!(groups, s, String[]), name)
    println(rpad(name, 28), " delta=", d, "  catalog=", get(known, s, "-"), "  candidate=", s in cand)
end
println("\ndistinct sigma among published rows: ", length(groups))
for (s, names) in groups
    length(names) > 1 && println("  shared: ", join(names, ", "))
end
println("catalog n=10 quadratic sigma: ", length(known), "; new sigma vs catalog: ", count(s -> !haskey(known, s), keys(groups)))

# Confirm each shared sigma, and the candidate, with an exact EA test.
byname = Dict(rows)
for (s, names) in groups
    length(names) > 1 || continue
    for other in names[2:end]
        t = @elapsed r = are_ea_equivalent(byname[names[1]], byname[other])
        println("EA(", names[1], ", ", other, ") = ", r, "  (", round(t, digits = 1), " s)")
    end
end
cS = first(S for S in sols if sigma_hash(SBox{10}(lut_of(S))) in cand)
t = @elapsed r = are_ea_equivalent(SBox{10}(lut_of(cS)), byname["UiB10.8 x3+a^-1Tr(a3x9)"])
println("EA(candidate, UiB10.8) = ", r, "  (", round(t, digits = 1), " s)")
