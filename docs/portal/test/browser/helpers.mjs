// Shared checks of the browser tests.
import { expect } from "@playwright/test";

/** Open a page and collect the console errors and the failed requests to the site itself. */
export async function open(page, path) {
  const problems = [];
  page.on("console", (m) => { if (m.type() === "error") problems.push(`console: ${m.text()}`); });
  page.on("requestfailed", (r) => { if (r.url().includes("127.0.0.1")) problems.push(`request failed: ${r.url()}`); });
  page.on("response", (r) => { if (r.url().includes("127.0.0.1") && r.status() >= 400) problems.push(`HTTP ${r.status()}: ${r.url()}`); });
  const response = await page.goto(path, { waitUntil: "networkidle" });
  expect(response.status(), `status of ${path}`).toBeLessThan(400);
  return problems;
}

/** The document must never be wider than the window (no horizontal page scroll). */
export async function expectNoOverflow(page) {
  const [doc, win] = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
  expect(doc, "document width").toBeLessThanOrEqual(win);
}

/** True when the build has the query database of the catalog snapshot (catalog/data/<key>/). */
export async function hasQueryDb(page, request) {
  const url = await page.locator("#member-view").getAttribute("data-db");
  const r = await request.head(new URL(url, page.url()).href);
  return r.ok();
}
