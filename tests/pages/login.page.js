class LoginPage {
  constructor(page) {
    this.page = page;
    this.usernameInput = page.locator('input[name="username"]');
    this.passwordInput = page.locator('input[name="pw"]');
    this.loginButton = page.locator('input[name="Login"]');
    this.errorMessage = page.locator("#error");
  }

  async goto(loginUrl) {
    await this.page.goto(loginUrl);
  }

  async login(username, password) {
    await this.usernameInput.fill(username);
    await this.passwordInput.fill(password);
    await this.loginButton.click();
  }

  async loginWithEnv() {
    const username = process.env.SF_USERNAME;
    const password = process.env.SF_PASSWORD;

    if (!username || !password) {
      throw new Error(
        "SF_USERNAME or SF_PASSWORD environment variable not set"
      );
    }

    return this.login(username, password);
  }

  async getErrorMessage() {
    return await this.errorMessage.textContent();
  }

  async waitForNavigation() {
    await this.page.waitForLoadState("networkidle");
  }
}

module.exports = LoginPage;
