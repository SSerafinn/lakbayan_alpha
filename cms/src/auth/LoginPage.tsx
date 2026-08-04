import { useState, type FormEvent } from "react";
import { FirebaseError } from "firebase/app";
import { useAuth } from "./auth-context";

/** Admin wireframe screen 1 — Admin Login. */
export function LoginPage() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signIn(email, password);
    } catch (err) {
      // Stay vague about which of the two was wrong: naming it tells an
      // attacker which admin accounts exist.
      setError(
        err instanceof FirebaseError && err.code === "auth/too-many-requests"
          ? "Too many attempts. Wait a moment and try again."
          : "That email and password don't match.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="auth-shell">
      <form className="auth-card" onSubmit={onSubmit}>
        <div className="auth-brand">
          <span className="auth-mark">L</span>
          <div>
            <h1>Lakbayan</h1>
            <p className="overline">Content management</p>
          </div>
        </div>

        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="username"
            required
          />
        </label>

        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>

        {error && <p className="error-note">{error}</p>}

        <button type="submit" className="btn-primary" disabled={busy}>
          {busy ? "Signing in..." : "Sign in"}
        </button>

        <p className="hint">
          Staff accounts only. Access is granted by an existing administrator.
        </p>
      </form>
    </main>
  );
}

/**
 * Shown to a user who authenticated but lacks the `admin` claim.
 *
 * Deliberately distinct from a login failure: they signed in correctly, they
 * simply are not staff. Telling them to log in again would send them round a
 * loop that can never succeed.
 */
export function NotAuthorised() {
  const { user, signOut } = useAuth();
  return (
    <main className="auth-shell">
      <div className="auth-card">
        <h1>Not an administrator</h1>
        <p>
          {user?.email} is signed in, but does not have CMS access. Ask an
          existing administrator to grant it.
        </p>
        <button className="btn-secondary" onClick={() => void signOut()}>
          Sign out
        </button>
      </div>
    </main>
  );
}
