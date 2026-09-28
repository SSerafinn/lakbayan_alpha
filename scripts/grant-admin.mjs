// Grant or revoke the `admin` custom claim — the BOOTSTRAP, for the first
// admin on a fresh project.
//
// firestore.rules and storage.rules gate every content write on
// `request.auth.token.admin == true`. Day to day, admins are added from the
// CMS's Users & roles screen, which calls the `setAdminRole` function in
// functions/. That screen needs an admin to open it, so the first one has to
// come from here. After that, prefer the screen: it needs no service account
// key, and it refuses the self-revoke this script will happily perform.
//
// Usage (emulator — the default, and safe):
//   cd scripts && npm install
//   node grant-admin.mjs you@example.com
//
// Usage (a real project — deliberate and irreversible-ish):
//   $env:GOOGLE_APPLICATION_CREDENTIALS="C:/path/serviceAccount.json"
//   node grant-admin.mjs you@example.com --live --project project-lakbayan
//
// Revoke with --revoke.
//
// The user must already exist: sign in through the app once first. Claims only
// reach the client on the next token refresh, so sign out and back in after.

import { initializeApp, cert, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { readFileSync } from "node:fs";

const args = process.argv.slice(2);
const email = args.find((a) => !a.startsWith("--"));
const revoke = args.includes("--revoke");
const live = args.includes("--live");
// Guard the -1: `args[args.indexOf("--project") + 1]` silently resolves to
// args[0] — the email — when the flag is absent.
const projectFlag = args.indexOf("--project");
const projectId =
  projectFlag !== -1 && args[projectFlag + 1]
    ? args[projectFlag + 1]
    : live
      ? "project-lakbayan"
      : "demo-lakbayan";

if (!email) {
  console.error(
    "Usage: node grant-admin.mjs <email> [--revoke] [--live] [--project <id>]"
  );
  process.exit(1);
}

// Live mode is opt-in and loud. Granting admin on the real project hands
// someone write access to all published content.
if (live) {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) {
    console.error(
      "--live needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service " +
        "account JSON. Firebase console -> Project settings -> Service accounts."
    );
    process.exit(1);
  }
  console.warn(
    `\n!!  LIVE project "${projectId}". This grants write access to real ` +
      `published content.\n`
  );
  initializeApp({
    credential: cert(JSON.parse(readFileSync(keyPath, "utf8"))),
    projectId,
  });
} else {
  // The Admin SDK talks to the emulator purely through this env var, and needs
  // no credentials when it is set.
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
  console.log(
    `Emulator mode (${process.env.FIREBASE_AUTH_EMULATOR_HOST}), project "${projectId}".`
  );
  initializeApp({ credential: applicationDefault(), projectId });
}

const auth = getAuth();

try {
  const user = await auth.getUserByEmail(email);

  // Read-modify-write: setCustomUserClaims replaces the whole object, so a
  // blind set would silently drop any other claim the user has.
  // Spreading null or undefined is already a no-op, so no `?? {}` is needed.
  const claims = { ...user.customClaims };
  if (revoke) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await auth.setCustomUserClaims(user.uid, claims);

  console.log(
    `${revoke ? "Revoked" : "Granted"} admin for ${email} (${user.uid}).`
  );
  console.log(
    "They must sign out and back in — custom claims are baked into the ID " +
      "token and will not appear until it is reissued."
  );
} catch (err) {
  if (err.code === "auth/user-not-found") {
    console.error(
      `No user with email ${email} in project "${projectId}". Sign in through ` +
        "the app once to create the account, then re-run."
    );
  } else {
    console.error(err.message ?? err);
  }
  process.exit(1);
}
