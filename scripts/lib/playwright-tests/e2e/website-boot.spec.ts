import { test, expect } from "../playground-fixtures.ts";
import fs from "fs";

const playgroundUrls = [
  {
    name: "Playground from November 6th 2024",
    url: "http://127.0.0.1:5932/",
    proxyUrl: "http://127.0.0.1:5932/plugin-proxy.php?url=",
    wpVersion: 6.6,
    year: 2024,
  },
  {
    name: "Playground from November 6th 2025",
    url: "http://127.0.0.1:5400/",
    proxyUrl: "http://127.0.0.1:5400/plugin-proxy.php?url=",
    wpVersion: 6.8,
    year: 2025,
  },
];

const currentDir = process.cwd();

// playground-2024-2025-error-comparison.json
const testResults = JSON.parse(
  fs.readFileSync(
    `${currentDir}/playground-2024-2025-error-comparison.json`,
    "utf8"
  )
);
const testResultsMap: {
  [slug: string]: { result_2024: string; result_2025: string };
} = {};
for (const result of testResults) {
  testResultsMap[result.slug] = {
    ...result,
  };
}

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

  // if cf7-conditional-fields add contact-form-7 as dependency
  if (slug === "cf7-conditional-fields") {
    dependencies.push("contact-form-7");
  }

  // Pattern: contains "woo-" but is not exactly "woocommerce"
  if (slug.includes("woo-") && slug !== "woocommerce") {
    dependencies.push("woocommerce");
  }

  // Add "woocommerce" if slug contains "woocommerce" but is not exactly "woocommerce"
  if (slug.includes("woocommerce") && slug !== "woocommerce") {
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

  // If yith install woocommerce
  if (slug.startsWith("yith")) {
    dependencies.push("woocommerce");
  }

  // if name contains loco-translate add loco-translate as dependency
  if (slug.includes("loco-translate") && slug !== "loco-translate") {
    dependencies.push("loco-translate");
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
    // Skip test if previously passed for this playground year
    if (
      testResultsMap[plugin.slug] &&
      testResultsMap[plugin.slug][`result_${playgroundUrl.year}`] === "ok"
    ) {
      return;
    }
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
          // Wait for the page to reload after activation
          await website.waitForNestedIframes(website.page);

          // Retry activation because the page might not be ready
          let activationSuccess = false;
          const maxAttempts = 10;
          let attempts = 0;

          while (attempts < maxAttempts && !activationSuccess) {
            attempts++;
            try {
              const activateLink = wordpress.locator(
                `a[href*="plugins.php?action=activate&plugin=${pluginSlug}%2F"], a[href*="plugins.php?action=activate&plugin=${pluginSlug}.php"], #activate-${pluginSlug}`
              );
              await activateLink.click({ timeout: 5000 }); // 5-second timeout per attempt
              activationSuccess = true;
            } catch (error) {
              if (attempts < maxAttempts) {
                await website.page.waitForTimeout(1000);
                await website.waitForNestedIframes(website.page);
              }
            }
          }

          await expect(
            activationSuccess,
            `Failed to activate ${pluginSlug} after ${maxAttempts} attempts`
          ).toBeTruthy();

          try {
            // Plugin activation shouldn't cause a critical error
            const errorMessage = wordpress.locator(
              "has-text=There has been a critical error on this website"
            );
            await expect(
              errorMessage,
              `Activating plugin ${pluginSlug} caused a critical error.`
            ).not.toBeVisible();
          } catch (e) {
            // Ignore errors in checking for critical error message
          }
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
          let h1Text: string | null = null;

          try {
            h1Text = await h1.textContent({ timeout: 5000 });
          } catch (error) {
            // h1 element not found, will retry by reloading
          }

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
      };

      // Find the minimum WordPress version required by plugin and its dependencies
      let minWpVersion = plugin.requires
        ? parseFloat(plugin.requires)
        : playgroundUrl.wpVersion;

      // Check dependencies' WordPress requirements
      if (plugin.requires_plugins && plugin.requires_plugins.length > 0) {
        for (const depSlug of plugin.requires_plugins) {
          const depPlugin = pluginsToTest.find((p: any) => p.slug === depSlug);
          if (depPlugin && depPlugin.requires) {
            const depMinVersion = parseFloat(depPlugin.requires);
            if (depMinVersion > minWpVersion) {
              minWpVersion = depMinVersion;
            }
          }
        }
      }

      let playgroundWpVersion: string | number = playgroundUrl.wpVersion;
      if (minWpVersion > playgroundUrl.wpVersion) {
        playgroundWpVersion = `${playgroundUrl.proxyUrl}https://wordpress.org/wordpress-${minWpVersion}.zip`;
      }

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

      console.log(`${playgroundUrl.url}#${JSON.stringify(blueprint)}`);
      await website.goto(`${playgroundUrl.url}#${JSON.stringify(blueprint)}`);
      await website.waitForNestedIframes();

      // Explicitly navigate to plugins page to ensure it's fully loaded with installed plugins
      const urlInput = website.page.getByLabel("URL to visit in the WordPress");
      await urlInput.fill(url);
      await urlInput.press("Enter");
      await website.waitForNestedIframes();

      // Wait for plugins page to load
      const h1 = wordpress.locator("h1").first();
      await expect(h1, "Plugins page should load after blueprint").toHaveText(
        "Plugins",
        { timeout: 10000 }
      );

      // First activate dependencies if they exist
      if (plugin.requires_plugins && plugin.requires_plugins.length > 0) {
        await activatePluginsAndReturnToPluginsPage(plugin.requires_plugins);
      }

      // Now activate the main plugin
      await activatePluginsAndReturnToPluginsPage([slug]);

      /**
       * Check that the plugin is activated by looking for the Deactivate button
       */
      // try 10 times to find the deactivate button with 3 seconds interval
      const maxChecks = 10;
      let checkCount = 0;
      let deactivateButtonFound = false;

      while (checkCount < maxChecks && !deactivateButtonFound) {
        // First check what page we're on
        const h1 = wordpress.locator("h1").first();
        let h1Text = "";
        try {
          h1Text = (await h1.textContent({ timeout: 2000 })) || "";
        } catch (e) {
          h1Text = "[h1 not found]";
        }

        // Match either:
        // - slug/ (folder plugin, URL-encoded as %2F)
        // - slug.php (single-file plugin)
        // - #deactivate-slug (WordPress standard ID)
        const deactivateButton = wordpress.locator(
          `a[href*="plugins.php?action=deactivate&plugin=${slug}%2F"], a[href*="plugins.php?action=deactivate&plugin=${slug}.php"], #deactivate-${slug}`
        );
        const buttonCount = await deactivateButton.count();
        if (buttonCount > 0) {
          deactivateButtonFound = true;
          break;
        }

        // If we're not on the plugins page, try to navigate back
        if (h1Text !== "Plugins" && checkCount < maxChecks - 1) {
          const urlInput = website.page.getByLabel(
            "URL to visit in the WordPress"
          );
          await urlInput.fill("/wp-admin/plugins.php");
          await urlInput.press("Enter");
          await website.waitForNestedIframes(website.page);
        }

        checkCount++;
        await website.page.waitForTimeout(1000); // wait for 1 second before retrying
      }

      await expect(
        deactivateButtonFound,
        `The plugin ${plugin.name} isn't activated.`
      ).toBeTruthy();
    });
  });
});
