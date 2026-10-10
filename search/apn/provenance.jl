"""Fingerprint implementation and environment before loading computational packages."""
function source_fingerprint_impl(repo_root)
    paths=[joinpath(repo_root,"Project.toml"),joinpath(repo_root,"Manifest.toml"),joinpath(repo_root,"packages/VBF/Project.toml"),joinpath(repo_root,"packages/VBFCatalog/Project.toml"),joinpath(repo_root,"bin/vbf"),joinpath(@__DIR__,"report.py")]
    for dir in (joinpath(repo_root,"packages/VBF/src"),joinpath(repo_root,"packages/VBFCatalog/src"),@__DIR__)
        for (d,dirs,files) in walkdir(dir)
            filter!(name->!(name in ("results","test")),dirs)
            occursin("/results",d) && continue
            append!(paths,[joinpath(d,f) for f in files if endswith(f,".jl") && !occursin("/test",d)])
        end
    end
    Dict(relpath(p,repo_root)=>bytes2hex(open(SHA.sha256,p)) for p in sort!(unique(paths)) if isfile(p))
end
