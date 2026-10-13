# Cheap facts about the 3 non-quadratic n=8 APN rows (ids 43, 581, 634):
# exact monomial identification over GF(2^8) mod 0x11B / 0x11D, and CCZ invariants.
using VBF, VBFCatalog
const DBI = VBFCatalog.DBInterface
cat = VBFCatalog.load_catalog()
F = Dict(Int(r.id) => VBFCatalog._sbox_from_blob(Vector{UInt8}(r.lut_blob), 8) for r in
     DBI.execute(cat, "SELECT id, lut_blob FROM functions WHERE id IN (43, 581, 634)"))
function gfmul(a, b, m)
    r = 0
    while b != 0
        (b & 1) == 1 && (r ⊻= a); b >>= 1; a <<= 1; (a & 0x100) != 0 && (a ⊻= m)
    end
    r
end
gfpow(x, e, m) = (r = 1; for _ in 1:e; r = gfmul(r, x, m); end; r)
for id in (43, 581, 634), m in (0x11B, 0x11D)
    for e in 1:254
        if all(gfpow(x, e, m) == Int(F[id].lut[x+1]) for x in 0:255)
            println("id $id = x^$e over GF(2^8) mod $(string(m, base=16)) (cyclotomic class of 57: ", sort(unique([57 * 2^k % 255 for k in 0:7])), ")")
        end
    end
end
for id in (43, 581, 634)
    f = F[id]
    println("id $id: deg=$(algebraic_degree(f)) du=$(differential_uniformity(f)) |Z|=$(walsh_zeroes_size(f)) ",
            "ddt-multiset-hash=$(hash(sort(vec(ddt(f))))) abs-walsh-multiset-hash=$(hash(sort(abs.(vec(lat(f)))))) perm=$(is_permutation(f))")
end
