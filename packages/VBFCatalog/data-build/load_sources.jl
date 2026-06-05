# Shared path-resolution helpers for external data sources.
# Include-guarded so that chained includes from build_catalog.jl and
# importer scripts do not redefine constants.
@isdefined(_BFA_SOURCES_LOADED) && return
const _BFA_SOURCES_LOADED = true

import TOML

const _SOURCES_TOML = joinpath(@__DIR__, "sources.toml")

function _bfa_source_config(name::AbstractString)
    config = TOML.parsefile(_SOURCES_TOML)
    for src in get(config, "source", [])
        src["name"] == name && return src
    end
    nothing
end

function _bfa_check_valid(root::AbstractString, check_path::AbstractString,
                           check_kind::AbstractString)
    p = joinpath(root, check_path)
    check_kind == "file" ? isfile(p) : isdir(p)
end

"""
    with_source(f, name) -> result of f, or nothing if source unavailable

Resolve the named external source from sources.toml and call `f(root_path)`.

Resolution order:
1. `ENV[src.env_var]` if set and the check_path exists under it.
2. Shallow-clone `src.upstream` into a `mktempdir()` and call `f` inside the
   do-block so the temp dir is deleted automatically on return.
3. Warn and return `nothing` if the source is unavailable.
"""
function with_source(f::Function, name::AbstractString)
    src = _bfa_source_config(name)
    src === nothing && error("BFA: unknown source '$name' in sources.toml")

    label      = get(src, "label", name)
    env_var    = src["env_var"]
    check_path = src["check_path"]
    check_kind = get(src, "check_kind", "dir")

    env_val = get(ENV, env_var, "")
    if !isempty(env_val)
        if _bfa_check_valid(env_val, check_path, check_kind)
            return f(env_val)
        else
            @warn "BFA: $env_var set but check failed; ignoring" path=env_val check=check_path
        end
    end

    if haskey(src, "upstream")
        @info "BFA: $label: $env_var not set; cloning from upstream" url=src["upstream"]
        return mktempdir() do tmpdir
            run(`git clone --depth=1 $(src["upstream"]) $tmpdir`)
            _bfa_check_valid(tmpdir, check_path, check_kind) ||
                error("BFA: cloned $(src["upstream"]) but " *
                      "$(check_kind) '$check_path' not found in $tmpdir")
            f(tmpdir)
        end
    end

    @warn "BFA: $label not available; set $env_var to enable"
    nothing
end

"""
    source_short_sha(path) -> String

`git -C path rev-parse --short HEAD`; returns "unknown" if git fails.
"""
function source_short_sha(path::AbstractString)
    try
        readchomp(`git -C $path rev-parse --short HEAD`)
    catch
        "unknown"
    end
end
