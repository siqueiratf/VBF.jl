# Implements Remark 3: Gold and Inverse families as special cases of e(l,k)
# Paper: Kaleyski, Nesheim, Stănică (2022), "A doubly-infinite family of 0-APN monomials"
# Section: 2 — Remark 3
#
# Pseudocode:
#   1. Verify Gold x^{2^k+1} = x^{e(2,k)} for small k
#   2. Verify Inverse x^{2^{n-1}-1} = x^{e(n-1,1)} mod 2^n-1 for small n
#   3. Check APN property for these known-family representatives
# VBF API used: print_section, print_check, print_kv, differential_uniformity,
#               gf_monomial_lut

include(joinpath(@__DIR__, "helpers.jl"))

function remark3_report(io::IO = stdout; max_n_apn::Int = 12)
    print_section(io, "Remark 3 — Known families as e(l,k)")

    # ── Gold: x^{2^k+1} = x^{e(2,k)} ───────────────────────────────────
    gold_ok = true
    for k in 1:10
        e2k = e_exponent(2, k)
        gold_exp = (1 << k) + 1
        if e2k != gold_exp
            gold_ok = false
        end
    end
    print_check(io, "Gold: e(2,k) = 2^k+1 for k=1..10", gold_ok)

    gold_apn_ok = true
    for n in 3:2:min(max_n_apn, 15)
        for k in 1:n-1
            if gcd(k, n) == 1
                e = e_exponent(2, k)
                sbox = SBox(gf_monomial_lut(n, e))
                du = differential_uniformity(sbox)
                if du != 2
                    gold_apn_ok = false
                    print_kv(io, "  FAIL", "Gold n=$n, k=$k, du=$du")
                end
            end
        end
    end
    print_check(io, "Gold x^{e(2,k)} is APN when gcd(k,n)=1, n≤$max_n_apn",
        gold_apn_ok)

    # ── Inverse: x^{2^{n-1}-1} = x^{e(n-1,1)} ─────────────────────────
    inv_ok = true
    for n in 2:20
        en1 = e_exponent(n - 1, 1)
        inv_exp = (1 << (n - 1)) - 1
        if en1 != inv_exp
            inv_ok = false
        end
    end
    print_check(io, "Inverse: e(n-1,1) = 2^{n-1}-1 for n=2..20", inv_ok)

    inv_apn_ok = true
    for n in 3:2:min(max_n_apn, 13)
        e = e_exponent(n - 1, 1)
        sbox = SBox(gf_monomial_lut(n, e))
        du = differential_uniformity(sbox)
        if du != 2
            inv_apn_ok = false
            print_kv(io, "  FAIL", "Inverse n=$n, du=$du")
        end
    end
    print_check(io, "Inverse x^{e(n-1,1)} is APN for odd n≤$max_n_apn",
        inv_apn_ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    remark3_report()
end
