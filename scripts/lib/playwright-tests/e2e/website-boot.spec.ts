import { test, expect } from "../playground-fixtures.ts";
import fs from "fs";

const playgroundUrls = [
  {
    name: "Playground from December 2023",
    url: "http://localhost:5400/website-server/",
  },
  {
    name: "Playground from December 2024",
    url: "http://localhost:5401/website-server/",
  },
];

// Read ../plugins-to-test.txt and store each line as a array item
const currentDir = process.cwd();
const pluginsToTest = JSON.parse(
  fs.readFileSync(
    `${currentDir}/scripts/lib/playwright-tests/plugins-to-test.json`,
    "utf8"
  )
).splice(0, 12);

pluginsToTest.forEach((plugin) => {
  playgroundUrls.forEach((playgroundUrl) => {
    test(`${playgroundUrl.name} - ${plugin.slug} should load`, async ({
      website,
      wordpress,
    }) => {
      const url = "/wp-admin/plugins.php";
      const slug = plugin.slug;
      const plugins = [slug];
      if (plugin.requires_plugins) {
        plugins.push(...plugin.requires_plugins);
      }
      const pluginArgs = plugins.map((plugin) => `plugin=${plugin}`).join("&");
      const response = await website.goto(
        `${playgroundUrl.url}?url=${url}&${pluginArgs}`
      );
      await website.waitForNestedIframes(website.page);

      expect(response.status()).not.toBe(500);

      /**
       * Some plugins are redirecting to custom pages, so we need to check if the URL is correct
       * and if not, redirect to the correct URL using the Playground Website URL input.
       */
      let urlInput;
      if (playgroundUrl.name === "Playground from December 2023") {
        urlInput = await website.page.getByRole("textbox", {
          name: "URL to visit in the WordPress",
        });
      } else {
        urlInput = await website.page.getByLabel(
          "URL to visit in the WordPress"
        );
      }
      await expect(urlInput).toBeVisible();
      if ((await urlInput.inputValue()) !== url) {
        await urlInput.fill(url);
        await urlInput.press("Enter");
        await website.waitForNestedIframes(website.page);
      }

      await expect(wordpress.locator(`#deactivate-${slug}`)).toContainText(
        "Deactivate"
      );
    });
  });
});
