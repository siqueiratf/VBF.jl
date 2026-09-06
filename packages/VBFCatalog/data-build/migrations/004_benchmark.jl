using VBFCatalog
import VBFCatalog: SQLite, DBInterface

"""Add raw benchmark storage to a version 3 catalog, preserving all existing rows."""
function migrate_benchmark(path = VBFCatalog.catalog_path())
    isfile(path) || error("Catalog does not exist: $path")
    db = SQLite.DB(path)
    try
        version = only([Int(r.schema_version) for r in
            DBInterface.execute(db, "SELECT schema_version FROM schema_meta")])
        version in (3, 4) || error("Expected schema 3 or 4, found $version")
        SQLite.transaction(db) do
            for stmt in VBFCatalog._split_ddl(read(joinpath(pkgdir(VBFCatalog),
                    "src", "data", "benchmark.sql"), String))
                isempty(strip(stmt)) || SQLite.execute(db, stmt)
            end
            SQLite.execute(db, "UPDATE schema_meta SET schema_version = 4")
        end
    finally
        close(db)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    migrate_benchmark(isempty(ARGS) ? VBFCatalog.catalog_path() : only(ARGS))
end
