@isdefined(_BFA_SOURCES_LOADED) && return
const _BFA_SOURCES_LOADED = true
import TOML
using VBFCatalog: catalog_data_dir
const _SOURCES_TOML = joinpath(VBFCatalog.catalog_source_dir(), "sources.toml")
_bfa_source_config(name) = only(s for s in TOML.parsefile(_SOURCES_TOML)["source"] if s["name"] == name)
_bfa_check_valid(root, path, kind) = kind == "file" ? isfile(joinpath(root,path)) : isdir(joinpath(root,path))
function _bfa_source_root(src)
    override=get(ENV,get(src,"env_var",""),"")
    isempty(override) ? joinpath(catalog_data_dir(),"raw",get(src,"cache_name",src["name"])) : override
end

"""Use a local override or fetch and retain a pinned upstream checkout.

Originals remain in packages/VBFCatalog/data/raw. Large standalone downloads are
explicitly fetched with fetch.jl; importing the package never fetches data.
"""
function with_source(f::Function, name::AbstractString)
    src = _bfa_source_config(name)
    root = _bfa_source_root(src)
    check_path = src["check_path"]; kind = get(src,"check_kind","dir")
    if _bfa_check_valid(root,check_path,kind)
        if haskey(src,"revision")
            readchomp(`git -C $root rev-parse HEAD`)==src["revision"] || error("cached source revision changed: $name")
            paths=haskey(src,"files") ? (kind=="file" ? src["files"] : joinpath.(check_path,src["files"])) : [check_path]
            success(`git -C $root diff --quiet $(src["revision"]) -- $paths`) || error("cached source files changed: $name")
        end
        return f(root)
    end
    if haskey(src,"upstream")
        haskey(src,"revision") || error("upstream source must have a pinned revision: $name")
        ispath(root) && error("incomplete source cache at $root; remove it or set $(src["env_var"])")
        mkpath(dirname(root))
        mktempdir(dirname(root)) do tmp
            checkout = joinpath(tmp,"checkout")
            run(`git clone --quiet $(src["upstream"]) $checkout`)
            run(`git -C $checkout checkout --quiet --detach $(src["revision"])`)
            _bfa_check_valid(checkout,check_path,kind) || error("upstream source missing $check_path")
            mv(checkout,root)
        end
        return f(root)
    end
    error("source $name unavailable; run fetch.jl or set $(src["env_var"])")
end

source_revision(path) = readchomp(`git -C $path rev-parse HEAD`)

"""Dataset declaration shared by converters and source/database checks."""
corpus_entry(name) = only(e for e in TOML.parsefile(joinpath(VBFCatalog.catalog_source_dir(),"corpora.toml"))["corpus"] if e["name"]==name)
