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

  // If oneclick-whatsapp-order install woocommerce
  if (slug === "oneclick-whatsapp-order") {
    dependencies.push("woocommerce");
  }

  // if name contains elementor add elementor as dependency
  if (slug.includes("elementor") && slug !== "elementor") {
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
      /**
       * Activates plugins and ensures we're back on the plugins page.
       * Some plugins redirect to custom pages after activation.
       */
      const activatePluginsAndReturnToPluginsPage = async (
        pluginSlugs: string[]
      ) => {
        const url = "/wp-admin/plugins.php";

        for (const pluginSlug of pluginSlugs) {
          // Activate the plugin
          const activateLink = wordpress.locator(`#activate-${pluginSlug}`);
          await activateLink.click();

          // Wait for the page to reload after activation
          await website.waitForNestedIframes(website.page);
        }

        // Keep reloading until we see the h1 title "Plugins" (up to 10 attempts)
        const urlInput = website.page.getByLabel(
          "URL to visit in the WordPress"
        );
        await expect(
          urlInput,
          `The Playground Website didn't load correctly. The URL input is not visible.`
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
          `Failed to load plugins page after ${maxAttempts} attempts`
        ).toHaveText("Plugins");
      };

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
      console.log(JSON.stringify(blueprint));
      await website.goto(`${playgroundUrl.url}#${JSON.stringify(blueprint)}`);
      await website.waitForNestedIframes();

      // First activate dependencies if they exist
      if (plugin.requires_plugins && plugin.requires_plugins.length > 0) {
        await activatePluginsAndReturnToPluginsPage(plugin.requires_plugins);
      }

      // Now activate the main plugin
      await activatePluginsAndReturnToPluginsPage([slug]);

      /**
       * Check that the plugin is activated by looking for the Deactivate button
       */
      const deactivateButtonById = await wordpress.locator(
        `#deactivate-${slug}`
      );
      await expect(
        deactivateButtonById,
        `The plugin ${plugin.name} isn't activated.`
      ).toHaveText("Deactivate");
    });
  });
});
