# Implements Section 5 total-class estimators
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 5
#
# Pseudocode:
#   1. Maximize choose(N,l)/N^t by locating the integer where the log-likelihood stops increasing.
#   2. Recompute the known-class overlap estimate t*M/(t-t').
#   3. Report both paper estimates from the stated constants.
# VBF API used: none

include(joinpath(@__DIR__, "helpers.jl"))

function _coupon_delta(t::Integer, l::Integer, N::Integer)
    tt = Float64(t)
    ll = Float64(l)
    NN = Float64(N)
    log((NN + 1) / (NN + 1 - ll)) - tt * log((NN + 1) / NN)
end

"Integer maximum-likelihood estimate for the inverse coupon-collector model."
function coupon_collector_mle(t::Integer, l::Integer)
    tt = Int(t)
    ll = Int(l)
    0 < ll <= tt || throw(ArgumentError("need 0 < l <= t"))
    low = ll
    high = max(low + 1, 2low)
    while _coupon_delta(tt, ll, high) > 0
        high *= 2
    end
    lo = low
    hi = high
    while lo < hi
        mid = (lo + hi) >>> 1
        if _coupon_delta(tt, ll, mid) > 0
            lo = mid + 1
        else
            hi = mid
        end
    end
    lo
end

"Estimate N from known M classes and t' samples outside those M classes."
overlap_estimate(M::Integer, t::Integer, t_new::Integer) =
    Float64(t) * Float64(M) / Float64(Int(t) - Int(t_new))

"Recompute both Section 5 estimates."
function paper_estimators()
    coupon = coupon_collector_mle(RANDOM_SEARCH_TOTAL, RANDOM_SEARCH_DISTINCT)
    overlap = overlap_estimate(
        SECTION41_KNOWN_OR_FOUND_CLASSES,
        RANDOM_SEARCH_TOTAL,
        RANDOM_SEARCH_NEW_OUTSIDE_SECTION41,
    )
    (;
        coupon_mle = coupon,
        overlap_estimate = overlap,
        overlap_estimate_rounded = round(Int, overlap),
        t = RANDOM_SEARCH_TOTAL,
        distinct = RANDOM_SEARCH_DISTINCT,
        known_or_found = SECTION41_KNOWN_OR_FOUND_CLASSES,
        outside_known_or_found = RANDOM_SEARCH_NEW_OUTSIDE_SECTION41,
    )
end

"Report the Section 5 numerical estimates."
function estimators_report(io::IO = stdout)
    print_section("Section 5 Estimators", io)
    r = paper_estimators()
    print_check("coupon-collector MLE is near 6,123,206", abs(r.coupon_mle - 6_123_206) <= 2, io)
    print_check("overlap estimate rounds near 5,786,151", abs(r.overlap_estimate_rounded - 5_786_151) <= 2, io)
    print_kv("sample size t", r.t, io)
    print_kv("distinct labels l", r.distinct, io)
    print_kv("coupon MLE", r.coupon_mle, io)
    print_kv("M known/found by Section 4.1", r.known_or_found, io)
    print_kv("samples outside M", r.outside_known_or_found, io)
    print_kv("overlap estimate", r.overlap_estimate_rounded, io)
    print_kv("completeness", "exact numerical recomputation from paper constants", io)
    r
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    estimators_report()
end
