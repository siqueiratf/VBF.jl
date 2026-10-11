using VBFCatalog
function main(; functions_only=false,classes_only=false)
    db = load_catalog()
    try
        if !classes_only
            stats = functions_only ? build_sigma_index!(db; rebuild=true, corpora=String[]) : build_sigma_index!(db; rebuild=true)
            println(stats)
        end
        functions_only || populate_ccz_equivalence_classes!(db)
    finally
        close(db)
    end
end
abspath(PROGRAM_FILE) == (@__FILE__) && main(; functions_only="--functions-only" in ARGS,classes_only="--classes-only" in ARGS)
