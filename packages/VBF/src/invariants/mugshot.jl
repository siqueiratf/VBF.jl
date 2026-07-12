"""
APN-EA mugshot — a fingerprint built from EA-invariant spectra.

For a quadratic APN function `F`, the **linear-equivalence class of
its ortho-derivative `π_F`** is an EA-equivalence-class invariant
([Canteaut, Couvreur and Perrin, 2022](@cite Canteaut_202205)). The
mugshot exploits this by hashing the easily-
computed spectra of `π_F` — the signed Walsh spectrum and the DDT
spectrum — into a comparable tuple.

For non-quadratic APN (where the ortho-derivative is undefined), the
mugshot falls back to F's own spectra: absolute Walsh, **component**
degree spectrum, sigma multiplicities, and thickness (when F is a
permutation). The component degree spectrum is the multiset of
algebraic degrees of the 2ⁿ-1 nonzero components `x ↦ ⟨b, F(x)⟩`,
with degrees ≤ 1 collapsed to 1: under `G = A₁∘F∘A₂ ⊕ A_drift` the
component `⟨b, G⟩ = ⟨A₁ᵀb, F⟩∘A₂ ⊕ ⟨b, A_drift⟩` where `b ↦ A₁ᵀb` is a
bijection of the nonzero masks, affine pre-composition preserves the
degree, and adding the affine `⟨b, A_drift⟩` preserves degrees ≥ 2 and
maps the class {degree ≤ 1} to itself — hence the multiset is a genuine
EA-invariant. (The per-*coordinate* `degree_spectrum` used before is
basis-dependent and is **not** EA-invariant.)

# Use cases

- **Fast EA-rejection**: `apn_ea_mugshot(F) ≠ apn_ea_mugshot(G)` ⇒
  `F !~_EA G`. The reverse implication is not asserted — equal
  mugshots are necessary but not sufficient.
- **Class indexing**: use the mugshot as a dictionary key for
  bucketing APN functions during catalog scans.
"""

"""
    APNEAMugshot

Tagged-union-style return type of [`apn_ea_mugshot`](@ref).

# Fields by kind
- `kind = :quadratic` — `(:walsh::Spectrum, :ddt::Spectrum)` of `π_F`.
- `kind = :non_quadratic` — `(:abs_walsh::Spectrum, :degree::Spectrum,
  :sigma::Spectrum, :thickness::Vector{Int})` of `F`, where `:degree`
  is the EA-invariant **component** degree spectrum (see the module
  docstring). The thickness vector is empty when `F` is not a
  permutation.
"""
struct APNEAMugshot
    kind::Symbol
    fields::NamedTuple
end

Base.:(==)(a::APNEAMugshot, b::APNEAMugshot) =
    a.kind == b.kind && a.fields == b.fields

Base.hash(m::APNEAMugshot, h::UInt) =
    hash(m.fields, hash(m.kind, hash(:APNEAMugshot, h)))

function Base.show(io::IO, m::APNEAMugshot)
    print(
        io,
        "APNEAMugshot{kind=",
        m.kind,
        ", ",
        length(m.fields),
        " components}",
    )
end

"""
    component_degree_spectrum(F::SBox{N,T}) -> Spectrum

Multiset of the algebraic degrees of the `2ⁿ - 1` nonzero components
`x ↦ ⟨b, F(x)⟩` of `F`, with degrees ≤ 1 collapsed to 1. A genuine
EA-invariant (unlike the per-coordinate [`degree_spectrum`](@ref),
which is basis-dependent); see the module docstring for the argument.
Computed from a single ANF pass: the coefficient of monomial `m` in
`⟨b, F⟩` is `⟨b, a[m]⟩` where `a = anf(F)`.
"""
function component_degree_spectrum(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    a = anf(F)
    # Monomial masks ordered by decreasing weight so the first hit is the degree.
    order = sort(collect(1:(n_size-1)); by = m -> count_ones(m), rev = true)
    spec = Spectrum()
    for b = 1:(n_size-1)
        deg = 0
        for m in order
            if parity(UInt(b) & UInt(a[m+1])) == 1
                deg = count_ones(m)
                break
            end
        end
        add!(spec, max(deg, 1))
    end
    return spec
end

"""
    apn_ea_mugshot(F::SBox{N,T}) -> APNEAMugshot

Compute the EA-equivalence-class fingerprint of `F`. For quadratic APN,
the mugshot is the Walsh + DDT spectra of the ortho-derivative `π_F`;
otherwise the spectra of `F` itself.

Two EA-equivalent functions have equal mugshots:

    F ~_EA G  ⇒  apn_ea_mugshot(F) == apn_ea_mugshot(G).

Equal mugshots are *necessary but not sufficient* for EA-equivalence: Gold `x³`
and `x⁵` over `F₂⁵` share a mugshot but are EA- (and CCZ-) inequivalent. So a
mugshot is a **bucketing key, not a decision procedure** — confirm a bucket with
[`are_ea_equivalent`](@ref) before collapsing it, or class counts come out too
low.

Nor does a mugshot *mismatch* certify CCZ-inequivalence. The mugshot is computed
from different data for quadratic and non-quadratic `F` (ortho-derivative spectra
vs. the function's own), and algebraic degree is **not** a CCZ-invariant: the Kim
function (degree 2) and Dillon's APN permutation (degree 4) have different
mugshots and are nonetheless CCZ-equivalent. A mismatch certifies
EA-inequivalence only; for CCZ it is conclusive just when both functions are
quadratic APN, where CCZ and EA coincide (Yoshiara).
"""
function apn_ea_mugshot(F::SBox{N,T}) where {N,T}
    deg = algebraic_degree(F)
    if deg == 2
        π = ortho_derivative(F)
        π === nothing && throw(
            ArgumentError(
                "apn_ea_mugshot: F has algebraic_degree 2 but is not a quadratic APN",
            ),
        )
        walsh_spec = Spectrum()
        for w in vec(lat(π))
            add!(walsh_spec, w)
        end
        ddt_spec = Spectrum()
        for d in vec(ddt(π))
            add!(ddt_spec, d)
        end
        return APNEAMugshot(:quadratic, (walsh = walsh_spec, ddt = ddt_spec))
    else
        abs_walsh = absolute_walsh_spectrum(F)
        deg_spec = component_degree_spectrum(F)
        sig = sigma_multiplicities(F)
        thk = is_permutation(F) ? thickness_spectrum(F) : Int[]
        return APNEAMugshot(
            :non_quadratic,
            (
                abs_walsh = abs_walsh,
                degree = deg_spec,
                sigma = sig,
                thickness = thk,
            ),
        )
    end
end
