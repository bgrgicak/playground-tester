import { test, expect } from "../playground-fixtures.ts";
import fs from "fs";

const playgroundUrls = [
  {
    name: "Playground from November 6th 2024",
    url: "http://127.0.0.1:5932/",
    oldUI: false,
    wpVersion: 6.6,
  },
  {
    name: "Playground from November 6th 2025",
    url: "http://127.0.0.1:5400/",
    oldUI: false,
    wpVersion: 6.8,
  },
];

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
      const blueprint = {
        landingPage: url,
        login: true,
        preferredVersions: {
          php: "8.3",
          wp: playgroundWpVersion.toString(),
        },
        steps: [] as any[],
      };

      const slug = plugin.slug;
      if (plugin.requires_plugins) {
        for (const requiredPlugin of plugin.requires_plugins) {
          blueprint.steps.push({
            step: "installPlugin",
            pluginData: {
              resource: "wordpress.org/plugins",
              slug: requiredPlugin,
            },
            options: {
              activate: true,
            },
          });
        }
      }
      blueprint.steps.push({
        step: "installPlugin",
        pluginData: {
          resource: "wordpress.org/plugins",
          slug: slug,
        },
        options: {
          activate: true,
        },
      });
      await website.goto(`${playgroundUrl.url}#${JSON.stringify(blueprint)}`);
      await website.waitForNestedIframes();

      expect(website.page.locator("h1", { hasText: "Report error" }), {
        message: "Playground failed to boot with an error.",
      }).not.toBeVisible();

      // Check if WordPress loaded the error page on first load
      expect(wordpress.locator("body")).not.toHaveId("error-page");

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
      const deactivateButtonByHrefStart = await wordpress.locator(
        `a[href^="plugins.php?action=deactivate&plugin=${slug}"]`
      );
      await expect(
        deactivateButtonByHrefStart
          .or(deactivateButtonById)
          .or(deactivateButtonByLabel),
        `The plugin ${plugin.name} isn't activated.`
      ).toHaveText("Deactivate");
    });
  });
});
