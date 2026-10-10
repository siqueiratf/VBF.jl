using VBFCatalog
include("load_sources.jl")

"""Run one registered raw-data converter against the selected catalog.

The converter streams or parses its own original format. All function-row
insertion goes through write.jl; bulk coefficients use VBFCatalog's corpus API.
"""
function convert_source(name)
    path=joinpath(@__DIR__,_bfa_source_config(name)["converter"])
    isfile(path) || error("missing converter: $path")
    context=Module(gensym(:CatalogConverter))
    Core.eval(context,:(include(path)=Base.include($context,path)))
    Base.include(context,path)
    Base.invokelatest(() -> getproperty(context,:main)())
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    isempty(ARGS) && error("usage: convert.jl SOURCE [converter options]")
    convert_source(first(ARGS))
end
