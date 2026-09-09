import { initializeApp } from "firebase-admin/app";

// One app for the whole codebase. Inside Cloud Functions and the emulator the
// SDK picks up project and credentials from the environment, so no config.
initializeApp();

export { listAdmins, setAdminRole } from "./admin.js";
export { generateOfflineBundle } from "./bundles.js";
