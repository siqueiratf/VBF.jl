@testitem "catalog_storage" begin
using Test, VBFCatalog
project=joinpath(pkgdir(VBFCatalog),"src","import")
script=joinpath(pkgdir(VBFCatalog),"test","import","storage.jl")
@test success(`$(Base.julia_cmd()) --startup-file=no --project=$project $script`)
end
