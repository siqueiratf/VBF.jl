"""Publication figures consuming the snapshot exported by VBFSearch; spectra use VBF."""
module SearchFigures
using VBF, VBFSearch, JSON3, Plots
export search_figures

function search_figures(directory;output=joinpath(directory,"publication"))
    VBFSearch.report(directory;output)
    snapshot=JSON3.read(read(joinpath(output,"snapshot.json"),String),Dict{String,Any})
    counts=snapshot["counts"]
    labels=["Exact LUTs","APN LUTs","Quadratic APN LUTs","Signature buckets","Reference-absent buckets"]
    values=[counts[k] for k in ("exact_luts","apn_luts","quadratic_apn_luts","quadratic_signature_buckets","corpus_absent_signature_buckets")]
    validation=bar(labels,values;legend=false,xrotation=25,ylabel="Count",title="Experiment snapshot; literature novelty unresolved")
    statuses=snapshot["units"]
    coverage=isempty(statuses) ? plot(;title="No construction plan",legend=false) :
        bar(sort!(collect(keys(statuses))),[statuses[k] for k in sort!(collect(keys(statuses)))];legend=false,ylabel="Construction units",title="Finite plan coverage")
    for (name,figure) in (("validation_counts",validation),("coverage",coverage)),ext in ("svg","pdf")
        savefig(figure,joinpath(output,name*"."*ext))
    end
    selected=filter(p->get(p,"evidence_level","")=="inequivalent_to_documented_quadratic_corpus",snapshot["candidates"])
    data=Dict{String,Any}[];panels=[]
    for p in first(selected,3)
        F=SBox{8}(hex2bytes(p["lut_hex"]));pi=ortho_derivative(F)
        VBF.sigma_hash(F)==p["sigma_hash"] || error("stored signature differs from VBF")
        row=Dict{String,Any}("lut_sha256"=>p["lut_sha256"],"sigma_hash"=>p["sigma_hash"])
        for (name,label,spectrum) in (("ortho_ddt_histogram","Differential multiplicity",differential_spectrum(pi)),
                ("ortho_absolute_walsh_histogram","Absolute Walsh coefficient",absolute_walsh_spectrum(pi)))
            pairs=VBF.sorted_pairs(spectrum)
            row[name]=[Dict("value"=>v,"count"=>c) for (v,c) in pairs]
            push!(panels,bar(first.(pairs),last.(pairs);legend=false,xlabel=label,ylabel="Frequency",title=p["lut_sha256"][1:12]))
        end
        push!(data,row)
    end
    open(io->JSON3.write(io,data),joinpath(output,"selected_invariants.json"),"w")
    if !isempty(panels)
        figure=plot(panels...;layout=(length(data),2),size=(900,300length(data)))
        for ext in ("svg","pdf");savefig(figure,joinpath(output,"ortho_spectra."*ext));end
    end
    abspath(output)
end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (1,2) || error("usage: search_figures.jl RUN [OUTPUT]")
    SearchFigures.search_figures(ARGS[1];output=length(ARGS)==2 ? ARGS[2] : joinpath(ARGS[1],"publication"))
end
