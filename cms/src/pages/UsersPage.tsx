import { useEffect, useMemo, useState } from "react";
import { ShieldCheck } from "lucide-react";
import { useAuth } from "../auth/auth-context";
import { Alert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { formatDate } from "../types/format";
import { Dialog } from "../components/Dialog";
import { Field, Section } from "../components/Form";
import { useToast } from "../components/toast-context";
import {
  callableMessage,
  listAdmins,
  listUsers,
  setAdminRole,
} from "../lib/users";
import type { AdminMember, AppUser } from "../types/user";

/**
 * Admin wireframe screen 10 — Users & roles.
 *
 * Two lists that look alike but come from different places, which is the
 * thing to keep straight when editing this file:
 *
 * - **Admin team** is whoever holds the `admin` custom claim. That lives on
 *   the Auth account, not in Firestore, so it is fetched through the
 *   `listAdmins` callable and changed through `setAdminRole`. Someone who has
 *   only ever opened the CMS appears here and nowhere else.
 * - **App users** is the `users/` collection — accounts that have signed in to
 *   the mobile app. Read-only: `firestore.rules` lets an admin read any
 *   profile and write none.
 *
 * One screen, like guides. The grant form is inline rather than a route,
 * because it is one field.
 */
export function UsersPage() {
  const { user: me } = useAuth();
  const toast = useToast();

  const [admins, setAdmins] = useState<AdminMember[] | null>(null);
  const [adminsError, setAdminsError] = useState<string | null>(null);
  const [users, setUsers] = useState<AppUser[] | null>(null);
  const [usersError, setUsersError] = useState<string | null>(null);

  const [grantEmail, setGrantEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [confirmRevoke, setConfirmRevoke] = useState<AdminMember | null>(null);
  const [search, setSearch] = useState("");

  async function reloadAdmins() {
    try {
      setAdmins(await listAdmins());
      setAdminsError(null);
    } catch (err) {
      setAdminsError(callableMessage(err));
    }
  }

  async function reloadUsers() {
    try {
      setUsers(await listUsers());
      setUsersError(null);
    } catch (err) {
      setUsersError(err instanceof Error ? err.message : String(err));
    }
  }

  useEffect(() => {
    void reloadAdmins();
    void reloadUsers();
  }, []);

  const adminUids = useMemo(
    () => new Set((admins ?? []).map((a) => a.uid)),
    [admins],
  );

  const filteredUsers = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return users ?? [];
    return (users ?? []).filter(
      (u) =>
        (u.email ?? "").toLowerCase().includes(q) ||
        (u.displayName ?? "").toLowerCase().includes(q),
    );
  }, [users, search]);

  async function grant(email: string) {
    const clean = email.trim();
    if (!clean) return;
    setBusy(true);
    try {
      const member = await setAdminRole(clean, true);
      setGrantEmail("");
      await reloadAdmins();
      toast.success(
        `${member.email ?? clean} is now an admin`,
        "They need to sign out and back in before it takes effect.",
      );
    } catch (err) {
      toast.error("Could not grant admin", callableMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function revoke(member: AdminMember) {
    if (!member.email) {
      toast.error("Could not revoke", "This account has no email to address.");
      return;
    }
    setBusy(true);
    try {
      await setAdminRole(member.email, false);
      setConfirmRevoke(null);
      await reloadAdmins();
      toast.success(
        `${member.email} is no longer an admin`,
        "Their current session keeps working until their token refreshes.",
      );
    } catch (err) {
      toast.error("Could not revoke", callableMessage(err));
    } finally {
      setBusy(false);
    }
  }

  const adminCount = admins
    ? `${admins.length} admin${admins.length === 1 ? "" : "s"}`
    : "Loading…";
  const userCount = users
    ? `${users.length} app user${users.length === 1 ? "" : "s"}`
    : "Loading…";

  return (
    <section className="page">
      <PageHeader title="Users & roles" meta={`${adminCount} · ${userCount}`} />

      <Alert variant="info" title="Admin is an account setting, not a document">
        The admin claim is what lets someone publish content. It is set on the
        Auth account by a Cloud Function, and it reaches the person on their
        next sign-in — after granting or revoking, ask them to sign out and
        back in. The first admin on a fresh project is still created with{" "}
        <code>scripts/grant-admin.mjs</code>; everyone after that is added
        here.
      </Alert>

      {/* ---- Admin team ------------------------------------------------ */}

      <div className="editor-card">
        <div className="editor-panel">
          <Section
            title="Admin team"
            hint="Everyone who can edit and publish content in this CMS."
          >
            {adminsError && (
              <Alert variant="destructive" title="Could not load the admin team">
                {adminsError}. Is the functions emulator running? It starts
                with <code>docker compose up emulators</code> and needs a few
                seconds longer than Firestore.
              </Alert>
            )}

            {admins === null && !adminsError ? (
              <div className="skeleton" />
            ) : admins && admins.length === 0 ? (
              <div className="empty">
                <p>No admins found — which should be impossible if you are seeing this.</p>
              </div>
            ) : (
              admins && (
                <table className="data">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Email</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {admins.map((a) => {
                      const isMe = a.uid === me?.uid;
                      return (
                        <tr key={a.uid}>
                          <td>
                            <span className="row">
                              <ShieldCheck size={14} aria-hidden="true" />
                              {a.displayName ?? <span className="hint">—</span>}
                              {isMe && <span className="badge">you</span>}
                            </span>
                          </td>
                          <td className="hint">{a.email ?? a.uid}</td>
                          <td className="row">
                            {/* Not a disabled button: one that looks pressable
                                and does nothing, with the reason in a tooltip,
                                is the least helpful way to say no. */}
                            {isMe ? (
                              <span className="hint">
                                Another admin can revoke yours
                              </span>
                            ) : (
                              <button
                                className="btn-quiet sm"
                                disabled={busy}
                                onClick={() => setConfirmRevoke(a)}
                              >
                                Revoke
                              </button>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )
            )}

            <Field
              label="Add an admin"
              hint="They must have signed in to the app or this CMS at least once."
              wide
            >
              <form
                className="row"
                onSubmit={(e) => {
                  e.preventDefault();
                  void grant(grantEmail);
                }}
              >
                <input
                  type="email"
                  value={grantEmail}
                  onChange={(e) => setGrantEmail(e.target.value)}
                  placeholder="colleague@tourism.cagayan.gov.ph"
                  disabled={busy}
                />
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={busy || !grantEmail.trim()}
                >
                  Grant admin
                </button>
              </form>
            </Field>
          </Section>
        </div>
      </div>

      {/* ---- App users ------------------------------------------------- */}

      <div className="toolbar">
        <input
          className="search"
          placeholder="Search app users by name or email"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <span className="spacer" />
        {search.trim() && (
          <button className="btn-quiet" onClick={() => setSearch("")}>
            Clear
          </button>
        )}
      </div>

      {usersError && (
        <Alert variant="destructive" title="Could not load app users">
          {usersError}. Is the emulator running, and do you still have the
          admin claim?
        </Alert>
      )}

      {users === null && !usersError ? (
        <table className="data">
          <tbody>
            {Array.from({ length: 4 }, (_, i) => (
              <tr key={i}>
                <td colSpan={6}>
                  <div className="skeleton" />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : users && filteredUsers.length === 0 ? (
        <div className="empty">
          <p>
            {users.length === 0
              ? "Nobody has signed in to the app yet."
              : "Nothing matches that search."}
          </p>
        </div>
      ) : (
        users && (
          <table className="data">
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Joined</th>
                <th>Saved tours</th>
                <th>Downloaded towns</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((u) => {
                const isAdmin = adminUids.has(u.uid);
                return (
                  <tr key={u.uid}>
                    <td>
                      {u.displayName ?? <span className="hint">—</span>}{" "}
                      {isAdmin && (
                        <span className="badge ok">
                          <ShieldCheck size={12} aria-hidden="true" /> admin
                        </span>
                      )}
                    </td>
                    <td className="hint">{u.email ?? "—"}</td>
                    <td className="hint">
                      {formatDate(u.createdAt)}
                    </td>
                    <td>{u.savedTourIds?.length ?? 0}</td>
                    <td>{u.downloadedTownIds?.length ?? 0}</td>
                    <td className="row">
                      {!isAdmin && u.email && (
                        <button
                          className="btn-quiet sm"
                          disabled={busy}
                          onClick={() => void grant(u.email!)}
                        >
                          Make admin
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )
      )}

      <Dialog
        open={confirmRevoke !== null}
        onDismiss={() => setConfirmRevoke(null)}
        variant="destructive"
        title={`Revoke admin from ${confirmRevoke?.email ?? ""}?`}
        actions={
          <>
            <button
              className="btn-quiet"
              onClick={() => setConfirmRevoke(null)}
            >
              Keep them
            </button>
            <button
              className="btn-secondary"
              disabled={busy}
              onClick={() => confirmRevoke && void revoke(confirmRevoke)}
            >
              Revoke
            </button>
          </>
        }
      >
        They lose the ability to edit or publish content. Nothing they already
        published is affected, and you can grant it back at any time.
      </Dialog>
    </section>
  );
}
