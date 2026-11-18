// Browser tests of the built portal (docs/portal/build), served under /VBF.jl/ as on
// GitHub Pages. Build the portal first:  julia --project=docs/portal docs/portal/build.jl
//   npm ci && npx playwright install chromium && npx playwright test
import { defineConfig } from "@playwright/test";

const port = process.env.PORTAL_PORT || "8431";
export default defineConfig({
  testDir: ".",
  testMatch: /.*\.spec\.mjs/,
  timeout: 60_000,
  fullyParallel: true,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["list"], ["html", { open: "never", outputFolder: "report" }]] : "list",
  use: { baseURL: `http://127.0.0.1:${port}/VBF.jl/`, trace: "retain-on-failure" },
  projects: [
    { name: "desktop", use: { browserName: "chromium", viewport: { width: 1280, height: 900 } } },
    { name: "mobile", use: { browserName: "chromium", viewport: { width: 390, height: 844 }, hasTouch: true } },
  ],
  webServer: {
    command: `node ../../review/serve.mjs ${port}`,
    url: `http://127.0.0.1:${port}/VBF.jl/`,
    reuseExistingServer: !process.env.CI,
  },
});
