# Implements Section 3.2 — Lemma 1 (Category separation for orbit partition)
# Paper: Ichanska, Berg, Kaleyski, Yu (2024/2025), "Pushing the QAM method for finding APN functions further"
# Section: 3.2 — Partitioning without the set of linear permutations
#
# Pseudocode:
#   1. Partition F₂ⁿ \ {0} into categories Cat₁ᵐ and Cat_Ind based on conjugate relations
#   2. Cat₁ᵐ = {α ≠ 0 : α + α^{2^m} = 0}  (elements in F₂ᵐ-subfield)
#   3. Cat_Ind = F₂ⁿ \ {0} \ Cat₁ᵐ
#   4. Lemma 1: if l ∈ L (linear perm with F₂ᵐ coefficients) then l(Cat₁) ⊆ Cat₁
#      → different categories cannot be in the same orbit
# VBF API used: gf_pow, gf_mul, conway_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    compute_categories(n, m; modulus) -> (cat1, cat_ind)

Partition F₂ⁿ - {0} into Cat₁ᵐ = {α : α + α^{2^m} = 0} and Cat_Ind = complement.
For (n=8, m=2): Cat₁ = {1, a^85, a^170} = F₄ - {0}, Cat_Ind has 252 elements.
"""
function compute_categories(n::Int, m::Int; modulus::Int = conway_polynomial(n))
    cat1 = [α for α in 1:(1<<n)-1 if is_in_cat1(α, n, m; modulus = modulus)]
    cat_ind = [α for α in 1:(1<<n)-1 if !is_in_cat1(α, n, m; modulus = modulus)]
    (cat1, cat_ind)
end

"""
    verify_lemma1_preservation(n, m; modulus, num_perms=20) -> Bool

Lemma 1: Linear perms with F₂ᵐ coefficients preserve categories.
Proof: for l(x) = Σᵢ αᵢ x^{2^i} with αᵢ ∈ F₂ᵐ and α ∈ Cat₁ (α + α^{2^m}=0):
  l(α) + l(α)^{2^m} = l(α + α^{2^m}) = l(0) = 0  → l(α) ∈ Cat₁.
Verified numerically by checking that linear maps preserve Cat₁.
"""
function verify_lemma1_preservation(n::Int, m::Int;
                                     modulus::Int = conway_polynomial(n),
                                     num_perms::Int = 20)
    cat1, _ = compute_categories(n, m; modulus = modulus)
    sf = subfield_elements(n, m; modulus = modulus)

    checked = 0
    for coeffs in Iterators.product(ntuple(_ -> sf, n)...)
        lut = zeros(Int, 1 << n)
        for x in 1:(1<<n)-1
            lut[x+1] = apply_linear_map(collect(coeffs), x, n; modulus = modulus)
        end
        length(Set(lut)) == (1 << n) || continue
        # Check l maps Cat₁ into Cat₁
        for α in cat1
            is_in_cat1(lut[α+1], n, m; modulus = modulus) || return false
        end
        checked += 1
        checked >= num_perms && break
    end
    true
end

function lemma1_report(io::IO = stdout)
    print_section(io, "Lemma 1: Category separation — different categories → different orbits (Section 3.2)")

    n = 8; m = 2; mod = conway_polynomial(n)
    cat1, cat_ind = compute_categories(n, m; modulus = mod)

    print_kv(io, "n", n)
    print_kv(io, "m", m)
    print_kv(io, "|Cat₁| (= |F₄ \\ {0}|)", length(cat1))
    print_kv(io, "|Cat_Ind|", length(cat_ind))
    print_check(io, "|Cat₁| + |Cat_Ind| = $(1<<n) - 1",
                length(cat1) + length(cat_ind) == (1<<n) - 1)

    # Verify Cat₁ = F₄ \ {0} = {a^0, a^85, a^170}
    a85  = gf_pow(2, 85,  n; modulus = mod)
    a170 = gf_pow(2, 170, n; modulus = mod)
    print_check(io, "1 ∈ Cat₁",    is_in_cat1(1,    n, m; modulus = mod))
    print_check(io, "a^85 ∈ Cat₁", is_in_cat1(a85,  n, m; modulus = mod))
    print_check(io, "a^170 ∈ Cat₁",is_in_cat1(a170, n, m; modulus = mod))
    print_check(io, "a ∉ Cat₁ (a ∈ Cat_Ind)", !is_in_cat1(2, n, m; modulus = mod))

    # Verify preservation algebraically (sample 30 perms)
    pass = verify_lemma1_preservation(n, m; modulus = mod, num_perms = 30)
    print_check(io, "Linear perms with F₂² coefficients map Cat₁ → Cat₁ (sample 30)", pass)

    print_kv(io, "completeness", "exact (algebraic proof + numerical verification, 30 sampled perms)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    lemma1_report()
end
