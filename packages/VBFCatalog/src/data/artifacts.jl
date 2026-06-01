"""
Content-addressed bulk-data resolution.

Wraps the standard `Pkg.Artifacts` machinery so that callers ask for
data by **logical name** (`"bfa_apn_n7_v1"`) rather than path. The
indirection lets us:

- store artifacts off-repo (hundreds of MB of APN tables);
- pin via SHA-256 in [`Artifacts.toml`](../../Artifacts.toml);
- keep old paper-reproduction notebooks pointing at the artifact
  version they were authored against — even after newer versions ship.

# Public surface
- [`artifact_path`](@ref)  — local filesystem path of an installed artifact
  (downloads on first call when `lazy = true`).
- [`have_artifact`](@ref)  — has the artifact been installed locally?
- [`list_artifacts`](@ref) — every artifact name declared in `Artifacts.toml`.

No artifacts are declared at v0.1.0.
"""

import LazyArtifacts
import Artifacts
import TOML

_artifacts_toml() = normpath(joinpath(@__DIR__, "..", "..", "Artifacts.toml"))

"""
    list_artifacts() -> Vector{String}

Names of every artifact stanza declared in the package's `Artifacts.toml`.
Returns `String[]` when no artifacts have been declared yet (the v0.1
state of the package).
"""
function list_artifacts()
    path = _artifacts_toml()
    isfile(path) || return String[]
    data = try
        TOML.parsefile(path)
    catch
        return String[]
    end
    # Top-level keys are artifact names; filter to dict-valued entries.
    sort!(String[k for (k, v) in data if v isa AbstractDict])
end

"""
    have_artifact(name::AbstractString) -> Bool

`true` iff the named artifact is declared in `Artifacts.toml` *and* the
content tree exists in the local Julia depot.
"""
function have_artifact(name::AbstractString)
    name in list_artifacts() || return false
    hash = Artifacts.artifact_hash(String(name), _artifacts_toml())
    hash !== nothing && Artifacts.artifact_exists(hash)
end

"""
    artifact_path(name::AbstractString) -> String

Local filesystem path of the named artifact. Downloads + extracts on
first call (per `LazyArtifacts` semantics) when the artifact's
`lazy = true`. Throws `ArgumentError` if the artifact is not declared
in `Artifacts.toml`.
"""
function artifact_path(name::AbstractString)
    n = String(name)
    n in list_artifacts() || throw(
        ArgumentError(
            "artifact_path: $(repr(n)) is not declared in $(_artifacts_toml()); " *
            "see list_artifacts() for the current set",
        ),
    )
    Artifacts.@artifact_str n
end
