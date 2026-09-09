/**
 * The pure half of admin promotion — everything that can be unit-tested
 * without an Auth backend. `admin.ts` wraps these in the callable.
 */

export type Claims = Record<string, unknown>;

/**
 * The claims to write back for a grant or a revoke.
 *
 * Read-modify-write, never a blind set: `setCustomUserClaims` replaces the
 * whole object, so writing `{ admin: true }` would silently drop any other
 * claim the account carries. Spreading `undefined` is a no-op, which covers a
 * user who has never had claims.
 */
export function withAdmin(existing: Claims | undefined, admin: boolean): Claims {
  const next: Claims = { ...existing };
  if (admin) next.admin = true;
  else delete next.admin;
  return next;
}

export type SetAdminRequest = { email: string; admin: boolean };

/**
 * Validate the callable's payload. Throws a plain Error with a message fit to
 * show the caller; `admin.ts` turns it into an `invalid-argument` HttpsError.
 *
 * Deliberately strict about types rather than coercing. A payload built by
 * the CMS is always well-formed; anything else is a hand-rolled request, and
 * "admin: 'false'" being truthy is exactly the kind of mistake that grants
 * access by accident.
 */
export function parseSetAdminRequest(data: unknown): SetAdminRequest {
  if (typeof data !== "object" || data === null) {
    throw new Error("Expected { email, admin }.");
  }
  const { email, admin } = data as Record<string, unknown>;
  if (typeof email !== "string" || !email.trim()) {
    throw new Error("email is required.");
  }
  if (typeof admin !== "boolean") {
    throw new Error("admin must be true or false.");
  }
  return { email: email.trim().toLowerCase(), admin };
}

/**
 * The one guard that protects the project from itself.
 *
 * If the last admin revokes their own claim, nobody can write content and
 * nobody can grant the claim back through the CMS — recovery means a service
 * account key and `scripts/grant-admin.mjs`. Refusing self-revoke does not
 * make that impossible (two admins can still revoke each other), but it stops
 * the single most likely way of getting there: one person, one misclick.
 */
export function assertNotSelfRevoke(
  callerUid: string,
  targetUid: string,
  admin: boolean,
): void {
  if (!admin && callerUid === targetUid) {
    throw new Error(
      "You cannot revoke your own admin access. Ask another admin to do it.",
    );
  }
}
