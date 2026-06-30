# Implements Table 3: CCZ-class fingerprints for n=6
# Paper: Deng Tang, Claude Carlet, Xiaohu Tang (2015),
#        "Differentially 4-Uniform Bijections by Permuting the Inverse Function"
#        Designs, Codes and Cryptography, DOI 10.1007/s10623-015-0137-y
# Section: 4.3 — CCZ-inequivalence; Table 3 (p. 22)
#
# For n=6: |U_max| = 14, elements form 7 pairs under x -> x+1.
# All 2^7 = 128 valid U choices; 127 non-empty.
# Claim: exactly 22 distinct (nl, D0, D2, D4) fingerprints (CCZ-invariants).
#
# NOTE: Table 3 α-indices use Magma's Conway polynomial for GF(2^6) = 91.
#       VBF uses primitive_polynomial(6) = 67. Element indices differ but
#       the count of 22 distinct fingerprints is polynomial-independent.
#
# Pseudocode:
#   1. Build U_max for n=6, extract 7 pairs {x, x+1}.
#   2. Enumerate all 2^7 - 1 = 127 non-empty subsets (union of k>=1 pairs).
#   3. For each: build F, compute (nl, D0, D2, D4) fingerprint.
#   4. Collect distinct fingerprints; expect exactly 22.
# VBF API used: differential_spectrum, linearity, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    table3_classes(; n) -> Vector{NamedTuple}

Enumerate all valid non-empty U subsets of U_max for GF(2^n), compute
(nl, D0, D2, D4) fingerprints, and return the distinct fingerprints sorted by nl.
"""
function table3_classes(; n::Int = 6)
    u_max = build_u_max(n)
    pairs = u_max_pairs(u_max)
    num_pairs = length(pairs)

    fingerprints = Dict{NTuple{4,Int}, Int}()  # signature -> number of U sets with this signature

    for mask in 1:((1 << num_pairs) - 1)   # skip mask=0 (empty U)
        U = Int[]
        for j in 1:num_pairs
            if (mask >> (j - 1)) & 1 == 1
                push!(U, pairs[j][1], pairs[j][2])
            end
        end
        F  = construction1_sbox(n, U)
        nl = nonlinearity(F)
        d0, d2, d4 = diff_spec_d024(F)
        sig = (nl, d0, d2, d4)
        fingerprints[sig] = get(fingerprints, sig, 0) + 1
    end

    sorted = sort(collect(fingerprints), by = kv -> (kv[1][1], kv[1][2], kv[1][3], kv[1][4]))
    [(; nl = k[1], d0 = k[2], d2 = k[3], d4 = k[4], u_set_count = v) for (k, v) in sorted]
end

"""
    table3_report([io]; n) -> NamedTuple

Enumerate all 127 non-empty valid U sets for n=6 and verify exactly 22 distinct
(nl, D0, D2, D4) CCZ-class fingerprints (Table 3 in paper).
"""
function table3_report(io::IO = stdout; n::Int = 6)
    print_section("Table 3 — CCZ-class fingerprints for n=$n", io)
    println(io, "  Enumerating all 2^7-1=127 non-empty valid U subsets of U_max")
    println(io, "  NOTE: α-indices differ from paper (VBF poly=$(primitive_polynomial(n)), Magma Conway=$(conway_polynomial(n)))")
    println(io, "        CCZ-class COUNT is polynomial-independent")

    u_max = build_u_max(n)
    print_kv("|U_max|", length(u_max), io)
    print_kv("pairs (each pair = {x, x+1})", length(u_max_pairs(u_max)), io)

    classes = table3_classes(; n)
    num_classes = length(classes)
    ok = num_classes == 22
    print_check("distinct CCZ fingerprints = $num_classes (expected 22)", ok, io)

    println(io, "\n  $(rpad("nl", 6))  $(rpad("D0", 7))  $(rpad("D2", 7))  $(rpad("D4", 7))  U-sets")
    for c in classes
        println(io, "  $(rpad(c.nl, 6))  $(rpad(c.d0, 7))  $(rpad(c.d2, 7))  $(rpad(c.d4, 7))  $(c.u_set_count)")
    end

    print_kv("completeness", "exhaustive (all 127 non-empty valid U sets for n=$n)", io)
    return (; all_ok = ok, num_classes, classes)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table3_report()
end
