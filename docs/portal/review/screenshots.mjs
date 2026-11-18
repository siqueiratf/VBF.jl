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
    await p.click("#corollary8 .claim-details summary"); }],
  ["beierle", "reproductions/202508-beierle-millions/"],
  ["catalog", "catalog/"],
  ["functions", "catalog/functions/?n=8&is_apn=1&family=known-family"],
  ["function", "catalog/names/reprs8_0/"],
  ["corpus", "catalog/corpora/beierle2025_n8/?idx=123456", async (p) => {
    await p.waitForSelector(".member-result table", { timeout: 30000 }); }],
];
const browser = await chromium.launch({ channel: process.env.CHANNEL || "chrome" });
for (const [vw, vh, tag] of [[1280, 900, "desktop"], [390, 844, "mobile"]]) {
  const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: 1 });
  const p = await ctx.newPage();
  for (const [name, path, act] of pages) {
    await p.goto(base + path, { waitUntil: "networkidle" });
    if (act) await act(p);
    await p.waitForTimeout(300);
    await p.screenshot({ path: `${out}/${name}-${tag}.png`, fullPage: true });
  }
  await ctx.close();
}
await browser.close();
console.log("screenshots in", out);
