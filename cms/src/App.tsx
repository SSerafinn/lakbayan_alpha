import type { ReactNode } from "react";
import {
  createBrowserRouter,
  Navigate,
  NavLink,
  Outlet,
  RouterProvider,
} from "react-router-dom";
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
  if (loading) return <div className="boot">Loading…</div>;
  if (!user) return <LoginPage />;
  if (!isAdmin) return <NotAuthorised />;
  return <>{children}</>;
}

function Shell() {
  const { user, signOut } = useAuth();
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="auth-mark small">L</span>
          <strong>Lakbayan</strong>
        </div>
        <nav>
          <NavLink to="/" end>
            Dashboard
          </NavLink>
          <NavLink to="/destinations">Destinations</NavLink>
          <NavLink to="/tours">Tours</NavLink>
          <NavLink to="/guides">Local guides</NavLink>
          <NavLink to="/bundles">Offline bundles</NavLink>
          <NavLink to="/users">Users &amp; roles</NavLink>
          <NavLink to="/settings">Settings</NavLink>
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
        <Outlet />
      </div>
    </div>
  );
}

function GatedShell() {
  return (
    <Gate>
      <Shell />
    </Gate>
  );
}

/**
 * A **data router**, not `<BrowserRouter>`.
 *
 * That is deliberate: `useBlocker` only works under a data router, and the
 * editor needs it to stop an in-app navigation discarding unsaved edits.
 * `beforeunload` alone covers closing the tab but not clicking a sidebar link,
 * which is the far more likely way to lose work.
 */
const router = createBrowserRouter([
  {
    path: "/",
    element: <GatedShell />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: "destinations", element: <DestinationsListPage /> },
      { path: "destinations/:id", element: <DestinationEditorPage /> },
      {
        path: "tours",
        element: <PlaceholderPage title="Tours" phase="CMS-2" />,
      },
      {
        path: "guides",
        element: <PlaceholderPage title="Local guides" phase="CMS-2" />,
      },
      {
        path: "bundles",
        element: <PlaceholderPage title="Offline bundles" phase="CMS-3" />,
      },
      {
        path: "users",
        element: <PlaceholderPage title="Users & roles" phase="CMS-3" />,
      },
      {
        path: "settings",
        element: <PlaceholderPage title="Settings" phase="CMS-4" />,
      },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);

export default function App() {
  return (
    <AuthProvider>
      <RouterProvider router={router} />
    </AuthProvider>
  );
}
