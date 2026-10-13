# Independent count of the n-dimensional subspaces in the Walsh zeroes with VBF
# (extract_linear_subspaces). Arguments: catalog ids and/or "dillon", "kim".
using VBF, VBFCatalog
const DBI = VBFCatalog.DBInterface

function load_function(name)
    name == "dillon" && return dillon_apn_permutation()
    name == "kim" && return kim_apn()
    cat = VBFCatalog.load_catalog()
    r = first(DBI.execute(cat, "SELECT n, lut_blob FROM functions WHERE id = $(parse(Int, name))"))
    VBFCatalog._sbox_from_blob(Vector{UInt8}(r.lut_blob), Int(r.n))
end

for name in ARGS
    F = load_function(name)
    N = trailing_zeros(length(F.lut))
    z = walsh_zeroes(F)
    t = time()
    b = VBF.extract_linear_subspaces(z, N; max_bits = 2N)
    println(name, "\tn=", N, "\twalsh_zeroes=", length(z), "\tsubspaces=", length(b),
            "\tseconds=", round(time() - t, digits = 2))
    flush(stdout)
end
