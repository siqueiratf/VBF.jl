// Library: Documenter inside the portal (header, search, light theme only) and the
// cross-references between symbols, reproductions, publications and the catalog.
import { test, expect } from "@playwright/test";
import { open } from "./helpers.mjs";

test("a Library page has the portal header and footer", async ({ page }) => {
  await open(page, "api/spectra/");
  await expect(page.locator("header.site-header .site-title")).toHaveText("VBF.jl");
  await expect(page.locator("footer.site-footer")).toContainText("Documenter.jl");
  await expect(page.locator("#documenter .docs-sidebar")).toBeAttached();
});

test("the Library search finds a function", async ({ page }, info) => {
  await open(page, "api/spectra/");
  if (info.project.name === "mobile") await page.locator("#documenter-sidebar-button").click();
  await page.locator("#documenter-search-query").click();
  const input = page.locator(".documenter-search-input");
  await input.fill("differential_uniformity");
  await expect(page.locator(".search-result-link").first()).toContainText("differential_uniformity", { timeout: 20_000 });
});

test("the Library keeps the light theme with a dark system preference", async ({ browser }) => {
  const context = await browser.newContext({ colorScheme: "dark" });
  const page = await context.newPage();
  await page.goto("api/spectra/", { waitUntil: "networkidle" });
  const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  expect(bg).toBe("rgb(253, 253, 253)");
  await context.close();
});

test("a docstring names the catalog property and the claims that use it", async ({ page }) => {
  await open(page, "api/spectra/");
  const block = page.locator("details.docstring", { has: page.locator("summary[id^='VBF.algebraic_degree']") }).locator(".portal-xref");
  await expect(block).toContainText("Algebraic degree");
  const claim = block.locator("a", { hasText: "Edel and Pott (2009), Theorem 11" });
  await claim.click();
  await expect(page).toHaveURL(/reproductions\/200900-edel-switching\/#theorem11$/);
  await expect(page.locator("#theorem11")).toBeInViewport();
});

test("the References page links publications to reproductions, corpora and symbols", async ({ page }) => {
  await open(page, "references/");
  const entry = page.locator("li", { has: page.locator("div#Beierle_202200") });
  await expect(entry.locator(".portal-xref")).toContainText("beierleleanderperrin2022_n8");
  await expect(entry.locator(".portal-xref")).toContainText("Cited by");
  await expect(page.locator("li", { has: page.locator("div#Edel_200900") }).locator(".portal-xref a", { hasText: "Reproduction" })).toBeVisible();
});

test("mathematics in docstrings is rendered", async ({ page }) => {
  await open(page, "api/spectra/");
  await expect(page.locator("#documenter .katex").first()).toBeAttached();
});

test("the keyboard opens, closes and follows a docstring", async ({ page }) => {
  await open(page, "api/spectra/");
  const details = page.locator("details.docstring").first();
  const summary = details.locator("summary");
  await summary.focus();
  await expect(summary).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(details).not.toHaveAttribute("open", /.*/);
  await page.keyboard.press("Enter");
  await expect(details).toHaveAttribute("open", /.*/);
  // The binding link inside the summary is the next stop of the Tab key, and Enter follows it.
  await page.keyboard.press("Tab");
  const link = summary.locator("a.docstring-binding");
  await expect(link).toBeFocused();
  const href = await link.getAttribute("href");
  await page.keyboard.press("Enter");
  await expect.poll(() => decodeURIComponent(page.url())).toContain(decodeURIComponent(href));
});
