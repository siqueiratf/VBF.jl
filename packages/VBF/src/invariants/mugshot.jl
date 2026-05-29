"""
APN-EA mugshot — a fingerprint built from EA-invariant spectra.

For a quadratic APN function `F`, the **linear-equivalence class of
its ortho-derivative `π_F`** is an EA-equivalence-class invariant
(Carlet-Charpin-Kyureghyan 2007; refined by Canteaut-Charpin-
Kyureghyan TIT 2022). The mugshot exploits this by hashing the easily-
computed spectra of `π_F` — the signed Walsh spectrum and the DDT
spectrum — into a comparable tuple.

For non-quadratic APN (where the ortho-derivative is undefined), the
mugshot falls back to F's own spectra: absolute Walsh, degree, sigma
multiplicities, and thickness (when F is a permutation).

Port of `cpp_apn_ea_mugshot` in `sboxU/cpp/apn/invariants.cpp`.

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
  :sigma::Spectrum, :thickness::Vector{Int})` of `F`. The thickness
  vector is empty when `F` is not a permutation.
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
    print(io, "APNEAMugshot{kind=", m.kind, ", ", length(m.fields), " components}")
end

"""
    apn_ea_mugshot(F::SBox{N,T}) -> APNEAMugshot

Compute the EA-equivalence-class fingerprint of `F`. For quadratic APN,
the mugshot is the Walsh + DDT spectra of the ortho-derivative `π_F`;
otherwise the spectra of `F` itself.

Two EA-equivalent functions have equal mugshots:

    F ~_EA G  ⇒  apn_ea_mugshot(F) == apn_ea_mugshot(G).

Equal mugshots are *necessary but not sufficient* for EA-equivalence.
"""
function apn_ea_mugshot(F::SBox{N,T}) where {N,T}
    deg = algebraic_degree(F)
    if deg == 2
        π = ortho_derivative(F)
        π === nothing && throw(ArgumentError(
            "apn_ea_mugshot: F has algebraic_degree 2 but is not a quadratic APN"))
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
        deg_spec  = degree_spectrum(F)
        sig       = sigma_multiplicities(F)
        thk = is_permutation(F) ? thickness_spectrum(F) : Int[]
        return APNEAMugshot(:non_quadratic, (
            abs_walsh = abs_walsh,
            degree    = deg_spec,
            sigma     = sig,
            thickness = thk,
        ))
    end
end
