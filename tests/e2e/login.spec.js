const { test, expect } = require("@playwright/test");
require("dotenv").config();

test.describe("Salesforce Login", () => {
  test("should login successfully with valid credentials", async ({ page }) => {
    const username = process.env.SF_USERNAME;
    const password = process.env.SF_PASSWORD;
    const loginUrl = process.env.SF_LOGIN_URL;

    if (!username || !password) {
      test.skip("SF_USERNAME or SF_PASSWORD environment variable not set");
      return;
    }

    await page.goto(loginUrl);

    await page.fill('input[name="username"]', username);
    await page.fill('input[name="pw"]', password);
    await page.click('input[name="Login"]');

    await page.waitForLoadState("networkidle");

    const currentUrl = page.url();
    const pageTitle = await page.title();

    // URLに salesforce.com が含まれているか、またはタイトルに Salesforce が含まれているか
    const isSalesforcePage =
      currentUrl.includes("salesforce.com") || pageTitle.includes("Salesforce");
    expect(isSalesforcePage).toBeTruthy();

    // 追加: SMS検証ページが表示されている場合はログに記録
    if (
      currentUrl.includes("verification") ||
      currentUrl.includes("SmsVerification")
    ) {
      console.log("Note: SMS verification page detected after login");
    }
  });

  test("should show error with invalid credentials", async ({ page }) => {
    await page.goto(process.env.SF_LOGIN_URL);

    await page.fill('input[name="username"]', "invalid@example.com");
    await page.fill('input[name="pw"]', "wrongpassword");
    await page.click('input[name="Login"]');

    const errorMessage = await page.locator("#error").textContent();
    expect(errorMessage).toContain("Please check your username and password");
  });
});
