# Discard the unpublished drafts of the catalog record on Zenodo.
#
# A failed publication can leave a draft of a new version. Zenodo then refuses the next new
# version (HTTP 400, "Please remove all files first"). This script deletes each unpublished
# draft of the concept record in prebuilt.toml; a published version is never touched. It is
# a CI script outside packages/VBFCatalog/src, so it is not part of the catalog snapshot key.
#
#   ZENODO_TOKEN=... julia --project=packages/VBFCatalog/src/import .github/scripts/zenodo_drafts.jl [--dry-run]
using JSON3, TOML

const API = "https://zenodo.org/api"
token = get(ENV, "ZENODO_TOKEN", "")
isempty(token) && error("set ZENODO_TOKEN")
dry = "--dry-run" in ARGS
concept = TOML.parsefile(joinpath(@__DIR__, "..", "..", "packages", "VBFCatalog", "src", "import", "prebuilt.toml"))["concept_recid"]

function zenodo(method, url)
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(`curl -sS --fail-with-body -X $method -H "Authorization: Bearer $token" $url`; stdout = out, stderr = err))
    text = String(take!(out))
    (; ok, text, err = String(take!(err)))
end

r = zenodo("GET", "$API/deposit/depositions?status=draft&size=100")
r.ok || error("Zenodo draft list failed: ", r.err, r.text)
drafts = [d for d in JSON3.read(r.text) if string(get(d, :conceptrecid, "")) == concept && !get(d, :submitted, false)]
isempty(drafts) && println("zenodo-drafts: no unpublished draft of concept $concept")
for d in drafts
    println("zenodo-drafts: unpublished draft $(d.id) of concept $concept", dry ? " (dry run: kept)" : ": deleting")
    dry && continue
    del = zenodo("DELETE", "$API/deposit/depositions/$(d.id)")
    if !del.ok
        # A new-version draft can refuse DELETE; discard it instead.
        dis = zenodo("POST", "$API/deposit/depositions/$(d.id)/actions/discard")
        dis.ok || error("cannot remove draft $(d.id): ", del.err, del.text, " / ", dis.err, dis.text)
    end
end
