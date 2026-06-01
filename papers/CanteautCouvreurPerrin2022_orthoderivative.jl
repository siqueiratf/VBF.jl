using VBF
using VBFCatalog

function reproduce()
    F3 = load_apn_function("n5_Gold_x3")
    F5 = load_apn_function("n5_Gold_x5")
    (; gold3_quadratic_apn = is_quadratic_apn(F3),
       gold5_quadratic_apn = is_quadratic_apn(F5),
       x3_self_ea          = are_ea_equivalent(F3, F3),
       x3_ea_equiv_x5      = are_ea_equivalent(F3, F5))
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Ortho-derivative EA-distinction — Canteaut–Couvreur–Perrin, IEEE TIT 2022")
    println(io, "n=5 Gold x^3 quadratic APN : ", r.gold3_quadratic_apn)
    println(io, "n=5 Gold x^5 quadratic APN : ", r.gold5_quadratic_apn)
    println(io, "x^3 EA-equivalent to itself: ", r.x3_self_ea)
    println(io, "x^3 EA-equivalent to x^5   : ", r.x3_ea_equiv_x5, "  (expected false)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
