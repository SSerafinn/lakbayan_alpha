import {
  collection,
  getCountFromServer,
  getDocs,
  orderBy,
  query,
} from "firebase/firestore";
import { httpsCallable, type FunctionsError } from "firebase/functions";
import { db, functions } from "./firebase";
import type { AdminMember, AppUser } from "../types/user";

/**
 * Every app user, newest first.
 *
 * Recency, unlike the guides directory: this is a "who has signed up" view,
 * and the interesting rows are the ones that were not there yesterday.
 */
export async function listUsers(): Promise<AppUser[]> {
  const snap = await getDocs(
    query(collection(db, "users"), orderBy("createdAt", "desc")),
  );
  return snap.docs.map((d) => ({ uid: d.id, ...d.data() }) as AppUser);
}

/**
 * How many people have signed in to the app.
 *
 * An aggregation query rather than `listUsers().length`: the dashboard wants
 * the number, and this collection is the one that grows without bound.
 */
export async function countUsers(): Promise<number> {
  const snap = await getCountFromServer(collection(db, "users"));
  return snap.data().count;
}

// The two callables in functions/src/admin.ts. Typed at the call site because
// the two packages do not share a build; keep these in step with the function
// signatures by hand.
const listAdminsFn = httpsCallable<void, { admins: AdminMember[] }>(
  functions,
  "listAdmins",
);
const setAdminRoleFn = httpsCallable<
  { email: string; admin: boolean },
  AdminMember & { admin: boolean }
>(functions, "setAdminRole");

export async function listAdmins(): Promise<AdminMember[]> {
  const res = await listAdminsFn();
  return res.data.admins;
}

/**
 * Grant or revoke the `admin` claim.
 *
 * Goes through a Cloud Function because only the Admin SDK can set custom
 * claims, and the Admin SDK must never run in a browser. The function refuses
 * a self-revoke; everything else it reports back as a `FunctionsError` whose
 * message is already fit to show.
 */
export async function setAdminRole(
  email: string,
  admin: boolean,
): Promise<AdminMember> {
  const res = await setAdminRoleFn({ email, admin });
  return res.data;
}

/** A readable message from a callable failure, or from anything else. */
export function callableMessage(err: unknown): string {
  if (typeof err === "object" && err !== null && "code" in err) {
    const fe = err as FunctionsError;
    // The server's own message is the useful part; the code prefix is not.
    return fe.message.replace(/^Firebase: /, "").replace(/ \(functions\/.*\)$/, "");
  }
  return err instanceof Error ? err.message : String(err);
}
