import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  CircleAlert,
  CircleCheck,
  Info,
  TriangleAlert,
  X,
  type LucideIcon,
} from "lucide-react";
import type { AlertVariant } from "./Alert";
import { ToastContext, type ToastApi, type ToastInput } from "./toast-context";

const ICONS: Record<AlertVariant, LucideIcon> = {
  info: Info,
  warning: TriangleAlert,
  success: CircleCheck,
  destructive: CircleAlert,
};

type Toast = ToastInput & { id: number };

/** How long before a toast fades. Failures linger — they carry information you
 *  may need to act on, and re-triggering them means redoing the action. */
const TTL: Record<AlertVariant, number> = {
  success: 3000,
  info: 4000,
  warning: 6000,
  destructive: 8000,
};

/**
 * Transient notifications in the corner, in the shape shadcn's Sonner uses.
 *
 * The division of labour matters, and getting it wrong is what made the editor
 * feel cluttered:
 *
 * - **Toast** — something *happened*. Saved, published, upload failed. Fades.
 * - **Savebar** — persistent *state*. Unsaved changes, what is left to publish.
 * - **Dialog** — a *decision* that blocks everything until answered.
 *
 * A persistent condition in a toast disappears before it is resolved; an event
 * in a banner sits there long after it stopped being true.
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);
  const nextId = useRef(1);

  const toast = useCallback((t: ToastInput) => {
    const id = nextId.current++;
    setItems((prev) => [...prev, { ...t, id }]);
  }, []);

  const api = useMemo<ToastApi>(
    () => ({
      toast,
      success: (title, description) =>
        toast({ variant: "success", title, description }),
      error: (title, description) =>
        toast({ variant: "destructive", title, description }),
    }),
    [toast],
  );

  const dismiss = useCallback(
    (id: number) => setItems((prev) => prev.filter((t) => t.id !== id)),
    [],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      {/* aria-live so a screen reader announces these; they are the only
          confirmation that a save happened. */}
      <div className="toasts" role="region" aria-live="polite">
        {items.map((t) => (
          // `dismiss` rather than an inline arrow: a new function identity each
          // render would restart the auto-dismiss timer on every keystroke, so
          // a toast raised while typing would never go away.
          <ToastItem key={t.id} toast={t} onDismiss={dismiss} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

/** The least a toast with an action (Undo) stays up. */
const ACTION_TTL = 8000;

/** Must match the toast-out animation in app.css. */
const EXIT_MS = 160;

function ToastItem({
  toast,
  onDismiss,
}: {
  toast: Toast;
  onDismiss: (id: number) => void;
}) {
  const Icon = ICONS[toast.variant];
  const [leaving, setLeaving] = useState(false);

  // Two stages, because a toast removed from the DOM the instant its timer
  // fires cannot animate out — it just vanishes. Mark it leaving, let the
  // animation play, then unmount.
  // One with an action stays longer: three seconds is enough to read
  // "Saved", and not enough to notice a mistake and reach for Undo.
  const ttl = toast.action
    ? Math.max(TTL[toast.variant], ACTION_TTL)
    : TTL[toast.variant];
  useEffect(() => {
    const timer = setTimeout(() => setLeaving(true), ttl);
    return () => clearTimeout(timer);
  }, [ttl]);

  useEffect(() => {
    if (!leaving) return;
    const timer = setTimeout(() => onDismiss(toast.id), EXIT_MS);
    return () => clearTimeout(timer);
  }, [leaving, onDismiss, toast.id]);

  return (
    <div className={`toast toast-${toast.variant}${leaving ? " leaving" : ""}`}>
      <Icon className="toast-icon" size={18} aria-hidden="true" />
      <div className="toast-body">
        <p className="toast-title">{toast.title}</p>
        {toast.description && <p className="toast-desc">{toast.description}</p>}
      </div>
      {toast.action && (
        <button
          className="toast-action"
          onClick={() => {
            toast.action!.onClick();
            setLeaving(true);
          }}
        >
          {toast.action.label}
        </button>
      )}
      <button
        className="toast-x"
        onClick={() => setLeaving(true)}
        aria-label="Dismiss"
      >
        <X size={14} aria-hidden="true" />
      </button>
    </div>
  );
}
