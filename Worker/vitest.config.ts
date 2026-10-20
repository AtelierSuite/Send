import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

// Reads the production Worker from wrangler.jsonc, so the tests and the deployed
// Worker cannot drift. Only the secret is supplied here.
export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: { bindings: { SERVER_SECRET: "test-secret-not-for-production" } },
    }),
  ],
});
