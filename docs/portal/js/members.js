// Corpus member view. The page gives data-db (the query database of its snapshot), data-corpus,
// data-digest (the full digest of the corpus snapshot) and data-count. Every view has a URL:
//   ?page=P                       a page of 25 members in index order
//   ?digest=D&idx=I               one member (the digest names the member order it means)
//   ?key=K                        members with a function key or LUT SHA-256 (or a prefix of 16+ hex)
//   ?sigma=S                      members with a signature (or a prefix of 16+ hex)
// Each query uses an index of the database (see docs/portal/src/querydb.jl), so a browser
// reads a few pages of the file over HTTP Range requests, never the whole file.
import { createSQLiteThread, createHttpBackend } from "sqlite-wasm-http";

const PAGE = 25;
const view = document.getElementById("member-view");
if (view) main();

function main() {
  const form = view.querySelector("form");
  const out = view.querySelector(".member-result");
  const { db: dbUrl, corpus, digest, root } = view.dataset;
  const count = Number(view.dataset.count);
  const pages = Math.ceil(count / PAGE);
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const fmt = (n) => Number(n).toLocaleString("en-US");
  const copy = (text, what) => `<button type="button" class="copy" data-command="${esc(text)}" title="${esc(text)}"
    aria-label="Copy ${esc(what)}: ${esc(text)}"><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><rect x="5" y="5"
    width="9" height="9" rx="1" fill="none" stroke="currentColor" stroke-width="1.3"/><path d="M3 11V3a1 1 0 0 1 1-1h7" fill="none"
    stroke="currentColor" stroke-width="1.3"/></svg></button>`;
  const short = (h, what) => `<code class="hash" title="${esc(h)}">${esc(h.slice(0, 12))}…</code>${copy(h, what)}`;

  let db = null, corpusId = null;
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
  const cid = async () => corpusId ??= (await query("SELECT id FROM corpora WHERE name = $c", { $c: corpus }))[0].id;

  // A hex value (full or a prefix of 16+ digits) as a BLOB range: [lo, hi]. The literals are
  // built only from checked hex digits.
  const range = (h) => {
    if (!/^[0-9a-f]{16,64}$/.test(h)) return null;
    return [`x'${h.padEnd(64, "0")}'`, `x'${h.padEnd(64, "f")}'`];
  };

  const href = (params) => "?" + new URLSearchParams(params).toString();
  const link = (params, text, rel = "") => `<a href="${href(params)}" data-nav${rel ? ` rel="${rel}"` : ""}>${text}</a>`;
  const memberLink = (i) => link({ digest, idx: i }, fmt(i));
  const rowsTable = (rows) => `<div class="table-wrap"><table class="members"><thead><tr><th scope="col">Index</th>
    <th scope="col">LUT SHA-256</th><th scope="col">Signature</th></tr></thead><tbody>${rows.map((r) =>
    `<tr><td>${memberLink(r.idx)}</td><td><code class="hash" title="${esc(r.lut)}">${esc(r.lut.slice(0, 16))}…</code></td>
    <td>${r.sigma ? `<code class="hash" title="${esc(r.sigma)}">${esc(r.sigma.slice(0, 16))}…</code>` : "–"}</td></tr>`).join("")}
    </tbody></table></div>`;
  const pager = (p) => `<nav class="pager" aria-label="Pages of members">
    ${p > 1 ? link({ page: 1 }, "First") + " " + link({ page: p - 1 }, "Previous", "prev") : ""}
    <span>Page ${fmt(p)} of ${fmt(pages)}</span>
    ${p < pages ? link({ page: p + 1 }, "Next", "next") + " " + link({ page: pages }, "Last") : ""}</nav>`;
  const COLS = "idx, lower(hex(lut_sha256)) AS lut, lower(hex(sigma)) AS sigma";

  const showPage = async (p) => {
    p = Math.min(Math.max(1, p), pages);
    const rows = await query(`SELECT ${COLS} FROM members WHERE corpus_id = $c AND idx BETWEEN $a AND $b ORDER BY idx`,
      { $c: await cid(), $a: (p - 1) * PAGE + 1, $b: p * PAGE });
    out.innerHTML = `<p>Members ${fmt((p - 1) * PAGE + 1)}–${fmt(Math.min(p * PAGE, count))} of ${fmt(count)}.</p>
      ${pager(p)}${rowsTable(rows)}${pager(p)}`;
  };

  const showMember = async (idx) => {
    const m = await query(`SELECT ${COLS}, hex(coeffs) AS coeffs FROM members WHERE corpus_id = $c AND idx = $i`,
      { $c: await cid(), $i: idx });
    if (!m.length) { out.innerHTML = `<p>No member ${fmt(idx)} in this corpus (1 to ${fmt(count)}).</p>`; return; }
    const r = m[0];
    const meta = (await query("SELECT n, m FROM corpora WHERE id = $c", { $c: await cid() }))[0];
    const key = `${meta.n}-${meta.m}-${r.lut}`;
    const [lo, hi] = range(r.lut);
    const curated = await query(`SELECT canonical_name FROM functions WHERE lut_sha256 BETWEEN ${lo} AND ${hi}`);
    let same = 0;
    if (r.sigma) {
      const [slo, shi] = range(r.sigma);
      same = (await query(`SELECT count(*) AS k FROM members WHERE sigma BETWEEN ${slo} AND ${shi}`))[0].k;
    }
    const page = Math.ceil(idx / PAGE);
    const julia = `corpus_function(load_catalog(), "${corpus}", ${idx})`;
    out.innerHTML = `<nav class="pager" aria-label="Neighbour members">
        ${idx > 1 ? link({ digest, idx: idx - 1 }, "Previous member", "prev") : ""}
        ${link({ page }, `Page ${fmt(page)} of the list`)}
        ${idx < count ? link({ digest, idx: idx + 1 }, "Next member", "next") : ""}</nav>
      <h3>Member ${fmt(idx)}</h3>
      <table class="properties">
      <tr><th scope="row">Function key</th><td>${short(key, "the function key")}${curated.length ?
        ` This is the curated function <a href="${root}catalog/functions/${esc(key)}/">${esc(curated[0].canonical_name || key)}</a>.` : ""}</td></tr>
      <tr><th scope="row">Signature</th><td>${r.sigma ? short(r.sigma, "the signature") +
        ` ${link({ sigma: r.sigma }, `${fmt(same)} ${same === 1 ? "member has" : "members have"} it`)}` : "not in the index"}</td></tr>
      <tr><th scope="row">Permanent link</th><td>${short(location.origin + location.pathname + href({ digest, idx }), "the permanent link")}</td></tr>
      </table>
      <details><summary>Stored coefficients (hex)</summary><pre>${esc(r.coeffs.toLowerCase())}</pre></details>
      <p>In Julia: <code>${esc(julia)}</code> ${copy(julia, "the Julia command")}</p>
      <p class="note">An equal signature is an invariant match, not a proof of equivalence.</p>`;
  };

  const showSearch = async (column, value) => {
    let h = value.toLowerCase().trim();
    const k = h.match(/^(\d+)-(\d+)-([0-9a-f]+)$/);
    if (column === "lut_sha256" && k) h = k[3];
    const r = range(h);
    if (!r) { out.innerHTML = "<p>Give 16 to 64 hex digits, or a function key such as <code>8-8-…</code>.</p>"; return; }
    const what = column === "sigma" ? "signature" : "lookup table";
    const all = await query(`SELECT count(*) AS k FROM members WHERE ${column} BETWEEN ${r[0]} AND ${r[1]}`);
    const rows = await query(`SELECT ${COLS} FROM members WHERE ${column} BETWEEN ${r[0]} AND ${r[1]} AND corpus_id = $c
      ORDER BY idx LIMIT ${PAGE}`, { $c: await cid() });
    out.innerHTML = `<p>${fmt(rows.length)}${rows.length === PAGE ? "+" : ""} ${rows.length === 1 ? "member" : "members"} of this corpus
      with this ${what} (${fmt(all[0].k)} in all corpora). ${link({ page: 1 }, "Back to the list")}</p>
      ${rows.length ? rowsTable(rows) : ""}`;
  };

  const render = async () => {
    const p = new URLSearchParams(location.search);
    const asked = p.get("digest");
    out.textContent = "Reading…";
    try {
      if (p.has("idx")) {
        form.by.value = "idx"; form.value.value = p.get("idx");
        if (asked && asked !== digest) {
          out.innerHTML = `<p>This link names corpus digest <code>${esc(asked)}</code>. This site holds digest
            <code>${esc(digest)}</code>, so the index can name another member here. Use the Zenodo version of that
            snapshot (see <a href="${root}catalog/#snapshots">Versions</a>).</p>`;
          return;
        }
        const i = Number(p.get("idx"));
        if (!Number.isInteger(i) || i < 1) { out.textContent = "Give a member index (1, 2, …)."; return; }
        await showMember(i);
      } else if (p.has("key")) {
        form.by.value = "key"; form.value.value = p.get("key");
        await showSearch("lut_sha256", p.get("key"));
      } else if (p.has("sigma")) {
        form.by.value = "sigma"; form.value.value = p.get("sigma");
        await showSearch("sigma", p.get("sigma"));
      } else {
        await showPage(Number(p.get("page")) || 1);
      }
    } catch (e) {
      out.textContent = `The query failed: ${e}`;
    }
  };

  const go = (search) => { history.pushState(null, "", search || location.pathname); render(); };
  view.addEventListener("click", (e) => {
    const a = e.target.closest("a[data-nav]");
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey) return;
    e.preventDefault();
    go(a.getAttribute("href"));
  });
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const v = form.value.value.trim();
    const by = form.by.value;
    go(href(by === "idx" ? { digest, idx: v.replace(/[,\s]/g, "") } : { [by]: v }));
  });
  window.addEventListener("popstate", render);
  render();
}
