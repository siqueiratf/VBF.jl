// Run the catalog PoC in headless Chromium and write results.json.
//
//   node measure.mjs DATA_DIR [profile ...]     profiles: local remote
//
// For each profile, the static server starts with that latency and bandwidth; each
// run uses a new browser context (cold cache) and runs every query twice (cold, warm).
import { chromium } from "playwright";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const [data, ...wanted] = process.argv.slice(2);
const profiles = { local: [0, 0], remote: [60, 2_500_000] };   // latency ms, bytes/s
const expected = Object.fromEntries(fs.readFileSync(path.join(data, "expected.toml"), "utf8")
  .split("\n").filter((l) => l.includes("=")).map((l) => {
    const [k, v] = l.split(" = "); return [k.trim(), v.trim().replace(/"/g, "")];
  }));
const root = fs.mkdtempSync("/tmp/vbf-poc-");
for (const f of fs.readdirSync("public/js")) fs.cpSync(`public/js/${f}`, `${root}/js/${f}`);
for (const f of fs.readdirSync("public").filter((f) => f.endsWith(".html"))) fs.cpSync(`public/${f}`, `${root}/${f}`);
for (const f of fs.readdirSync(data)) fs.symlinkSync(path.resolve(data, f), `${root}/${f}`);

const B = "(SELECT id FROM corpora WHERE name = 'beierle2025_n8')";
const queryDb = [
  { id: "Q1 member by (corpus, idx)", sql: `SELECT idx, hex(coeffs), hex(lut_sha256), hex(sigma) FROM members WHERE corpus_id = ${B} AND idx = ${expected.member_idx}` },
  { id: "Q2 page of 50 members", sql: `SELECT idx, hex(lut_sha256) FROM members WHERE corpus_id = ${B} AND idx > 2000000 ORDER BY idx LIMIT 50` },
  { id: "Q4 corpora of a function", sql: `SELECT c.name, m.idx FROM members m JOIN corpora c ON c.id = m.corpus_id WHERE m.lut_sha256 = x'${expected.function_lut}'` },
  { id: "Q4b function by member hash", sql: `SELECT c.name, m.idx FROM members m JOIN corpora c ON c.id = m.corpus_id WHERE m.lut_sha256 = x'${expected.member_lut}'` },
  { id: "Q5 count with an invariant key", sql: `SELECT count(*) AS k FROM members WHERE sigma = x'${expected.sigma}'` },
  { id: "Q5b members with an invariant key", sql: `SELECT corpus_id, idx FROM members WHERE sigma = x'${expected.sigma}' LIMIT 50` },
];
const heavy = [
  { id: "Q6 count of a whole corpus", sql: `SELECT count(*) AS k FROM members WHERE corpus_id = ${B}` },
];
const catalogDb = [
  { id: "Q3 filtered functions + bibliography", sql: "SELECT f.canonical_name, f.algebraic_degree, f.linearity, b.year, b.doi FROM functions f LEFT JOIN bibliography b ON b.bib_key = f.bib_key WHERE f.n = 8 AND f.is_apn = 1 AND f.family = 'known-family' ORDER BY f.canonical_name" },
];
const rawMembers = [
  { id: "Q1 raw member by (corpus, idx)", sql: `SELECT idx, hex(coeffs) FROM corpus_members WHERE corpus = 'beierle2025_n8' AND idx = ${expected.member_idx}` },
  { id: "Q2 raw page of 50", sql: "SELECT idx, hex(coeffs) FROM corpus_members WHERE corpus = 'beierle2025_n8' AND idx > 2000000 ORDER BY idx LIMIT 50" },
];

const runs = [];
for (const lib of ["httpvfs", "wasmhttp"]) {
  for (const p of [1024, 4096]) {
    runs.push({ lib, db: `query_full_p${p}.sqlite`, pageSize: p, queries: queryDb });
    runs.push({ lib, db: `catalog_p${p}.sqlite`, pageSize: p, queries: catalogDb });
    runs.push({ lib, db: `members_p${p}.sqlite`, pageSize: p, queries: rawMembers });
  }
  runs.push({ lib, db: "query_full_p1024.sqlite", pageSize: 1024, queries: heavy, timeout: 120000 });
}
runs.push({ lib: "binary", db: "members_beierle2025_n8.bin", width: 37, indices: [Number(expected.member_idx), 1, 3775599] });

function rssOf(pid) {
  try { return Number(/VmRSS:\s+(\d+)/.exec(fs.readFileSync(`/proc/${pid}/status`, "utf8"))[1]) * 1024; }
  catch { return null; }
}

const only = process.env.POC_ONLY ? new RegExp(process.env.POC_ONLY) : null;
const selected = runs.filter((r) => !only || only.test(`${r.lib} ${r.db}`));
const results = [];
for (const name of wanted.length ? wanted : Object.keys(profiles)) {
  const [latency, rate] = profiles[name];
  const server = spawn("node", ["server.mjs", "8411", root, String(latency), String(rate)], { stdio: "ignore" });
  await new Promise((r) => setTimeout(r, 500));
  const browser = await chromium.launch({ channel: process.env.POC_BROWSER_CHANNEL || "chrome" });
  for (const run of selected) {
    const context = await browser.newContext();
    const page = await context.newPage();
    const cdp = await context.newCDPSession(page);
    await page.goto(`http://127.0.0.1:8411/${run.lib}.html`);
    await page.waitForFunction(() => typeof window.runPoC === "function");
    const t0 = Date.now();
    let rows, error;
    try {
      rows = await Promise.race([
        page.evaluate((cfg) => window.runPoC(cfg), { url: `./${run.db}`, ...run }),
        new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), run.timeout || 300000)),
      ]);
    } catch (e) { error = String(e); }
    const procs = (await browser.newBrowserCDPSession().then((s) => s.send("SystemInfo.getProcessInfo"))).processInfo;
    const renderer = procs.filter((p) => p.type === "renderer").map((p) => rssOf(p.id)).filter(Boolean);
    const heap = (await cdp.send("Performance.enable"), await cdp.send("Performance.getMetrics")).metrics
      .find((m) => m.name === "JSHeapUsedSize").value;
    results.push({ profile: name, lib: run.lib, db: run.db, pageSize: run.pageSize, wall_ms: Date.now() - t0,
      renderer_rss_bytes: Math.max(...renderer), page_js_heap_bytes: heap, error, rows });
    console.log(name, run.lib, run.db, error || `${rows.length} measurements`);
    await context.close();
  }
  await browser.close();
  server.kill();
}
fs.writeFileSync(path.join(data, "results.json"), JSON.stringify(results, null, 1));
fs.rmSync(root, { recursive: true });
