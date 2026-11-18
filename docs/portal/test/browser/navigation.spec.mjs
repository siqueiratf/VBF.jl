// Navigation: the main sections, direct loads of nested URLs, breadcrumbs, the mobile menu
// (keyboard and touch) and the redirects of the previous site.
import { test, expect } from "@playwright/test";
import { open, expectNoOverflow } from "./helpers.mjs";

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
