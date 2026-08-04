import type { ReactNode } from "react";
import { BrowserRouter, Link, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider } from "./auth/AuthProvider";
import { useAuth } from "./auth/auth-context";
import { LoginPage, NotAuthorised } from "./auth/LoginPage";
import { DashboardPage } from "./pages/DashboardPage";
import { DestinationsListPage } from "./pages/DestinationsListPage";
import { DestinationEditorPage } from "./pages/DestinationEditorPage";
import { PlaceholderPage } from "./pages/PlaceholderPage";
import { useEmulators } from "./lib/firebase";

/**
 * Role gate. Every CMS route sits behind it.
 *
 * This is a convenience, not the security boundary — firestore.rules is. A
 * determined non-admin can render whatever they like in their own browser and
 * still cannot write a document.
 */
function Gate({ children }: { children: ReactNode }) {
  const { user, isAdmin, loading } = useAuth();
  if (loading) return <div className="boot">Loading...</div>;
  if (!user) return <LoginPage />;
  if (!isAdmin) return <NotAuthorised />;
  return <>{children}</>;
}

function Shell({ children }: { children: ReactNode }) {
  const { user, signOut } = useAuth();
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="auth-mark small">L</span>
          <strong>Lakbayan</strong>
        </div>
        <nav>
          <Link to="/">Dashboard</Link>
          <Link to="/destinations">Destinations</Link>
          <Link to="/tours">Tours</Link>
          <Link to="/guides">Local guides</Link>
          <Link to="/bundles">Offline bundles</Link>
          <Link to="/users">Users &amp; roles</Link>
          <Link to="/settings">Settings</Link>
        </nav>
        <div className="sidebar-foot">
          <span className="hint">{user?.email}</span>
          <button className="btn-quiet" onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
      </aside>
      <div className="content">
        {useEmulators && (
          <div className="env-banner">
            Emulators — nothing here touches the live project
          </div>
        )}
        {children}
      </div>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Gate>
          <Shell>
            <Routes>
              <Route path="/" element={<DashboardPage />} />
              <Route path="/destinations" element={<DestinationsListPage />} />
              <Route
                path="/destinations/:id"
                element={<DestinationEditorPage />}
              />
              <Route
                path="/tours"
                element={<PlaceholderPage title="Tours" phase="CMS-2" />}
              />
              <Route
                path="/guides"
                element={<PlaceholderPage title="Local guides" phase="CMS-2" />}
              />
              <Route
                path="/bundles"
                element={
                  <PlaceholderPage title="Offline bundles" phase="CMS-3" />
                }
              />
              <Route
                path="/users"
                element={<PlaceholderPage title="Users & roles" phase="CMS-3" />}
              />
              <Route
                path="/settings"
                element={<PlaceholderPage title="Settings" phase="CMS-4" />}
              />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </Shell>
        </Gate>
      </BrowserRouter>
    </AuthProvider>
  );
}
