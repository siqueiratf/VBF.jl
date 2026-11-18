// Reproductions: the listing (contents and search), the publication page (metadata, claim
// anchors and details, evidence, commands, copy buttons, mathematics, Library links).
import { test, expect } from "@playwright/test";
import { open } from "./helpers.mjs";

test("the contents give the publications of each year", async ({ page }) => {
  await open(page, "reproductions/");
  const total = Number((await page.locator(".page-content p").first().textContent()).match(/^(\d+) publications/)[1]);
  const counts = await page.locator("ul.contents li").allTextContents();
  const sum = counts.map((t) => Number(t.match(/: (\d+) publication/)[1])).reduce((a, b) => a + b, 0);
  expect(sum).toBe(total);
  expect(await page.locator("ol.publications > li").count()).toBe(total);
});

test("the search keeps the publications that match every word", async ({ page }) => {
  await open(page, "reproductions/");
  await page.locator("#publication-search").fill("edel pott 2009");
  const shown = page.locator("ol.publications > li:visible");
  await expect(shown).toHaveCount(1);
  await expect(shown).toContainText("A New Almost Perfect Nonlinear Function Which Is Not Quadratic");
  await page.locator("#publication-search").fill("");
  expect(await page.locator("ol.publications > li:visible").count()).toBeGreaterThan(1);
});

test("the publication page gives the reference and its links", async ({ page }) => {
  await open(page, "reproductions/200900-edel-switching/");
  await expect(page.locator("h1")).toHaveText("A New Almost Perfect Nonlinear Function Which Is Not Quadratic");
  await expect(page.locator(".authors")).toHaveText("Y. Edel and A. Pott");
  await expect(page.locator(".links a[href='https://doi.org/10.3934/amc.2009.3.59']", { hasText: "10.3934/amc.2009.3.59" })).toBeVisible();
  await expect(page.locator(".links a.tag", { hasText: "Paper" })).toBeVisible();
  const bibtex = page.locator("details.bibtex");
  await bibtex.locator("summary").click();
  await expect(bibtex.locator("pre")).toContainText("@article{Edel_200900");
});

test("a claim anchor targets its row, and the details give the evidence", async ({ page }) => {
  await open(page, "reproductions/200900-edel-switching/#corollary8");
  await expect(page.locator("#corollary8")).toBeInViewport();
  const details = page.locator("#corollary8 + tr details.claim-details");
  await details.locator("summary").click();
  const evidence = details.locator("table.evidence");
  await expect(evidence.locator("tr", { hasText: "Outcome" })).toContainText("passed");
  await expect(evidence.locator("tr", { hasText: "Command" })).toContainText("bin/vbfrepro run 200900-edel-switching --target theorem7");
  await expect(evidence.locator("tr", { hasText: "Compatibility" })).toContainText(/Current|Historical/);
});

test("each target has its own command and copy button", async ({ page, context }, info) => {
  test.skip(info.project.name === "mobile", "the clipboard check runs once");
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  await open(page, "reproductions/202508-beierle-millions/");
  const cmds = page.locator("#table4_1 .cmd");
  await expect(cmds).toHaveCount(2);
  await expect(cmds.locator("code")).toHaveText(["paper_counts", "table4_1"]);
  const button = cmds.nth(1).locator("button.copy");
  const command = await button.getAttribute("data-command");
  expect(command).toBe("bin/vbfrepro run 202508-beierle-millions --target table4_1");
  await button.click();
  await expect(cmds.nth(1).locator(".copy-note")).toHaveText(/Copied/);
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(command);
});

test("mathematics is rendered with KaTeX", async ({ page }) => {
  await open(page, "reproductions/202508-beierle-millions/");
  await expect(page.locator("#table4_1 .katex").first()).toBeVisible();
  await expect(page.locator("#table4_1")).not.toContainText("$P_k$");
});

test("the Library links of a claim lead to their docstrings", async ({ page }) => {
  await open(page, "reproductions/200900-edel-switching/");
  const details = page.locator("#corollary8 + tr details.claim-details");
  await details.locator("summary").click();
  const link = details.locator("dd a", { hasText: "delta_rank" });
  const href = await link.getAttribute("href");
  await link.click();
  const id = decodeURIComponent(href.split("#")[1]);
  await expect(page.locator(`[id="${id}"]`)).toBeAttached();
});

test("the associated data link to the corpus page", async ({ page }) => {
  await open(page, "reproductions/200900-edel-switching/");
  await page.locator("#data + ul a").first().click();
  await expect(page.locator("h1")).toHaveText("Quadratic APN functions of Edel and Pott (2009)");
});
