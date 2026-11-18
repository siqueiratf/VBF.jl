// Layout and accessibility of the main pages at desktop and mobile width: no page wider than
// the window, no wide table that scrolls in its column (claims), and no serious or critical
// axe-core violation of WCAG 2.1 A and AA.
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { open, expectNoOverflow } from "./helpers.mjs";

const pages = [
  ["home", ""],
  ["reproductions", "reproductions/"],
  ["publication", "reproductions/200900-edel-switching/"],
  ["publication with details", "reproductions/202508-beierle-millions/", async (p) => p.locator("#table4_1 + tr summary").click()],
  ["catalog", "catalog/"],
  ["functions", "catalog/functions/?n=8&is_apn=1"],
  ["function", "catalog/names/reprs8_0/"],
  ["corpus", "catalog/corpora/edelpott2009_n8/"],
  ["library", "library/"],
  ["api", "api/spectra/"],
  ["references", "references/"],
  ["about", "about/"],
];

for (const [name, path, act] of pages) {
  test(`layout and accessibility: ${name}`, async ({ page }) => {
    await open(page, path);
    if (act) await act(page);
    await expectNoOverflow(page);
    const wide = await page.evaluate(() => [...document.querySelectorAll("table.claims")]
      .filter((t) => t.parentElement.scrollWidth > t.parentElement.clientWidth).length);
    expect(wide, "claims tables that scroll inside their column").toBe(0);
    const axe = new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]);
    // Documenter's own widgets (search modal, settings) are outside the portal design.
    const library = path.startsWith("api/") || path.startsWith("library/") || path.startsWith("references/");
    if (library) axe.exclude("#documenter-settings").exclude(".search-modal").disableRules(["nested-interactive"]);
    const result = await axe.analyze();
    const violations = [...result.violations];
    if (library) {
      // The one exception: a Documenter docstring <summary> holds the link of its binding
      // (nested-interactive). The rule runs on the rest of the page; library.spec.mjs checks
      // that the keyboard still opens, closes and follows these summaries.
      const nested = await new AxeBuilder({ page }).withRules(["nested-interactive"])
        .exclude("details.docstring > summary").exclude("#documenter-settings").exclude(".search-modal").analyze();
      violations.push(...nested.violations);
    }
    const serious = violations.filter((v) => ["serious", "critical"].includes(v.impact));
    expect(serious.map((v) => `${v.id} (${v.impact}): ${v.nodes.length} × ${v.nodes[0].target.join(" ")} — ${v.help}`)).toEqual([]);
  });
}
