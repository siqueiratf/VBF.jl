// Tests against the production query database (all corpora, 759 MiB), and against the query
// database of an archived snapshot on Zenodo. They run only when PORTAL_FULL_DB=1, because CI
// has the small fixture database only:
//   PORTAL_FULL_DB=1 npx playwright test production.spec.mjs --project desktop
// Each test records the HTTP Range requests, the bytes and the time of its query in
// test-results/production-measurements.json.
import { test, expect } from "@playwright/test";
import fs from "node:fs";

test.skip(process.env.PORTAL_FULL_DB !== "1", "set PORTAL_FULL_DB=1 with a build that has the full query database");
test.describe.configure({ mode: "serial" });

// The Zenodo version of 2026-11-18 (snapshot 105b532b579d…): its query database over HTTP Range.
const HISTORICAL = { doi: "10.5281/zenodo.24327622", url: "https://zenodo.org/api/records/24327622/files/query.sqlite/content" };
const measurements = [];
test.afterAll(() => {
  fs.mkdirSync("test-results", { recursive: true });
  fs.writeFileSync("test-results/production-measurements.json", JSON.stringify(measurements, null, 2));
});

/** Run `act` with a cold cache and count the reads of the query database. */
async function measure(browser, name, path, act, { route } = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();
  if (route) await route(page);
  const reads = [];
  page.on("response", async (r) => {
    if (!/query\.sqlite/.test(r.url())) return;
    const range = r.request().headers().range || "";
    // A HEAD request (the file size) transfers no body: count its request, not its length.
    const head = r.request().method() === "HEAD";
    reads.push({ status: r.status(), range, head, bytes: head ? 0 : Number(r.headers()["content-length"] || 0) });
  });
  const t0 = Date.now();
  await page.goto(path);
  const result = await act(page);
  const ms = Date.now() - t0;
  const m = { name, ms, requests: reads.length, ranged: reads.filter((x) => x.status === 206).length,
    head: reads.filter((x) => x.head).length,
    bytes: reads.reduce((a, x) => a + x.bytes, 0), ...result };
  measurements.push(m);
  console.log(JSON.stringify(m));
  await context.close();
  return m;
}

const entry = async (page, idx) => {
  const view = page.locator("#member-view");
  await expect(view.locator("h3")).toHaveText(`Entry ${idx.toLocaleString("en-US")}`, { timeout: 60_000 });
  return { key: await view.locator("tr", { hasText: "Function key" }).locator("button.copy").getAttribute("data-command") };
};

test.beforeEach(({}, info) => test.skip(info.project.name !== "desktop", "measured once, at desktop width"));

for (const idx of [1, 1234567, 3775599]) {
  test(`current snapshot: entry ${idx} of beierle2025_n8`, async ({ browser }) => {
    const m = await measure(browser, `entry ${idx}`, `catalog/corpora/beierle2025_n8/?idx=${idx}`, (p) => entry(p, idx));
    expect(m.key).toMatch(/^8-8-[0-9a-f]{64}$/);
    expect(m.bytes, "bytes for one entry").toBeLessThan(2 * 1024 * 1024);
    expect(m.ms, "time for one entry").toBeLessThan(15_000);
  });
}

test("current snapshot: the last page of the largest corpus", async ({ browser }) => {
  const m = await measure(browser, "last page", "catalog/corpora/beierle2025_n8/?page=151024", async (p) => {
    const rows = p.locator("#member-view table.members tbody tr");
    await expect(rows.last().locator("td").first()).toHaveText("3,775,599", { timeout: 60_000 });
    return { rows: await rows.count() };
  });
  expect(m.rows).toBe(24);
  expect(m.bytes).toBeLessThan(2 * 1024 * 1024);
});

test("current snapshot: search by function key over all corpora", async ({ browser }) => {
  // reprs8_0 (sboxU) is entry 1 of edelpott2009_n8 and of yuwangli2014_qam_n8.
  const key = "8-8-f723b6e13a85a8c79c721ee8361b7b574ec3dbaa9da9e91048bf2ec25215374e";
  const m = await measure(browser, "search by key", `catalog/corpora/yuwangli2014_qam_n8/?key=${key}`, async (p) => {
    const out = p.locator("#member-view .member-result");
    await expect(out).toContainText("in all corpora", { timeout: 60_000 });
    return { text: (await out.locator("p").first().textContent()).replace(/\s+/g, " ").trim() };
  });
  expect(m.text).toMatch(/^1 entry of this corpus with this lookup table \(2 in all corpora\)/);
});

test("current snapshot: search by signature, 2,000+ entries", async ({ browser }) => {
  const sigma = "31245805669f3ae96ad40132ee45542bcfb1ecebf610a01db1e1651771d80405";
  const m = await measure(browser, "search by signature", `catalog/corpora/simonberg_gf4_n8/?sigma=${sigma}`, async (p) => {
    const out = p.locator("#member-view .member-result");
    await expect(out).toContainText("in all corpora", { timeout: 60_000 });
    return { text: (await out.locator("p").first().textContent()).replace(/\s+/g, " ").trim(),
      rows: await out.locator("table.members tbody tr").count() };
  });
  expect(m.rows).toBe(25);
  expect(m.text).toContain("2,066 in all corpora");
});

test("historical snapshot: the same entry from the Zenodo query database", async ({ browser }) => {
  const idx = 123456;
  const current = await measure(browser, `entry ${idx} (current)`, `catalog/corpora/beierle2025_n8/?idx=${idx}`, (p) => entry(p, idx));
  // The page of the corpus reads the archived database instead of the one of this site.
  const route = (page) => page.route(/catalog\/corpora\/beierle2025_n8\/(\?.*)?$/, async (r) => {
    const response = await r.fetch();
    const html = (await response.text()).replace(/data-db="[^"]*"/, `data-db="${HISTORICAL.url}"`);
    await r.fulfill({ response, body: html });
  });
  const old = await measure(browser, `entry ${idx} (historical, Zenodo ${HISTORICAL.doi})`,
    `catalog/corpora/beierle2025_n8/?idx=${idx}`, (p) => entry(p, idx), { route });
  expect(old.ranged).toBeGreaterThan(0);
  expect(old.key, "the corpus is unchanged between the two snapshots").toBe(current.key);
  expect(old.ms).toBeLessThan(90_000);
});
