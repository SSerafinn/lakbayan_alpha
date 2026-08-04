import { initializeApp, type FirebaseOptions } from "firebase/app";
import { getAuth, connectAuthEmulator } from "firebase/auth";
import { getFirestore, connectFirestoreEmulator } from "firebase/firestore";
import { getStorage, connectStorageEmulator } from "firebase/storage";

/**
 * Whether to talk to the local Emulator Suite.
 *
 * Read from an env var at build time, so a production bundle compiled without
 * it has no path to a developer's laptop.
 */
export const useEmulators = import.meta.env.VITE_USE_EMULATORS === "true";

const emulatorHost = import.meta.env.VITE_EMULATOR_HOST ?? "127.0.0.1";

/**
 * Placeholder config for emulator work.
 *
 * The same reasoning as the Flutter app: a `demo-` project has no backend, so
 * if an emulator connection ever fails the CMS cannot silently fall through to
 * production and start editing real published content. The project id must
 * match the `--project` flag on the `emulators` service in docker-compose.yml.
 */
const demoConfig: FirebaseOptions = {
  apiKey: "demo-api-key",
  appId: "1:000000000000:web:0000000000000000",
  messagingSenderId: "000000000000",
  projectId: "demo-lakbayan",
  storageBucket: "demo-lakbayan.appspot.com",
};

/**
 * The real dev project. Not secret — Firebase web API keys are public
 * identifiers; access is governed by firestore.rules and App Check.
 * See docs/DECISIONS.md D-08.
 */
const liveConfig: FirebaseOptions = {
  apiKey: "AIzaSyD22OHnyfUR37JkN8suZ-Gre4tMlyhFPcM",
  appId: "1:3422515105:web:58805326239b43adc225e0",
  messagingSenderId: "3422515105",
  projectId: "project-lakbayan",
  authDomain: "project-lakbayan.firebaseapp.com",
  storageBucket: "project-lakbayan.firebasestorage.app",
};

export const app = initializeApp(useEmulators ? demoConfig : liveConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

if (useEmulators) {
  // Must run before any read or write — these SDKs latch their endpoint on
  // first use and throw if repointed afterwards.
  connectAuthEmulator(auth, `http://${emulatorHost}:9099`, {
    disableWarnings: true,
  });
  connectFirestoreEmulator(db, emulatorHost, 8080);
  connectStorageEmulator(storage, emulatorHost, 9199);
}

// eslint-disable-next-line no-console
console.info(
  `Lakbayan CMS — ${
    useEmulators
      ? `emulators on ${emulatorHost}`
      : "LIVE project, writes hit the real backend"
  }`,
);
