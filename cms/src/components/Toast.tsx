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
          <ToastItem key={t.id} toast={t} onDismiss={() => dismiss(t.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

function ToastItem({
  toast,
  onDismiss,
}: {
  toast: Toast;
  onDismiss: () => void;
}) {
  const Icon = ICONS[toast.variant];

  useEffect(() => {
    const timer = setTimeout(onDismiss, TTL[toast.variant]);
    return () => clearTimeout(timer);
  }, [onDismiss, toast.variant]);

  return (
    <div className={`toast toast-${toast.variant}`}>
      <Icon className="toast-icon" size={18} aria-hidden="true" />
      <div className="toast-body">
        <p className="toast-title">{toast.title}</p>
        {toast.description && <p className="toast-desc">{toast.description}</p>}
      </div>
      <button className="toast-x" onClick={onDismiss} aria-label="Dismiss">
        <X size={14} aria-hidden="true" />
      </button>
    </div>
  );
}
