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
import { GuidesPage } from "./pages/GuidesPage";
import { PlaceholderPage } from "./pages/PlaceholderPage";
import { useEmulators } from "./lib/firebase";
import { ToastProvider } from "./components/Toast";
import {
  LayoutDashboard,
  MapPin,
  Package,
  Route,
  Settings,
  ShieldCheck,
  UsersRound,
  type LucideIcon,
} from "lucide-react";

/**
 * Sidebar sections, in the wireframe's order.
 *
 * Data rather than seven hand-written links: adding a section is one entry,
 * and the icon travels with it instead of being wired up separately.
 */
const NAV: { to: string; label: string; icon: LucideIcon; end?: boolean }[] = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/destinations", label: "Destinations", icon: MapPin },
  { to: "/tours", label: "Tours", icon: Route },
  { to: "/guides", label: "Local guides", icon: UsersRound },
  { to: "/bundles", label: "Offline bundles", icon: Package },
  { to: "/users", label: "Users & roles", icon: ShieldCheck },
  { to: "/settings", label: "Settings", icon: Settings },
];

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
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end}>
              <Icon size={18} aria-hidden="true" />
              {label}
            </NavLink>
          ))}
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
      { path: "guides", element: <GuidesPage /> },
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
    <ToastProvider>
      <AuthProvider>
        <RouterProvider router={router} />
      </AuthProvider>
    </ToastProvider>
  );
}
