// Navigation: the main sections, direct loads of nested URLs, breadcrumbs, the mobile menu
// (keyboard and touch) and the redirects of the previous site.
import { test, expect } from "@playwright/test";
import { open, expectNoOverflow } from "./helpers.mjs";
import fs from "node:fs";

const nested = [
  "reproductions/200900-edel-switching/",
  "reproductions/202508-beierle-millions/",
  "catalog/functions/",
  "catalog/names/n10_Gold_x3/",
  "catalog/corpora/edelpott2009_n8/",
  "api/spectra/",
  "references/",
  "about/",
];

test("the home page links to the three sections", async ({ page }) => {
  const problems = await open(page, "");
  await expect(page).toHaveTitle(/VBF\.jl/);
  for (const [name, path] of [["Reproductions", "reproductions/"], ["Catalog", "catalog/"], ["Library", "library/"]]) {
    await expect(page.locator(`#site-nav a[href$="${path}"]`)).toHaveText(new RegExp(name, "i"));
  }
  expect(problems).toEqual([]);
});

for (const path of nested) {
  test(`direct load of ${path}`, async ({ page }) => {
    const problems = await open(page, path);
    await expect(page.locator("h1").first()).toBeVisible();
    await expectNoOverflow(page);
    expect(problems).toEqual([]);
  });
}

test("the current section is marked in the navigation", async ({ page }) => {
  await open(page, "catalog/functions/");
  await expect(page.locator('#site-nav a[aria-current="page"]')).toHaveText(/catalog/i);
  await open(page, "api/spectra/");
  await expect(page.locator('#site-nav a[aria-current="page"]')).toHaveText(/library/i);
});

test("breadcrumbs lead back to the section", async ({ page }) => {
  await open(page, "reproductions/200900-edel-switching/");
  const crumbs = page.locator("nav.breadcrumbs");
  await expect(crumbs.locator("a")).toHaveText(["Home", "Reproductions"]);
  await expect(crumbs.locator('[aria-current="page"]')).toContainText("Almost Perfect Nonlinear");
  await crumbs.getByRole("link", { name: "Reproductions" }).click();
  await expect(page).toHaveURL(/\/reproductions\/$/);
});

test("the mobile menu opens with the keyboard", async ({ page }, info) => {
  test.skip(info.project.name !== "mobile", "the menu button shows only at mobile width");
  await open(page, "reproductions/");
  const button = page.locator(".menu-toggle");
  const nav = page.locator("#site-nav");
  await expect(nav).toBeHidden();
  await button.focus();
  await page.keyboard.press("Enter");
  await expect(button).toHaveAttribute("aria-expanded", "true");
  await expect(nav).toBeVisible();
  await page.keyboard.press("Tab");
  await expect(page.locator("#site-nav a").first()).toBeFocused();
  await button.click();
  await expect(nav).toBeHidden();
});

test("the mobile menu also works on Library pages", async ({ page }, info) => {
  test.skip(info.project.name !== "mobile", "the menu button shows only at mobile width");
  await open(page, "api/spectra/");
  await page.locator(".site-header .menu-toggle").click();
  await expect(page.locator(".site-header #site-nav")).toBeVisible();
});

test("an address of the previous site redirects to its new page", async ({ page }) => {
  await page.goto("generated/200900-edel-switching/");
  await page.waitForURL(/reproductions\/200900-edel-switching\/$/);
  await expect(page.locator("h1")).toContainText("Almost Perfect Nonlinear");
});

test("a folder address without the final slash works", async ({ page }) => {
  await page.goto("catalog");
  await expect(page).toHaveURL(/\/catalog\/$/);
});

test("the title and the navigation keep their place in every section", async ({ page }) => {
  // The home page has a taller header band (200px, an approved design choice); every other
  // page, Library pages included, must put the title and the links at the same pixels.
  const where = async (path) => {
    await open(page, path);
    return page.evaluate(() => [".site-title", ...[...document.querySelectorAll("#site-nav a")].map((_, i) => `#site-nav a:nth-child(${i + 1})`)]
      .map((s) => { const r = document.querySelector(s).getBoundingClientRect(); return [s, Math.round(r.x), Math.round(r.y)]; }));
  };
  const first = await where("reproductions/");
  for (const path of ["catalog/functions/", "catalog/names/n10_Gold_x3/", "api/spectra/", "references/", "about/"]) {
    expect(await where(path), path).toEqual(first);
  }
});

test("a formula and the punctuation after it stay on one line", async ({ page }) => {
  await open(page, "reproductions/200900-edel-switching/");
  const glue = page.locator("#proposition2 .math-glue").last();
  await expect(glue).toHaveText(/\.$/);
  expect(await glue.evaluate((e) => getComputedStyle(e).whiteSpace)).toBe("nowrap");
});

test("every address of the previous site resolves under the base path", async ({ request }, info) => {
  test.skip(info.project.name !== "desktop", "checked once");
  const paths = fs.readFileSync("../../legacy_urls.txt", "utf8").split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
  expect(paths.length).toBeGreaterThan(10);
  for (const p of paths) {
    const r = await request.get(p);
    expect(r.status(), p).toBe(200);
    const html = await r.text();
    const target = html.match(/http-equiv="refresh" content="0; url=([^"]+)"/);
    if (target) expect((await request.get(new URL(target[1], r.url()).href)).status(), `${p} -> ${target[1]}`).toBe(200);
  }
});

test("snapshot references resolve under the base path", async ({ request }, info) => {
  test.skip(info.project.name !== "desktop", "checked once");
  const snap = await (await request.get("catalog/snapshots.json")).json();
  const head = await request.head(`catalog/data/${snap.current}/query.sqlite`);
  expect(head.status()).toBe(200);
  for (const v of snap.versions) expect(v.key).toMatch(/^[0-9a-f]{64}$/);
});
