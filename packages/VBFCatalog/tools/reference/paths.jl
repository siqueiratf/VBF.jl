"""
Resolve an input path recorded before the census data relocation.

Only the known retired `census/quadratic_apn8/` prefix is relocated. Callers
must still verify the recorded byte digest. Archived manifests are never edited;
this lookup does not make changed computation code eligible to resume a run.
"""
function artifact_path(path::AbstractString)
    ispath(path) && return path
    normalized=replace(String(path),'\\'=>'/')
    marker="census/quadratic_apn8/"
    index=findfirst(marker,normalized)
    index===nothing && return path
    tail=normalized[last(index)+1:end]
    root=normpath(joinpath(@__DIR__,"../../../../data/apn/archive/census"))
    target=normpath(joinpath(root,tail))
    startswith(target,root*"/") || error("archived input escapes data directory")
    ispath(target) ? target : path
end
