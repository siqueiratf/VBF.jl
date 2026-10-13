"""Render the author's curated publication assessments, resolving runner slugs to BibTeX keys.
This formats recorded assessments; it does not grade mathematical correctness.
"""
function write_audit_table(rows,out)
    mkpath(out)
    labels=Dict("A"=>"Quadratic APN constructions","B"=>"Computational search",
        "C"=>"Equivalence classification","D"=>"Sporadic instances and case studies")
    grades=Dict("f"=>"\\gf","h"=>"\\gh","o"=>"\\go")
    taxonomy=TOML.parsefile(joinpath(@__DIR__,"analysis","reproductions","taxonomy.toml"))["papers"]
    ordered=sort!(collect(rows);by=r->(string(r.category),-Int(r.year),string(r.paper_key)))
    path=joinpath(out,"tab_audit.tex")
    open(path,"w") do io
        println(io,raw"\begin{tabular}{@{}>{\raggedright\arraybackslash}p{5.2cm}cccc@{}}")
        println(io,raw"\toprule Reference & R1 & R2 & R3 & R4 \\ \midrule")
        previous=""
        for r in ordered
            category=string(r.category)
            if category!=previous
                println(io,"\\multicolumn{5}{@{}l}{\\textbf{(",category,") ",labels[category],"}} ",repeat("\\",2))
                previous=category
            end
            id=string(r.paper_key)
            key=get(get(taxonomy,id,Dict()),"citation_key",something(VBFRepro.paper_bib_key(id),id))
            occursin(r"^[A-Za-z0-9_-]+$",key) || error("invalid bibliography key: $key")
            println(io,"\\tabref{",key,"} & ",join((grades[string(getproperty(r,axis))] for axis in (:r1,:r2,:r3,:r4))," & ")," \\\\")
        end
        println(io,raw"\bottomrule\end{tabular}")
    end
    path
end

"""Stage an Overleaf checkout and generated audit table without editing the checkout.

The staged main document replaces its existing `tab:audit` tabular body with
an input of the generated table. Missing/ambiguous anchors fail closed. Inputs,
table, package sources, environment and Overleaf revision are digest-bound.
"""
function stage_paper(;source=joinpath(document_root(),"overleaf"),
        output=joinpath(workspace_root(),"packages","VBFPaper","doc","generated","paper"),
        assessments=joinpath(@__DIR__,"analysis","reproductions","curated_bfa4r.csv"),
        main="main.tex",compile=false)
    source=realpath(source);output=abspath(output)
    basename(main)==main && endswith(main,".tex") || throw(ArgumentError("main must be a TeX filename"))
    (output==source || startswith(output,source*string(Base.Filesystem.path_separator))) &&
        throw(ArgumentError("build output must be outside the Overleaf checkout"))
    ispath(output) && throw(ArgumentError("build output already exists; choose a fresh directory"))
    rows=CSV.File(assessments)
    text=read(joinpath(source,main),String)
    anchor=r"(\\label\{tab:audit\}.*?)(\\begin\{tabular\}.*?\\end\{tabular\})"s
    length(collect(eachmatch(anchor,text)))==1 || error("expected exactly one tab:audit table in $main")
    mkpath(output)
    hashes=Dict{String,String}()
    for (dir,dirs,files) in walkdir(source)
        filter!(d->d!=".git",dirs)
        for file in files
            file==".git" && continue
            path=joinpath(dir,file);relative=relpath(path,source);target=joinpath(output,relative)
            mkpath(dirname(target));cp(path,target)
            hashes[relative]=bytes2hex(open(sha256,path))
        end
    end
    generated=joinpath(output,"generated")
    table=write_audit_table(rows,generated)
    staged=replace(text,anchor=>s"\1\\input{generated/tab_audit.tex}")
    write(joinpath(output,main),staged)
    revision=try chomp(read(pipeline(`git -C $source rev-parse HEAD`;stderr=devnull),String)) catch; "unavailable" end
    environment=Dict{String,String}()
    for filename in ("Project.toml","Manifest.toml")
        path=joinpath(dirname(@__DIR__),filename)
        filename=="Manifest.toml" && !isfile(path) && (path=joinpath(workspace_root(),filename))
        isfile(path) || continue
        cp(path,joinpath(output,filename));environment[filename]=bytes2hex(open(sha256,path))
    end
    sources=Dict(relpath(joinpath(d,f),@__DIR__)=>bytes2hex(open(sha256,joinpath(d,f)))
        for (d,_,fs) in walkdir(@__DIR__) for f in fs if endswith(f,".jl") || endswith(f,".toml") || endswith(f,".csv"))
    metadata=Dict("schema_version"=>1,"overleaf_commit"=>revision,"julia_version"=>string(VERSION),
        "source_files"=>hashes,"implementation_files"=>sources,"environment"=>environment,
        "assessments_sha256"=>bytes2hex(open(sha256,assessments)),
        "publication_metadata_sha256"=>bytes2hex(open(sha256,VBFRepro.publications_path())),
        "table_sha256"=>bytes2hex(open(sha256,table)),"main"=>main,
        "curated_assessments"=>length(rows),"compile_requested"=>compile,"compiled"=>false)
    manifest=joinpath(output,"build.toml")
    save()=open(io->TOML.print(io,metadata;sorted=true),manifest,"w")
    save()
    if compile
        executable=Sys.which("latexmk");executable===nothing && error("latexmk is required to compile the staged paper")
        run(Cmd(`$executable -pdf -interaction=nonstopmode -halt-on-error $main`;dir=output))
        metadata["compiled"]=true;metadata["pdf_sha256"]=bytes2hex(open(sha256,joinpath(output,replace(main,".tex"=>".pdf"))))
        save()
    end
    output
end
