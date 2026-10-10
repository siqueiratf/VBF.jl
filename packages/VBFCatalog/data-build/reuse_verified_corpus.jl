# Explicit reuse of an independently audited, content-addressed corpus store.
# This is a build helper, not a package runtime dependency.
import SHA, TOML, SQLite, DBInterface

function _source_digest_and_records(path)
    ctx = SHA.SHA2_256_CTX()
    records = 0
    last = nothing
    open(path, "r") do io
        while !eof(io)
            bytes = read(io, 4 * 1024 * 1024)
            SHA.update!(ctx, bytes)
            records += count(==(0x0a), bytes)
            isempty(bytes) || (last = bytes[end])
        end
    end
    records += last !== nothing && last != 0x0a
    bytes2hex(SHA.digest!(ctx)), records
end

"""
Reuse a store only when current original bytes, descriptor and store match a
complete independent source-rebuild audit. This checks persisted audit evidence;
it does not rerun its mathematical verification. A fresh import remains the
default. Every failed check aborts rather than silently accepting stale data.
"""
function reuse_verified_corpus!(target, previous_catalog, name, source_path, audit_dir;
                                store_path=VBFCatalog.corpus_store_path(name))
    previous = SQLite.DB("file:" * abspath(previous_catalog) * "?mode=ro")
    info = try
        VBFCatalog.corpus_info(previous, name)
    finally
        SQLite.close(previous)
    end
    info === nothing && error("cannot reuse unregistered corpus $name")
    info.encoding == "quadratic-coeffs-v1" && info.degree == 2 && info.n == info.m == 8 &&
        info.bytes_per_member == 37 && info.modulus == VBF.conway_polynomial(8) || error("unsupported reused corpus encoding/dimension")
    raw_path = joinpath(audit_dir, "raw_" * name * ".toml")
    stored_path = joinpath(audit_dir, "stored_" * name * ".toml")
    comparison_path = joinpath(audit_dir, "comparison.toml")
    audits = [begin
        bytes = read(p)
        digest = bytes2hex(SHA.sha256(bytes))
        (TOML.parse(String(bytes)), digest)
    end for p in (raw_path, stored_path, comparison_path)]
    raw, stored, comparison = first.(audits)
    for audit in (raw, stored)
        audit["complete"] === true || error("incomplete corpus audit")
        audit["excluded_records"] == 0 || error("audit excluded corpus members")
        audit["records"] == audit["expected_records"] == audit["quadratic_apn_records"] == info.member_count ||
            error("audit corpus count mismatch")
    end
    raw["source"] == "raw_" * name && stored["source"] == "stored_" * name || error("audit source mismatch")
    raw["code_sha256"] == stored["code_sha256"] || error("audit verifiers differ")
    comparison["scope"] == "quadratic (8,8)-APN" || error("unsupported audit scope")
    comparison["provenance_complete"] === true || error("comparison provenance incomplete")
    comparison["stored_original_lut_sets_match"] === true &&
        comparison["stored_original_signature_sets_match"] === true || error("original/store comparison failed")
    evidence = comparison["sources"]["raw_" * name]
    for key in ("raw_records_absent_from_store_luts", "stored_records_absent_from_raw_luts",
                "raw_signatures_absent_from_store", "stored_signatures_absent_from_raw", "excluded_records")
        evidence[key] == 0 || error("unmatched corpus evidence: $key")
    end
    evidence["records"] == info.member_count || error("comparison corpus count mismatch")
    source_digest, source_records = _source_digest_and_records(source_path)
    source_records == info.member_count || error("original-source record count mismatch")
    source_digest == only(values(raw["input_sha256"])) || error("original-source digest differs from audit")
    digest = bytes2hex(open(SHA.sha256, store_path))
    digest == info.store_sha256 == only(values(stored["input_sha256"])) || error("stored corpus digest differs from descriptor/audit")
    # A WAL can contain rows not bound by the main database digest.
    wal = store_path * "-wal"
    isfile(wal) && filesize(wal) > 0 && error("reused store has an unbound WAL")
    store = SQLite.DB("file:" * abspath(store_path) * "?mode=ro")
    try
        [String(r[1]) for r in DBInterface.execute(store, "PRAGMA integrity_check")] == ["ok"] || error("corpus integrity check failed")
        columns = [(String(r.name), uppercase(String(r.type)), Int(r.pk), Int(r.notnull)) for r in DBInterface.execute(store, "PRAGMA table_info(members)")]
        columns == [("idx", "INTEGER", 1, 0), ("coeffs", "BLOB", 0, 1)] || error("unexpected corpus schema")
        c, lo, hi, blo, bhi = only([(Int(r.c),Int(r.lo),Int(r.hi),Int(r.blo),Int(r.bhi)) for r in
            DBInterface.execute(store, "SELECT COUNT(*) c, MIN(idx) lo, MAX(idx) hi, MIN(length(coeffs)) blo, MAX(length(coeffs)) bhi FROM members")])
        c == hi == info.member_count && lo == 1 || error("corpus indices/count mismatch")
        blo == bhi == info.bytes_per_member || error("corpus encoding size mismatch")
    finally
        SQLite.close(store)
    end
    bytes2hex(open(SHA.sha256, store_path)) == digest || error("corpus store changed during verification")
    # Preserve bibliography and original provenance; record the exact parsed evidence.
    hashes = last.(audits)
    receipt = "Verified-store reuse: original SHA256=$source_digest; raw/stored/comparison audit SHA256=$(join(hashes, ',')); verifier SHA256=$(raw["code_sha256"])."
    original_notes = String(info.notes)
    notes = occursin(receipt, original_notes) ? original_notes : original_notes * " " * receipt
    fields = (; (k=>(ismissing(getproperty(info,k)) ? nothing : getproperty(info,k))
        for k in propertynames(info) if k ∉ (:id, :notes))...,
        notes)
    VBFCatalog.register_corpus!(target; fields...)
    @info "Reused audited corpus store" name records=source_records store_sha256=digest audit_sha256=hashes
    nothing
end
