const { defineConfig, devices } = require("@playwright/test");
require("dotenv").config();

module.exports = defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ["html", { outputFolder: "playwright-report" }],
    ["json", { outputFile: "test-results/results.json" }]
  ],
  use: {
    baseURL: process.env.SF_LOGIN_URL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    actionTimeout: 30000,
    navigationTimeout: 30000
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] }
    },
    {
      name: "webkit",
      use: { ...devices["Desktop Safari"] }
    },
    {
      name: "Mobile Chrome",
      use: { ...devices["Pixel 5"] }
    },
    {
      name: "Mobile Safari",
      use: { ...devices["iPhone 12"] }
    }
  ],
  timeout: 60000,
  expect: {
    timeout: 10000
  }
});
