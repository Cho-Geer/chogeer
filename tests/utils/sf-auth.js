require("dotenv").config();

class SFAuth {
  constructor(page) {
    this.page = page;
  }

  async login(username, password) {
    const loginUrl = process.env.SF_LOGIN_URL;

    await this.page.goto(loginUrl);
    await this.page.fill('input[name="username"]', username);
    await this.page.fill('input[name="pw"]', password);
    await this.page.click('input[name="Login"]');

    await this.page.waitForLoadState("networkidle");

    const currentUrl = this.page.url();
    if (currentUrl.includes("lightning")) {
      return true;
    } else {
      throw new Error("Login failed");
    }
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

  async logout() {
    await this.page.goto("/secur/logout.jsp");
    await this.page.waitForLoadState("networkidle");
  }

  async isLoggedIn() {
    const currentUrl = this.page.url();
    return (
      currentUrl.includes("lightning") || currentUrl.includes("salesforce.com")
    );
  }
}

module.exports = SFAuth;
