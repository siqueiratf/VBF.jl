# Implements paper-local helpers for the Kalgin–Idrisova (2020) reproduction.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: General — shared helpers, I/O, formatting
#
# VBF API used: SBox, anf, mobius!, apn_ea_mugshot, algebraic_degree

using VBF

# ── Report formatting ────────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Kalgin, Idrisova (2020): Classification of Quadratic APN Functions")
    println(io, "in 7 Variables — Cryptography and Communications 14, pp. 691–715")
    println(io, "=" ^ 72)
end

function print_section(title::AbstractString, io::IO = stdout)
    println(io, "\n── ", title, " ", "─" ^ max(0, 70 - length(title) - 4))
end

function print_check(label::AbstractString, ok::Bool, io::IO = stdout)
    tag = ok ? "[ OK ]" : "[FAIL]"
    println(io, "  ", tag, " ", label)
end

function print_kv(label::AbstractString, value, io::IO = stdout)
    println(io, "  ", label, ": ", value)
end

# ── Quadratic-part extraction ────────────────────────────────────────────────

"""
    quadratic_part(F::SBox{N,T}) -> SBox{N}

The quadratic part F^{(2)} of F: keeps only degree-2 ANF monomials.
Kalgin–Idrisova §6 uses this to define stacked APN functions.
"""
function quadratic_part(F::SBox{N,T}) where {N,T}
    a = anf(F)
    @inbounds for m = 0:(1 << N - 1)
        count_ones(m) == 2 || (a[m+1] = T(0))
    end
    mobius!(a)
    SBox{N}(Int.(a))
end

# ── EA-class deduplication ───────────────────────────────────────────────────

"""
    dedup_ea(fns) -> Vector

Deduplicate a list of quadratic APN SBox-es by EA-class (apn_ea_mugshot).
For quadratic APNs, EA-equivalence equals CCZ-equivalence (Yoshiara 2012).
"""
function dedup_ea(fns)
    seen = Set{Any}()
    out = eltype(fns)[]
    for f in fns
        sig = apn_ea_mugshot(f)
        sig ∉ seen && (push!(seen, sig); push!(out, f))
    end
    out
end
