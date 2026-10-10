# Implements Theorem 5.4 — Carlet's general bivariate construction.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 5 — Theorem 5.4 (P,Q,R,S linear), Remark 5.5
#
# Theorem 5.4: G(x,y) = P(x^{2^i+1}) + Q(x^{2^i}y) + R(xy^{2^i}) + S(y^{2^i+1})
# with P,Q,R,S linear, gcd(i,m)=1. F(x,y)=(xy,G(x,y)) is APN iff for all
# (c,d) != (0,0):
#   T_{c,d}(Y) = P(c^{2^i+1}Y) + Q(c^{2^i}dY) + R(cd^{2^i}Y) + S(d^{2^i+1}Y)
# satisfies:  m odd  -> T_{c,d} bijective;
#             m even -> ker(T_{c,d}) ∩ {u^{2^i+1}(t^{2^i}+t)} = {0}.
# Remark 5.5: {u^{2^i+1}(t^{2^i}+t)} = GF(2^m), so for m even the kernel
# condition is equivalent to T_{c,d} being bijective.
#
# Verification strategy: linear maps are represented as linearized polynomials
# L(x) = sum_j a_j x^{2^j}. The space of (P,Q,R,S) tuples is far too large for
# exhaustion ((2^m)^{4m} tuples), so we use a seeded random sample plus
# structured instances (Taniguchi, Zhou-Pott, Theorem 6.2) that guarantee APN
# representatives, and check condition <=> APN for every sample.
# VBF API used: gf_mul, gf_pow, gf_is_dth_power, primitive_polynomial, SBox,
#               differential_uniformity, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))
using Random

# Evaluate the linearized polynomial with coefficient vector `a` at x.
function _lin_eval(a::Vector{Int}, x::Int, m::Int, mod_m::Int)
    v = 0
    for j in eachindex(a)
        a[j] == 0 && continue
        v ⊻= gf_mul(a[j], gf_pow(x, 1 << (j - 1), m; modulus = mod_m), m;
                    modulus = mod_m)
    end
    v
end

# Build F(x,y) = (xy, P(x^{2^i+1}) + Q(x^{2^i}y) + R(xy^{2^i}) + S(y^{2^i+1})).
function _theorem5_4_sbox(m, i, P, Q, R, S, mod_m)
    Ei  = 1 << i
    len = 1 << m
    lut = Vector{Int}(undef, 1 << (2m))
    for x in 0:(len - 1), y in 0:(len - 1)
        xi = gf_pow(x, Ei, m; modulus = mod_m)
        yi = gf_pow(y, Ei, m; modulus = mod_m)
        G  = _lin_eval(P, gf_mul(x, xi, m; modulus = mod_m), m, mod_m) ⊻
             _lin_eval(Q, gf_mul(xi, y, m; modulus = mod_m), m, mod_m) ⊻
             _lin_eval(R, gf_mul(x, yi, m; modulus = mod_m), m, mod_m) ⊻
             _lin_eval(S, gf_mul(y, yi, m; modulus = mod_m), m, mod_m)
        lut[(x | (y << m)) + 1] = gf_mul(x, y, m; modulus = mod_m) | (G << m)
    end
    SBox{2m}(lut)
end

# Theorem 5.4 condition for one (P,Q,R,S); S0 is the set {u^{2^i+1}(t^{2^i}+t)}
# (only consulted when m is even).
function _theorem5_4_condition(m, i, P, Q, R, S, S0, mod_m)
    Ei  = 1 << i
    Ei1 = Ei + 1
    len = 1 << m
    for c in 0:(len - 1), d in 0:(len - 1)
        (c == 0 && d == 0) && continue
        ci  = gf_pow(c, Ei1, m; modulus = mod_m)
        cid = gf_mul(gf_pow(c, Ei, m; modulus = mod_m), d, m; modulus = mod_m)
        cdi = gf_mul(c, gf_pow(d, Ei, m; modulus = mod_m), m; modulus = mod_m)
        di  = gf_pow(d, Ei1, m; modulus = mod_m)
        if isodd(m)
            img = falses(len)
            n_img = 0
            for Y in 0:(len - 1)
                t = _lin_eval(P, gf_mul(ci, Y, m; modulus = mod_m), m, mod_m) ⊻
                    _lin_eval(Q, gf_mul(cid, Y, m; modulus = mod_m), m, mod_m) ⊻
                    _lin_eval(R, gf_mul(cdi, Y, m; modulus = mod_m), m, mod_m) ⊻
                    _lin_eval(S, gf_mul(di, Y, m; modulus = mod_m), m, mod_m)
                img[t + 1] || (img[t + 1] = true; n_img += 1)
            end
            n_img == len || return false
        else
            for Y in 1:(len - 1)
                Y in S0 || continue
                t = _lin_eval(P, gf_mul(ci, Y, m; modulus = mod_m), m, mod_m) ⊻
                    _lin_eval(Q, gf_mul(cid, Y, m; modulus = mod_m), m, mod_m) ⊻
                    _lin_eval(R, gf_mul(cdi, Y, m; modulus = mod_m), m, mod_m) ⊻
                    _lin_eval(S, gf_mul(di, Y, m; modulus = mod_m), m, mod_m)
                t == 0 && return false
            end
        end
    end
    true
end

"""
    theorem5_4_report([io]; ms, samples, seed) -> NamedTuple

Verify Theorem 5.4 (condition <=> APN) on seeded random (P,Q,R,S) samples and
structured instances (Taniguchi, Zhou-Pott, Theorem 6.2), for each m in `ms`
with all i s.t. gcd(i,m)=1, i<m/2 (i=1 for m=3). Also verifies Remark 5.5
({u^{2^i+1}(t^{2^i}+t)} = GF(2^m)) for m even.
"""
function theorem5_4_report(io::IO = stdout; ms::Vector{Int} = [3, 4],
                            samples::Int = 150, seed::Int = 24301)
    print_section("Theorem 5.4 — general bivariate construction (random sample)", io)
    rng    = Xoshiro(seed)
    all_ok = true
    stats  = Dict{Int,NamedTuple}()

    for m in ms
        mod_m = primitive_polynomial(m)
        len   = 1 << m
        is    = [ii for ii in 1:(m - 1) if gcd(ii, m) == 1 && (2ii < m || m == 3)]
        m == 3 && (is = [1])
        mism  = 0
        apn_n = 0
        total = 0
        rem55_ok = true

        for i in is
            # S0 = {u^{2^i+1}(t^{2^i}+t)} (m even); Remark 5.5: it is the full field
            S0 = Set{Int}()
            if iseven(m)
                for u in 0:(len - 1), t in 0:(len - 1)
                    push!(S0, gf_mul(gf_pow(u, (1 << i) + 1, m; modulus = mod_m),
                                     gf_pow(t, 1 << i, m; modulus = mod_m) ⊻ t,
                                     m; modulus = mod_m))
                end
                rem55_ok &= (length(S0) == len)
            end

            # structured instances guaranteeing APN hits
            zero_l = zeros(Int, m)
            structured = Vector{NTuple{4,Vector{Int}}}()
            #   Taniguchi a=1: P=z^{2^{2i}}, Q=z^{2^i}, R=0, S=b*z
            b_t = first(b for b in 1:(len - 1)
                        if bivariate_carlet_condition(m, i, 1, b; modulus = mod_m))
            P_t = zeros(Int, m); P_t[mod(2i, m) + 1] = 1
            Q_t = zeros(Int, m); Q_t[mod(i, m) + 1]  = 1
            S_t = zeros(Int, m); S_t[1] = b_t
            push!(structured, (P_t, Q_t, copy(zero_l), S_t))
            if iseven(m)
                #   Zhou-Pott: P=z, Q=R=0, S=alpha*z^{2^j}, alpha non-cube, j=2
                alpha = first(a for a in 1:(len - 1)
                              if !gf_is_dth_power(a, 3, m; modulus = mod_m))
                P_z = zeros(Int, m); P_z[1] = 1
                S_z = zeros(Int, m); S_z[3] = alpha
                push!(structured, (P_z, copy(zero_l), copy(zero_l), S_z))
                #   Theorem 6.2 (b=1, c=6 at m=4): P=z, Q=z^{2^{m/2}}, R=b*z, S=c*z
                bc = first((b, c) for b in 0:(len - 1) for c in 0:(len - 1)
                           if theorem6_2_condition(m, i, b, c; modulus = mod_m))
                P_6 = zeros(Int, m); P_6[1] = 1
                Q_6 = zeros(Int, m); Q_6[m ÷ 2 + 1] = 1
                R_6 = zeros(Int, m); R_6[1] = bc[1]
                S_6 = zeros(Int, m); S_6[1] = bc[2]
                push!(structured, (P_6, Q_6, R_6, S_6))
            end

            tuples = copy(structured)
            for _ in 1:samples
                push!(tuples, (rand(rng, 0:(len - 1), m), rand(rng, 0:(len - 1), m),
                               rand(rng, 0:(len - 1), m), rand(rng, 0:(len - 1), m)))
            end

            for (P, Q, R, S) in tuples
                cond = _theorem5_4_condition(m, i, P, Q, R, S, S0, mod_m)
                F    = _theorem5_4_sbox(m, i, P, Q, R, S, mod_m)
                apn  = (differential_uniformity(F) == 2)
                cond == apn || (mism += 1)
                apn && (apn_n += 1)
                total += 1
            end
        end

        ok = (mism == 0) && (apn_n > 0) && rem55_ok
        all_ok &= ok
        print_check("m=$m n=$(2m): condition <=> APN on $total sampled (P,Q,R,S)", mism == 0, io)
        print_kv("    APN instances among samples", apn_n, io)
        iseven(m) && print_check("m=$m: Remark 5.5 — {u^{2^i+1}(t^{2^i}+t)} = GF(2^$m)",
                                 rem55_ok, io)
        stats[m] = (; ok, total, apn_n, mism)
    end

    print_kv("completeness", "seeded random sample (seed=$(seed)) + structured instances", io)
    (; all_ok, stats)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_4_report()
end
