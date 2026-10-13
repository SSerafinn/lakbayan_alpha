// Refuses to deploy a CMS build that talks to the emulators.
//
// Runs as a Hosting predeploy step, after the build (firebase.json). The
// backend is chosen at build time (src/lib/firebase.ts): `npm run build` picks
// the live project, but a VITE_USE_EMULATORS=true left in a .env.local is read
// in every mode, and the result would go live pointing every admin's browser
// at 127.0.0.1. A production build has the demo config tree-shaken out, so its
// project id appearing in the bundle means the emulators were compiled in.

import { readdirSync, readFileSync } from "node:fs";

const dir = new URL("../dist/assets/", import.meta.url);
const bundle = readdirSync(dir)
  .filter((f) => f.endsWith(".js"))
  .map((f) => readFileSync(new URL(f, dir), "utf8"))
  .join("\n");

if (bundle.includes("demo-lakbayan")) {
  console.error(
    "cms/dist was built against the emulators, not the live project.\n" +
      "Look for VITE_USE_EMULATORS in cms/.env.local or your shell, remove it, and deploy again.",
  );
  process.exit(1);
}
console.log("cms/dist targets the live project.");
