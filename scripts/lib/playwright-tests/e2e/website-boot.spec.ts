import { test, expect } from "../playground-fixtures.ts";
import fs from "fs";

const playgroundUrls = [
  {
    name: "Playground from December 2023",
    url: "http://localhost:5400/website-server/",
    oldUI: true,
    wpVersion: 6.4,
  },
  {
    name: "Playground from December 2024",
    url: "http://localhost:5401/website-server/",
    oldUI: false,
    wpVersion: 6.6,
  },
];

// Read ../plugins-to-test.txt and store each line as a array item
const currentDir = process.cwd();
const pluginsToTest = JSON.parse(
  fs.readFileSync(
    `${currentDir}/scripts/lib/playwright-tests/plugins-to-test.json`,
    "utf8"
  )
);

pluginsToTest.forEach((plugin) => {
  playgroundUrls.forEach((playgroundUrl) => {
    test(`${playgroundUrl.name} - ${plugin.slug} should load`, async ({
      website,
      wordpress,
    }) => {
      const playgroundWpVersion = playgroundUrl.wpVersion;
      const minWpVersion = plugin.requires
        ? parseFloat(plugin.requires)
        : playgroundWpVersion;
      expect(
        minWpVersion,
        `Min WP version for ${plugin.slug} is ${minWpVersion}`
      ).toBeLessThanOrEqual(playgroundWpVersion);

      const url = "/wp-admin/plugins.php";
      const slug = plugin.slug;
      const plugins = [slug];
      if (plugin.requires_plugins) {
        plugins.push(...plugin.requires_plugins);
      }
      const pluginArgs = plugins.map((plugin) => `plugin=${plugin}`).join("&");
      const response = await website.goto(
        `${playgroundUrl.url}?url=${url}&wp=${playgroundWpVersion}&${pluginArgs}`
      );
      await website.waitForNestedIframes(website.page);

      expect(
        response.status(),
        `Response status for ${
          plugin.slug
        } is ${response.status()}. A valid response status is less than 400.`
      ).toBeLessThan(400);

      /**
       * Some plugins are redirecting to custom pages, so we need to check if the URL is correct
       * and if not, redirect to the correct URL using the Playground Website URL input.
       */
      let urlInput;
      if (playgroundUrl.oldUI) {
        urlInput = await website.page.getByRole("textbox", {
          name: "URL to visit in the WordPress",
        });
      } else {
        urlInput = await website.page.getByLabel(
          "URL to visit in the WordPress"
        );
      }
      await expect(
        urlInput,
        `The Playground Website didn't load correctly. The URL input for ${plugin.slug} is not visible.`
      ).toBeVisible();
      if ((await urlInput.inputValue()) !== url) {
        await urlInput.fill(url);
        await urlInput.press("Enter");
        await website.waitForNestedIframes(website.page);
      }

      const deactivateButtonByLabel = await wordpress.getByLabel(
        `Deactivate ${plugin.name}`
      );
      const deactivateButtonById = await wordpress.locator(
        `#deactivate-${slug}`
      );
      await expect(deactivateButtonByLabel.or(deactivateButtonById)).toHaveText(
        "Deactivate"
      );
    });
  });
});
