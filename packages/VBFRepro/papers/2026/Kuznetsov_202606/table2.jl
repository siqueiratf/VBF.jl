# Implements Table II — CCZ-Equivalence Classes and σ-Signatures
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: VI.B — σ-Signatures of the Six CCZ-Classes
#
# Pseudocode:
#   For each of the 6 CCZ-class representatives:
#   1. Compute π_F = ortho_derivative(F)
#   2. Compute diff_sp  = differential_spectrum(π_F)
#   3. Compute walsh_sp = absolute_walsh_spectrum(π_F)
#   4. Define σ(F) = (diff_sp, walsh_sp)
#   5. Verify σ(CLASS-E) == σ(Gold x³),  σ(CLASS-F) == σ(Gold x⁹)
#   6. Verify all 6 σ values are pairwise distinct
# VBF API used: ortho_derivative, differential_spectrum, absolute_walsh_spectrum,
#               gold_apn, SBox, sorted_pairs, print_section, print_check, print_kv

include("helpers.jl")

function sigma(F::SBox)
    pi = ortho_derivative(F)
    pi === nothing && error("ortho_derivative returned nothing for $(F)")
    diff_sp  = differential_spectrum(pi)
    walsh_sp = absolute_walsh_spectrum(pi)
    (diff_sp, walsh_sp)
end

function sigma_key(F::SBox)
    (d, w) = sigma(F)
    (sorted_pairs(d), sorted_pairs(w))
end

function table2_run()
    sboxes = representative_sboxes()
    names  = [:class_a, :class_b, :class_c, :class_d, :class_e, :class_f]

    sigs = map(names) do name
        F = getfield(sboxes, name)
        (name, sigma_key(F))
    end

    gold3_sig = sigma_key(gold_apn(8, 1))
    gold9_sig = sigma_key(gold_apn(8, 3))

    e_sig = last(sigs[5])
    f_sig = last(sigs[6])

    all_keys = map(last, sigs)
    all_distinct = length(unique(all_keys)) == 6

    (; sigs, gold3_sig, gold9_sig, e_sig, f_sig,
       e_eq_gold3 = (e_sig == gold3_sig),
       f_eq_gold9 = (f_sig == gold9_sig),
       all_distinct)
end

function _fmt_sp(pairs)
    join(("$v:$c" for (v, c) in pairs), " ")
end

function table2_report(io::IO = stdout)
    r = table2_run()
    print_section("Table II — CCZ-Equivalence Classes (σ-Signatures)", io)

    for (name, sig) in r.sigs
        nm = uppercase(String(name))
        diff_str  = _fmt_sp(sig[1])
        walsh_str = _fmt_sp(sig[2])
        print_kv("$nm diff-spectrum(π)", diff_str, io)
        print_kv("$nm Walsh-spectrum(π)", walsh_str, io)
    end

    print_check("σ(CLASS-E) = σ(Gold x³)", r.e_eq_gold3, io)
    print_check("σ(CLASS-F) = σ(Gold x⁹)", r.f_eq_gold9, io)
    print_check("all 6 σ-signatures distinct", r.all_distinct, io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    table2_report()
end
