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

"""Load the pinned 488 quadratic seven-bit roots used by Section 3.2.

Three preexisting Gold rows were merged by LUT during import; selecting only
the APN-rep family would omit those roots. The source tag selects the complete
imported collection, independently of its catalog family labels.
"""
function section32_seven_inputs()
    db = load_catalog()
    rows = filter(row->row.is_quadratic && occursin("sboxu@7066b82",row.source_repo),
        list_functions(db;n=7,is_apn=true))
    length(rows)==488 || error("expected 488 pinned quadratic seven-bit roots")
    inputs = [(;label=String(row.canonical_name),identifier=string(row.id),
        function_value=load_sbox(db,row.id),provenance=String(row.source_repo)) for row in rows]
    length(unique(Tuple(row.function_value.lut) for row in inputs))==488 || error("duplicate seven-bit root LUT")
    all(row->is_quadratic_apn(row.function_value),inputs) || error("seven-bit root is not quadratic APN")
    return inputs
end
