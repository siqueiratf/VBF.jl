# Implements dataset access for Section 3.2's known six-bit census.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.2 — Implementation and Results
#
# Pseudocode:
#   1. Load the thirteen APN-rep six-bit catalog entries.
#   2. Add the Kim representative and verify fourteen APN functions, thirteen quadratic.
# VBF API used: kim_apn, algebraic_degree, differential_uniformity
using VBF
using VBFCatalog

"""Load known census inputs for Baudrin–Galissant–Perrin (2025), Section 3.2."""
function section32_inputs()
    db = load_catalog()
    rows = sort!(list_functions(db; n=6, is_apn=true, family="APN-rep"); by=r -> r.id)
    inputs = [(; label=String(row.canonical_name), identifier=string(row.id),
        function_value=load_sbox(db, row.id), provenance="VBFCatalog/APN-rep") for row in rows]
    push!(inputs, (; label="Kim", identifier="n6_Kim", function_value=kim_apn(),
        provenance="VBF.kim_apn; x^3+x^10+u*x^24, u^6+u^4+u^3+u+1=0"))
    length(inputs) == 14 || error("expected thirteen APN-rep inputs plus Kim")
    all(row -> differential_uniformity(row.function_value) == 2, inputs) || error("census input is not APN")
    count(row -> algebraic_degree(row.function_value) == 2, inputs) == 13 || error("expected thirteen quadratic roots")
    length(unique(Tuple(row.function_value.lut) for row in inputs)) == 14 || error("duplicate census lookup table")
    return inputs
end
