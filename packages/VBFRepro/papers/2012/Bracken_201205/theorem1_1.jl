# Theorem 1.1: the smallest genuine binomial instance, (k,s)=(10,2), n=30.
# The exact coefficient-orbit reduction lives in orbit_certificate.jl. The
# legacy literal streaming/rank helpers remain available as independent controls.
include(joinpath(@__DIR__, "orbit_certificate.jl"))

const THEOREM11_K = 10
const THEOREM11_S = 2

"""Exact source function: alpha*x^5 + alpha^(2^10)*x^(2^20+2^12)."""
theorem1_1_instance() =
    bracken_binomial(THEOREM11_K, THEOREM11_S; allow_nonpermutation=false)

"""
    theorem1_1_report(io=stdout; full_search=false, max_coefficients=256,
                      timeout_seconds=30, save_results=false)

Check a bounded coefficient prefix by default. `full_search=true` attempts all
49,981 normalized coefficients, covering every original input difference and
nonzero component through exact coset identities. Only a completed walk can
certify the n30 DU4/permutation/Walsh-support claims. This neither classifies
CCZ classes nor proves the infinite construction family.
"""
function theorem1_1_report(io::IO=stdout; full_search::Bool=false,
        max_coefficients::Int=256, timeout_seconds::Real=30, save_results::Bool=false)
    orbit_certificate_report(io; full_search,max_coefficients,timeout_seconds,save_results)
end

if abspath(PROGRAM_FILE)==@__FILE__
    theorem1_1_report()
end
