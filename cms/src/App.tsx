import { Fragment, useState, type ReactNode } from "react";
import {
  createBrowserRouter,
  Link,
  Navigate,
  NavLink,
  Outlet,
  RouterProvider,
  useLocation,
} from "react-router-dom";
import { CrumbContext } from "./components/crumb-context";
import { AuthProvider } from "./auth/AuthProvider";
import { useAuth } from "./auth/auth-context";
import { LoginPage, NotAuthorised } from "./auth/LoginPage";
import { BundlesPage } from "./pages/BundlesPage";
import { DashboardPage } from "./pages/DashboardPage";
import { DestinationsListPage } from "./pages/DestinationsListPage";
import { DestinationEditorPage } from "./pages/DestinationEditorPage";
import { GuidesPage } from "./pages/GuidesPage";
import { PlaceholderPage } from "./pages/PlaceholderPage";
import { ToursPage } from "./pages/ToursPage";
import { UsersPage } from "./pages/UsersPage";
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

type NavItem = {
  to: string;
  label: string;
  icon: LucideIcon;
  end?: boolean;
  /** Starts a group, named by this label, in the sidebar. */
  group?: string;
};

/**
 * Sidebar sections, in the wireframe's order.
 *
 * Data rather than seven hand-written links: adding a section is one entry,
 * and the icon travels with it instead of being wired up separately. Grouped
 * by what the work is — writing content, getting it onto phones, running the
 * CMS — so the list reads as three jobs rather than seven peers.
 */
const NAV: NavItem[] = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/destinations", label: "Destinations", icon: MapPin, group: "Content" },
  { to: "/tours", label: "Tours", icon: Route },
  { to: "/guides", label: "Local guides", icon: UsersRound },
  {
    to: "/bundles",
    label: "Offline bundles",
    icon: Package,
    group: "Distribution",
  },
  { to: "/users", label: "Users & roles", icon: ShieldCheck, group: "Admin" },
  { to: "/settings", label: "Settings", icon: Settings },
];

/** The section a path belongs to, for the top bar. */
function sectionFor(pathname: string): NavItem | undefined {
  return NAV.find((n) =>
    n.end ? pathname === n.to : pathname === n.to || pathname.startsWith(`${n.to}/`),
  );
}

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
  const { pathname } = useLocation();
  const section = sectionFor(pathname);
  // Set by a screen showing one item (the destination editor), so the bar can
  // name it. Cleared by that screen when it unmounts.
  const [crumb, setCrumb] = useState<string | null>(null);

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="auth-mark small">L</span>
          Lakbayan
        </div>
        <nav aria-label="Sections">
          {NAV.map(({ to, label, icon: Icon, end, group }) => (
            <Fragment key={to}>
              {group && <div className="nav-group">{group}</div>}
              <NavLink to={to} end={end}>
                <Icon size={18} aria-hidden="true" />
                {label}
              </NavLink>
            </Fragment>
          ))}
        </nav>
        <div className="sidebar-foot">
          <span className="avatar" aria-hidden="true">
            {user?.email?.[0] ?? "?"}
          </span>
          <div className="sidebar-user">
            <strong title={user?.email ?? undefined}>{user?.email}</strong>
            <span className="hint">Administrator</span>
          </div>
        </div>
        <button className="btn-quiet sm" onClick={() => void signOut()}>
          Sign out
        </button>
      </aside>
      <div className="content">
        <div className="topbar">
          <nav className="crumbs" aria-label="Breadcrumb">
            {crumb && section ? (
              <>
                <Link to={section.to}>{section.label}</Link>
                <span aria-hidden="true">/</span>
                <span aria-current="page">{crumb}</span>
              </>
            ) : (
              <span aria-current="page">{section?.label}</span>
            )}
          </nav>
          {useEmulators && (
            <span
              className="env-pill"
              title="Nothing here touches the live project"
            >
              Emulators
            </span>
          )}
        </div>
        <CrumbContext.Provider value={setCrumb}>
          <Outlet />
        </CrumbContext.Provider>
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
      { path: "tours", element: <ToursPage /> },
      { path: "guides", element: <GuidesPage /> },
      { path: "bundles", element: <BundlesPage /> },
      { path: "users", element: <UsersPage /> },
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
