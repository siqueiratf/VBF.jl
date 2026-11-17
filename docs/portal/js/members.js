// Corpus member view. The page gives data-db (the query database of its snapshot), data-corpus
// and data-digest (the full digest of the corpus snapshot). The URL keeps ?digest=&idx=, so a
// reference to a member names the member order it means.
import { createSQLiteThread, createHttpBackend } from "sqlite-wasm-http";

const view = document.getElementById("member-view");
if (view) main();

async function main() {
  const form = view.querySelector("form");
  const out = view.querySelector(".member-result");
  const { db: dbUrl, corpus, digest, root } = view.dataset;
  const params = new URLSearchParams(location.search);
  if (params.has("idx")) form.idx.value = params.get("idx");
  let db = null;
  const open = async () => {
    if (db) return db;
    const http = createHttpBackend({ maxPageSize: 4096, timeout: 30000, cacheSize: 4096 });
    db = await createSQLiteThread({ http });
    await db("open", { filename: "file:" + encodeURI(new URL(dbUrl, location.href).href), vfs: "http" });
    return db;
  };
  const query = async (sql, bind) => {
    const conn = await open();
    return new Promise((resolve, reject) => {
      const rows = [];
      conn("exec", { sql, bind, rowMode: "object", callback: (m) => (m.row ? rows.push(m.row) : resolve(rows)) }).catch(reject);
    });
  };
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const show = async () => {
    const idx = Number(form.idx.value);
    const asked = params.get("digest");
    if (asked && asked !== digest) {
      out.innerHTML = `<p>This reference names corpus digest <code>${esc(asked)}</code>, but this site holds digest
        <code>${esc(digest)}</code>. The index may name another member here. Use the archived snapshot of that digest
        (see the catalog snapshots on Zenodo).</p>`;
      return;
    }
    if (!Number.isInteger(idx) || idx < 1) { out.textContent = "Give a member index (1, 2, ...)."; return; }
    out.textContent = "Reading…";
    try {
      const m = await query(`SELECT m.idx, hex(m.coeffs) AS coeffs, lower(hex(m.lut_sha256)) AS lut, lower(hex(m.sigma)) AS sigma,
        c.n, c.m FROM members m JOIN corpora c ON c.id = m.corpus_id WHERE c.name = $c AND m.idx = $i`, { $c: corpus, $i: idx });
      if (!m.length) { out.textContent = `No member ${idx} in ${corpus}.`; return; }
      const r = m[0];
      const key = `${r.n}-${r.m}-${r.lut}`;
      const hex = (h) => { if (!/^[0-9a-f]{64}$/.test(h)) throw new Error("bad digest"); return `x'${h}'`; };
      const curated = await query(`SELECT canonical_name FROM functions WHERE lut_sha256 = ${hex(r.lut)}`);
      let same = [], count = 0;
      if (r.sigma) {
        count = (await query(`SELECT count(*) AS k FROM members WHERE sigma = ${hex(r.sigma)}`))[0].k;
        same = await query(`SELECT c.name, m.idx FROM members m JOIN corpora c ON c.id = m.corpus_id
          WHERE m.sigma = ${hex(r.sigma)} LIMIT 21`);
      }
      history.replaceState(null, "", `?digest=${digest}&idx=${idx}`);
      out.innerHTML = `<table class="properties">
        <tr><th scope="row">Member</th><td>${esc(corpus)} #${idx}</td></tr>
        <tr><th scope="row">Function key</th><td><code>${esc(key)}</code>${curated.length ?
          ` = <a href="${root}catalog/functions/${esc(key)}/">${esc(curated[0].canonical_name)}</a>` : ""}</td></tr>
        <tr><th scope="row">Signature</th><td>${r.sigma ? `<code>${esc(r.sigma)}</code>` : "not indexed"}</td></tr>
        <tr><th scope="row">Coefficients</th><td><code>${esc(r.coeffs.toLowerCase())}</code></td></tr></table>
        ${r.sigma ? `<p>${count} members share this signature. Equal signatures are an invariant match, not a proof of
          equivalence.</p><ul>${same.filter((s) => !(s.name === corpus && s.idx === idx)).slice(0, 20).map((s) =>
          `<li><a href="${root}catalog/corpora/${esc(s.name)}/?idx=${s.idx}">${esc(s.name)} #${s.idx}</a></li>`).join("")}</ul>` : ""}
        <p>In Julia: <code>corpus_function(load_catalog(), "${esc(corpus)}", ${idx})</code></p>`;
    } catch (e) {
      out.textContent = `The query failed: ${e}`;
    }
  };
  form.addEventListener("submit", (e) => { e.preventDefault(); show(); });
  if (params.has("idx")) show();
}
