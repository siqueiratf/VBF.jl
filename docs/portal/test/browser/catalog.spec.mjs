// Catalog: the home search, the function list (filters, sort, pages, state in the URL), the
// function pages and the corpus member view (SQLite over HTTP Range).
import { test, expect } from "@playwright/test";
import { open, hasQueryDb } from "./helpers.mjs";

const count = async (page) => (await page.locator("#function-count").textContent()).trim();
const visibleNames = (page) => page.locator("#function-table tbody tr:visible td:first-child").allTextContents();

test("the catalog home search opens the filtered function list", async ({ page }) => {
  await open(page, "catalog/");
  await page.locator("form.search-main input[name=q]").fill("gold");
  await page.locator("form.search-main select[name=n]").selectOption("10");
  await page.locator("form.search-main button[type=submit]").click();
  await expect(page).toHaveURL(/catalog\/functions\/\?q=gold&n=10/);
  const names = await visibleNames(page);
  expect(names.length).toBeGreaterThan(0);
  for (const n of names) expect(n.toLowerCase()).toContain("gold");
});

test("the corpus table names each corpus and links to its page", async ({ page }) => {
  await open(page, "catalog/");
  const rows = page.locator("table.corpora tbody tr");
  expect(await rows.count()).toBeGreaterThan(5);
  await rows.first().locator("a").first().click();
  await expect(page.locator("h2", { hasText: "Original dataset" })).toBeVisible();
});

test("the versions table marks the snapshot of this site", async ({ page }) => {
  await open(page, "catalog/#snapshots");
  await expect(page.locator("table.versions tbody tr").first()).toContainText(/this site|This build/);
  const json = await (await page.request.get("catalog/snapshots.json")).json();
  expect(json.current).toMatch(/^[0-9a-f]{64}$/);
});

test("filters change the list and the URL; a reload keeps them", async ({ page }) => {
  await open(page, "catalog/functions/");
  const all = await count(page);
  await page.locator("#function-filters select[name=n]").selectOption("8");
  await page.locator("#function-filters select[name=is_apn]").selectOption("1");
  await expect(page).toHaveURL(/n=8/);
  await expect(page).toHaveURL(/is_apn=1/);
  const filtered = await count(page);
  expect(filtered).not.toBe(all);
  for (const n of await page.locator("#function-table tbody tr:visible td:nth-child(2)").allTextContents()) expect(n.trim()).toBe("8");
  await page.reload({ waitUntil: "networkidle" });
  await expect(page.locator("#function-filters select[name=n]")).toHaveValue("8");
  expect(await count(page)).toBe(filtered);
  await page.locator("#function-filters button.reset").click();
  await expect(page.locator("#function-count")).toHaveText(all);
});

test("a column title sorts the list, and a second selection reverses it", async ({ page }) => {
  await open(page, "catalog/functions/?n=8&is_apn=1");
  const th = page.locator("#function-table th[data-col=name]");
  await th.locator("button").click();
  await expect(th).toHaveAttribute("aria-sort", "ascending");
  await expect(page).toHaveURL(/sort=name&dir=asc/);
  // The script orders every row of the table (the hidden rows of the other pages too).
  const filtered = await page.locator("#function-count").textContent();
  const rows = page.locator("#function-table tbody tr");
  const order = async () => (await rows.evaluateAll((trs) => trs.filter((tr) => tr.dataset.n === "8" && tr.dataset.is_apn === "1")
    .map((tr) => tr.cells[0].textContent)));
  const up = await order();
  const sorted = [...up].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase(), "en", { numeric: true }));
  expect(up).toEqual(sorted);
  expect((await visibleNames(page))[0]).toBe(up[0]);
  await th.locator("button").click();
  await expect(th).toHaveAttribute("aria-sort", "descending");
  expect((await visibleNames(page))[0]).toBe(up[up.length - 1]);
  expect(await page.locator("#function-count").textContent()).toBe(filtered);
});

test("the list has pages of 50 functions", async ({ page }) => {
  await open(page, "catalog/functions/");
  expect((await visibleNames(page)).length).toBe(50);
  await page.locator("#function-pager a", { hasText: "Next" }).click();
  await expect(page).toHaveURL(/page=2/);
  await expect(page.locator("#function-count")).toContainText("Functions 51–100");
});

test("a function page has its sections in the agreed order", async ({ page }) => {
  await open(page, "catalog/names/n10_Gold_x3/");
  await expect(page).toHaveURL(/catalog\/functions\/10-10-[0-9a-f]{64}\/$/);
  await expect(page.locator("h1")).toHaveText("n10_Gold_x3");
  expect(await page.locator(".page-content h2").allTextContents()).toEqual(["Properties", "Representations", "Provenance",
    "Corpora", "Equivalence relations", "Local commands", "Technical identifiers"]);
  await expect(page.locator(".lead .katex").first()).toBeVisible();
});

test("a property name links to the Library function that computes it", async ({ page }) => {
  await open(page, "catalog/names/n10_Gold_x3/");
  const link = page.locator("table.properties th a", { hasText: "Differential uniformity" });
  await link.click();
  await expect(page).toHaveURL(/api\/spectra\/#VBF\.differential_uniformity/);
});

test("the Julia commands load the function by its content key", async ({ page }) => {
  await open(page, "catalog/names/n10_Gold_x3/");
  const key = page.url().match(/10-10-([0-9a-f]{64})/)[1];
  await expect(page.locator("pre", { hasText: "find_function" })).toContainText(`h = "${key}"`);
});

test("the member view lists, shows and searches members", async ({ page, request }) => {
  await open(page, "catalog/corpora/edelpott2009_n8/");
  test.skip(!(await hasQueryDb(page, request)), "this build has no query database");
  const view = page.locator("#member-view");
  await expect(view.locator("table.members tbody tr")).toHaveCount(22);
  await view.locator("table.members tbody tr").nth(4).locator("a").click();
  await expect(page).toHaveURL(/\?digest=[0-9a-f]{64}&idx=5$/);
  await expect(view.locator("h3")).toHaveText("Entry 5");
  await view.getByRole("link", { name: "Next entry" }).click();
  await expect(view.locator("h3")).toHaveText("Entry 6");
  await page.goBack();
  await expect(view.locator("h3")).toHaveText("Entry 5");
  // The permanent link names the full corpus digest and the index; the Julia command checks
  // the digest before it reads the index.
  const digest = await view.getAttribute("data-digest");
  const permanent = await view.locator("tr", { hasText: "Permanent link" }).locator("button.copy").getAttribute("data-command");
  expect(permanent).toBe(new URL(`?digest=${digest}&idx=5`, page.url()).href);
  expect(permanent).toMatch(/\/VBF\.jl\/catalog\/corpora\/edelpott2009_n8\/\?digest=[0-9a-f]{64}&idx=5$/);
  await expect(view.locator("pre", { hasText: "corpus_function" })).toContainText(`corpus_digest(db, "edelpott2009_n8") == "${digest}"`);
  await expect(view.locator("pre", { hasText: "corpus_function" })).toContainText(`corpus_function(db, "edelpott2009_n8", 5)`);
  const key = await view.locator("tr", { hasText: "Function key" }).locator("button.copy").getAttribute("data-command");
  await view.locator("select[name=by]").selectOption("key");
  await view.locator("input[name=value]").fill(key);
  await view.locator("button[type=submit]").click();
  await expect(view.locator("table.members tbody tr")).toHaveCount(1);
  await expect(view.locator("table.members tbody tr td").first()).toHaveText("5");
});

test("a member link with another corpus digest is not resolved", async ({ page, request }) => {
  await open(page, "catalog/corpora/edelpott2009_n8/");
  test.skip(!(await hasQueryDb(page, request)), "this build has no query database");
  await page.goto(`catalog/corpora/edelpott2009_n8/?digest=${"0".repeat(64)}&idx=5`);
  await expect(page.locator(".member-result")).toContainText("This link names corpus digest");
});

test("equal values keep the natural order of the names", async ({ page }) => {
  await open(page, "catalog/functions/?n=8&is_apn=1&sort=linearity&dir=asc&size=all");
  const rows = await page.locator("#function-table tbody tr").evaluateAll((trs) => trs.filter((tr) => !tr.hidden)
    .map((tr) => [Number(tr.dataset.linearity), tr.dataset.name]));
  for (let i = 1; i < rows.length; i++) {
    const [[l0, n0], [l1, n1]] = [rows[i - 1], rows[i]];
    expect(l0 <= l1, `linearity order at ${n1}`).toBe(true);
    if (l0 === l1) expect(n0.localeCompare(n1, "en", { numeric: true }), `${n0} before ${n1}`).toBeLessThanOrEqual(0);
  }
});
