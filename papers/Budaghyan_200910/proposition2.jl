# Implements Proposition 2 — slight extension of Proposition 1.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.A — The case n even.
#
# Proposition 2: n even, L, L' linear. If F(x)=L'(x)+L(x³) is a permutation of
#   GF(2ⁿ) then F(x³)=L'(x³)+L(x⁹) is APN.
#
# Pseudocode:
#   take a linear permutation M and a class-1 L (L(y)=trₙ(y));  set L'=M∘id, use
#   F(x) = M(x) + M(L(x³)) = M(x + L(x³))  (permutation ⇔ x+L(x³) permutation)
#   then verify F(x³) = M(x³) + M(L(x⁹)) is APN and quadratic.
# VBF API used: gf_mul, gf_pow, is_permutation, differential_uniformity, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition2_report(io; save_results) -> NamedTuple

Verify Proposition 2 with a non-identity linear L' (scalar multiplication by α)
composed with the class-1 permutation x + trₙ(x³).
"""
function proposition2_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 2 — n even: L'(x)+L(x³) perm ⟹ L'(x³)+L(x⁹) APN", io)
    all_ok = true
    rows = Tuple{Int,Bool,Int,Int}[]
    for n in (6, 8)
        a = primitive_element(n)                    # L'(x) = α·x, a linear perm
        Llut = L_class_lut(:trace, n)
        # F(x) = M(x) + M(L(x³)) = α·x + α·L(x³)
        perm = [gf_mul(a, x ⊻ apply_L(Llut, gf_pow(x, 3, n)), n) for x = 0:((1<<n)-1)]
        is_perm = is_permutation(as_sbox(perm, n))
        # F(x³) = α·x³ + α·L(x⁹)
        apn = [
            gf_mul(a, gf_pow(x, 3, n) ⊻ apply_L(Llut, gf_pow(x, 9, n)), n) for
            x = 0:((1<<n)-1)
        ]
        Fs = as_sbox(apn, n)
        du = differential_uniformity(Fs)
        deg = algebraic_degree(Fs)
        ok = is_perm && du == 2 && deg == 2
        all_ok &= ok
        print_check("n=$n: L'=α·x, L=trₙ — F perm=$is_perm ⟹ APN (δ=$du, deg=$deg)", ok, io)
        push!(rows, (n, is_perm, du, deg))
    end
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition2.toml"), "w") do f
            println(f, "# Proposition 2\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition2_report()
end
