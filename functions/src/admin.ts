import { HttpsError, onCall, type CallableRequest } from "firebase-functions/https";
import { getAuth, type UserRecord } from "firebase-admin/auth";
import {
  assertNotSelfRevoke,
  parseSetAdminRequest,
  withAdmin,
} from "./claims.js";
import { REGION } from "./region.js";

/**
 * Admin team management for the CMS (admin wireframe screen 10).
 *
 * The `admin` custom claim is what every content write in firestore.rules and
 * storage.rules checks. Only the Admin SDK can set it, and the Admin SDK only
 * runs somewhere trusted — which is why this is a Cloud Function and not a
 * button that writes a Firestore document. Before this existed, promoting a
 * teammate meant a service account key on someone's laptop and
 * `scripts/grant-admin.mjs`; that script remains the bootstrap for the very
 * first admin, and nothing else.
 */

function requireAdmin(req: CallableRequest<unknown>): string {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (req.auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Only an admin can manage the admin team.",
    );
  }
  return req.auth.uid;
}

export type AdminMember = {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoUrl: string | null;
};

function toMember(u: UserRecord): AdminMember {
  return {
    uid: u.uid,
    email: u.email ?? null,
    displayName: u.displayName ?? null,
    photoUrl: u.photoURL ?? null,
  };
}

/**
 * Grant or revoke the `admin` claim on the account with this email.
 *
 * The target must already exist — they sign in to the app or CMS once first.
 * Claims are baked into the ID token, so the change reaches them on their
 * next token refresh; the CMS tells the caller to have them sign out and in.
 */
export const setAdminRole = onCall({ region: REGION }, async (req) => {
  const callerUid = requireAdmin(req);

  let email: string;
  let admin: boolean;
  try {
    ({ email, admin } = parseSetAdminRequest(req.data));
  } catch (err) {
    throw new HttpsError("invalid-argument", (err as Error).message);
  }

  const auth = getAuth();
  let user: UserRecord;
  try {
    user = await auth.getUserByEmail(email);
  } catch (err) {
    if ((err as { code?: string }).code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        `No account with the email ${email}. They need to sign in once first.`,
      );
    }
    throw err;
  }

  try {
    assertNotSelfRevoke(callerUid, user.uid, admin);
  } catch (err) {
    throw new HttpsError("failed-precondition", (err as Error).message);
  }

  await auth.setCustomUserClaims(user.uid, withAdmin(user.customClaims, admin));

  return { ...toMember(user), admin };
});

/**
 * Everyone who currently holds the claim.
 *
 * Walks the whole user list, because custom claims are not queryable — there
 * is no "where admin == true" on the Auth backend. At this project's scale
 * (a province's tourism office, not a consumer app) that is one page; if it
 * ever becomes more, the answer is to mirror the claim into a Firestore
 * document from this same function, not to paginate in the browser.
 */
export const listAdmins = onCall({ region: REGION }, async (req) => {
  requireAdmin(req);

  const auth = getAuth();
  const admins: AdminMember[] = [];
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      if (u.customClaims?.admin === true) admins.push(toMember(u));
    }
    pageToken = page.pageToken;
  } while (pageToken);

  admins.sort((a, b) => (a.email ?? "").localeCompare(b.email ?? ""));
  return { admins };
});
