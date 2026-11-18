// Screenshots of the built portal for design review (stage S5).
//   node screenshots.mjs OUT_DIR [BASE_URL]
// BASE_URL defaults to http://127.0.0.1:8430/VBF.jl/ (docs/portal/poc/server.mjs over a folder
// that links VBF.jl -> docs/portal/build).
import { chromium } from "playwright";
import fs from "node:fs";

const [out, base = "http://127.0.0.1:8430/VBF.jl/"] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const pages = [
  ["home", ""],
  ["reproductions", "reproductions/"],
  ["edel", "reproductions/200900-edel-switching/", async (p) => {
    await p.click("#corollary8 + tr summary"); }],
  ["beierle", "reproductions/202508-beierle-millions/", async (p) => {
    await p.click("#table4_1 + tr summary"); }],
  ["catalog", "catalog/"],
  ["functions", "catalog/functions/?n=8&is_apn=1&sort=linearity&dir=asc"],
  ["functions-all", "catalog/functions/"],
  ["function", "catalog/names/reprs8_0/"],
  ["function-gold", "catalog/names/n10_Gold_x3/"],
  ["corpus", "catalog/corpora/beierle2025_n8/", async (p) => {
    await p.waitForSelector(".member-result table", { timeout: 30000 }); }],
  ["corpus-member", "catalog/corpora/beierle2025_n8/?idx=123456", async (p) => {
    await p.waitForSelector(".member-result table", { timeout: 30000 }); }],
  ["corpus-small", "catalog/corpora/edelpott2009_n8/", async (p) => {
    await p.waitForSelector(".member-result table", { timeout: 30000 }); }],
];
const overflow = [];
const browser = await chromium.launch({ channel: process.env.CHANNEL || "chrome" });
for (const [vw, vh, tag] of [[1280, 900, "desktop"], [390, 844, "mobile"]]) {
  const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: 1 });
  const p = await ctx.newPage();
  for (const [name, path, act] of pages) {
    await p.goto(base + path, { waitUntil: "networkidle" });
    if (act) await act(p);
    await p.waitForTimeout(300);
    // The document must never be wider than the window (no horizontal page scroll).
    const w = await p.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    if (w[0] > w[1]) overflow.push(`${name} ${tag}: document ${w[0]}px > window ${w[1]}px`);
    // The claims table must fit its column: no scroll inside the table wrapper either.
    const t = await p.evaluate(() => [...document.querySelectorAll("table.claims")]
      .map((e) => [e.parentElement.scrollWidth, e.parentElement.clientWidth]).filter(([a, b]) => a > b));
    for (const [a, b] of t) overflow.push(`${name} ${tag}: claims table ${a}px > column ${b}px`);
    await p.screenshot({ path: `${out}/${name}-${tag}.png`, fullPage: true });
  }
  if (tag === "mobile") {
    await p.goto(base + "reproductions/", { waitUntil: "networkidle" });
    await p.click(".menu-toggle");
    await p.screenshot({ path: `${out}/menu-open-mobile.png` });
  }
  await ctx.close();
}
await browser.close();
console.log("screenshots in", out);
if (overflow.length) { console.log("HORIZONTAL OVERFLOW:\n  " + overflow.join("\n  ")); process.exit(1); }
console.log("no horizontal overflow on any page");
