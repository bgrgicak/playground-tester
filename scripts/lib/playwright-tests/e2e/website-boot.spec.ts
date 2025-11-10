import { test, expect } from "../playground-fixtures.ts";
import fs from "fs";

const playgroundUrls = [
  {
    name: "Playground from November 6th 2024",
    url: "http://127.0.0.1:5932/",
    wpVersion: 6.6,
  },
  {
    name: "Playground from November 6th 2025",
    url: "http://127.0.0.1:5400/",
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

// Guess plugin dependencies based on slug patterns
function guessDependencies(slug: string): string[] {
  const dependencies: string[] = [];

  // Pattern: contains "contact-form-7" but is not exactly "contact-form-7"
  if (slug.includes("contact-form-7") && slug !== "contact-form-7") {
    dependencies.push("contact-form-7");
  }

  // Pattern: contains "woo-" but is not exactly "woocommerce"
  if (slug.includes("woo-") && slug !== "woocommerce") {
    dependencies.push("woocommerce");
  }

  // If dynamic-visibility-for-elementor install elementor
  if (slug === "dynamic-visibility-for-elementor") {
    dependencies.push("elementor");
  }

  return dependencies;
}

// Apply dependency guessing to plugins with empty requires_plugins
pluginsToTest.forEach((plugin: any) => {
  if (!plugin.requires_plugins || plugin.requires_plugins.length === 0) {
    const guessedDeps = guessDependencies(plugin.slug);
    if (guessedDeps.length > 0) {
      plugin.requires_plugins = guessedDeps;
    }
  }
});

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
      const pluginInstallStep = (slug: string) => ({
        step: "installPlugin",
        pluginData: {
          resource: "wordpress.org/plugins",
          slug: slug,
        },
        options: {
          activate: false,
        },
      });
      if (plugin.requires_plugins) {
        for (const requiredPlugin of plugin.requires_plugins) {
          blueprint.steps.push(pluginInstallStep(requiredPlugin));
        }
      }
      blueprint.steps.push(pluginInstallStep(slug));
      await website.goto(`${playgroundUrl.url}#${JSON.stringify(blueprint)}`);
      await website.waitForNestedIframes();

      // Activate all plugins
      await wordpress.locator("#cb-select-all-1").check();
      await wordpress
        .locator("#bulk-action-selector-top")
        .selectOption("activate-selected");
      await wordpress.locator("#doaction").click();

      // wait for the page to reload after bulk activation
      await website.waitForNestedIframes(website.page);

      /**
       * Some plugins redirect to custom pages after activation.
       * Keep reloading until we see the h1 title "Plugins" (up to 10 attempts).
       *
       * We do this because await website.waitForNestedIframes sometimes doesn't
       * wait for the full page load after activation.
       */
      const urlInput = await website.page.getByLabel(
        "URL to visit in the WordPress"
      );
      await expect(
        urlInput,
        `The Playground Website didn't load correctly. The URL input for ${plugin.slug} is not visible.`
      ).toBeVisible();

      let attempts = 0;
      const maxAttempts = 10;
      while (attempts < maxAttempts) {
        attempts++;
        const h1 = wordpress.locator("h1").first();
        const h1Text = await h1.textContent();

        if (h1Text === "Plugins") {
          break;
        }

        if (attempts < maxAttempts) {
          // Add a small delay to avoid overwhelming the server
          await website.page.waitForTimeout(1000);
          await urlInput.fill(url);
          await urlInput.press("Enter");
          await website.waitForNestedIframes(website.page);
        }
      }

      const h1 = wordpress.locator("h1").first();
      await expect(
        h1,
        `Failed to load plugins page for ${plugin.slug} after ${maxAttempts} attempts`
      ).toHaveText("Plugins");

      /**
       * Check that the plugin is activated by looking for the Deactivate button
       */
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
