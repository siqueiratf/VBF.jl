# Implements Theorem 1 + Remark 2
# Paper: Yu, Wang, Li (2013), "Constructing Differentially 4 Uniform
#        Permutations from Known Ones"
# Section: III — Theorem 1: δ(I_{(u,v)})=4 iff Tr(u/v)=Tr(v/u)=1
#          Remark 2: n=8 exhaustive counts
#
# Pseudocode:
#   1. For each pair (u,v) with u≠v, u,v ∈ F*_{2^n}:
#      a. Compute Tr(u·v^{-1}) and Tr(v·u^{-1})
#      b. Build I_{(u,v)} and compute δ
#      c. Verify: δ=4 iff both traces = 1; δ=6 iff either trace = 0
#   2. Remark 2 (n=8): count du=4 cases, check nl=110, example I_{(g,g^12)}
# VBF API used: gf_mul, gf_inv, gf_trace, SBox, differential_uniformity, nonlinearity

include(joinpath(@__DIR__, "helpers.jl"))

"""
Check Theorem 1 trace condition for a given (u,v) pair.
Returns predicted δ: 4 if Tr(u/v)=Tr(v/u)=1, else 6.
"""
function theorem1_predict(u::Int, v::Int, n::Int, mod::Int)
    uv_inv = gf_mul(u, gf_inv(v, n; modulus=mod), n; modulus=mod)
    vu_inv = gf_mul(v, gf_inv(u, n; modulus=mod), n; modulus=mod)
    tr_uv = gf_trace(uv_inv, n; modulus=mod)
    tr_vu = gf_trace(vu_inv, n; modulus=mod)
    predicted = (tr_uv == 1 && tr_vu == 1) ? 4 : 6
    (; predicted, tr_uv, tr_vu)
end

function theorem1_report(io::IO = stdout; full_search::Bool = true)
    print_section("Theorem 1: trace condition for I_{(u,v)}", io)

    for m in [2, 3]
        n = 2 * m
        N = 1 << n
        mod = primitive_polynomial(n)
        println(io, "\n  --- m=$m, n=$n (exhaustive) ---")

        all_match = true
        count_du4 = 0
        total = 0

        for u in 1:N-1
            for v in u+1:N-1
                total += 1
                pred = theorem1_predict(u, v, n, mod)
                G = inverse_swap(u, v, n; modulus=mod)
                actual_du = differential_uniformity(G)

                if actual_du != pred.predicted
                    all_match = false
                end
                if actual_du == 4
                    count_du4 += 1
                end
            end
        end

        print_kv(io, "total pairs (u<v, uv≠0)", total)
        print_kv(io, "pairs with δ=4", count_du4)
        print_check(io, "Theorem 1 matches all pairs", all_match)
    end

    # Remark 2: n=8 (m=4)
    m = 4; n = 8; N = 1 << n
    mod = conway_polynomial(n)  # paper uses x^8+x^4+x^3+x^2+1 = 285
    println(io, "\n  --- m=$m, n=$n (Remark 2) ---")

    all_match = true
    count_du4 = 0
    count_du6 = 0
    total = 0
    nl_set = Set{Int}()

    for u in 1:N-1
        for v in u+1:N-1
            total += 1
            pred = theorem1_predict(u, v, n, mod)
            G = inverse_swap(u, v, n; modulus=mod)
            actual_du = differential_uniformity(G)

            if actual_du != pred.predicted
                all_match = false
            end
            if actual_du == 4
                count_du4 += 1
                push!(nl_set, nonlinearity(G))
            else
                count_du6 += 1
            end
        end
    end

    print_kv(io, "total pairs", total)
    print_check(io, "total = 32385", total == 32385)
    print_kv(io, "pairs with δ=4", count_du4)
    print_kv(io, "pairs with δ=6", count_du6)
    print_check(io, "9180 pairs with δ=4", count_du4 == 9180)
    print_check(io, "Theorem 1 matches all pairs", all_match)

    if !isempty(nl_set)
        print_kv(io, "nonlinearity values (δ=4 functions)", sort(collect(nl_set)))
        print_check(io, "all δ=4 functions have nl=110", nl_set == Set([110]))
    end

    # Example: I_{(g, g^12)}
    g = 2  # primitive element
    g1 = g
    g12 = gf_pow(g, 12, n; modulus=mod)
    G_ex = inverse_swap(g1, g12, n; modulus=mod)
    du_ex = differential_uniformity(G_ex)
    nl_ex = nonlinearity(G_ex)
    A_ex = parameter_A_from_ddt(G_ex)

    I_sbox = SBox(inverse_function_lut(n; modulus=mod))
    A_inv = parameter_A_from_ddt(I_sbox)

    print_kv(io, "I_{(g,g^12)} δ", du_ex)
    print_kv(io, "I_{(g,g^12)} nl", nl_ex)
    print_kv(io, "I_{(g,g^12)} A", A_ex)
    print_check(io, "I_{(g,g^12)}: δ=4, nl=110, A=477", du_ex == 4 && nl_ex == 110 && A_ex == 477)
    print_kv(io, "I(x) A", A_inv)
    print_check(io, "I(x) A = 255", A_inv == 255)

    (; all_match, count_du4, total)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem1_report()
end
