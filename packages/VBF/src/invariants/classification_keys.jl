# Pure invariant keys shared by equivalence filters and catalog indexes.
# Preserve the existing tuple/string encoding so rebuilt indexes remain comparable.
import SHA

# --- the invariant ----------------------------------------------------------

"""
    sigma_key(F::SBox) -> Tuple

CCZ-invariant ortho-derivative signature: `(sorted_pairs(diff-spectrum(π_F)),
sorted_pairs(abs-Walsh-spectrum(π_F)))`. `F` must be a quadratic APN function.
"""
function sigma_key(F::SBox)
    pi = ortho_derivative(F)
    pi === nothing && error("sigma_key: ortho_derivative undefined (F not APN?)")
    sigma_key_from_ortho_derivative(pi)
end

"""Compute the sigma key from an already computed ortho-derivative.

The caller must supply the ortho-derivative of its verified quadratic APN.
This shares the signature encoding with [`sigma_key`](@ref) when the derivative
is also needed for evidence or other invariants.
"""
sigma_key_from_ortho_derivative(pi::SBox) =
    (sorted_pairs(differential_spectrum(pi)), sorted_pairs(absolute_walsh_spectrum(pi)))

"""Hash a precomputed ortho-derivative using the stable [`sigma_hash`](@ref) encoding."""
sigma_hash_from_ortho_derivative(pi::SBox) = bytes2hex(SHA.sha256(string(sigma_key_from_ortho_derivative(pi))))

"""
    sigma_hash(F::SBox) -> String

Stable hex digest (SHA-256 of `string(sigma_key(F))`) usable as a content key.
Different hashes imply different signatures and therefore CCZ-inequivalence
for quadratic APNs. Equal hashes are only a necessary filter, not an
equivalence certificate (and SHA-256 is not mathematically collision-free).
"""
sigma_hash(F::SBox) = bytes2hex(SHA.sha256(string(sigma_key(F))))

"""
    ccz_fingerprint_key(F::SBox) -> Tuple

CCZ-invariant fingerprint tuple for APN functions. Dimensions up to seven
include the Gamma and Delta ranks; larger dimensions use only differential
and absolute-Walsh spectra. The leading `(N, tier)` makes keys from different
dimensions/tiers incomparable.
"""
function ccz_fingerprint_key(F::SBox{N,T}) where {N,T}
    ds = sorted_pairs(differential_spectrum(F))
    ws = sorted_pairs(absolute_walsh_spectrum(F))
    if N ≤ 7
        return (N, 1, gamma_rank(F), delta_rank(F), ds, ws)
    else
        return (N, 2, ds, ws)
    end
end

"""
    ccz_fingerprint_hash(F::SBox) -> String

Stable hex digest (SHA-256 of `string(ccz_fingerprint_key(F))`). Different
hashes certify CCZ-inequivalence. Equal hashes are only a necessary filter;
they neither prove equal fingerprints nor equivalence.
"""
ccz_fingerprint_hash(F::SBox) = bytes2hex(SHA.sha256(string(ccz_fingerprint_key(F))))
