import { useEffect, useRef, type ReactNode } from "react";
import {
  CircleAlert,
  CircleCheck,
  Info,
  TriangleAlert,
  type LucideIcon,
} from "lucide-react";
import type { AlertVariant } from "./Alert";

const ICONS: Record<AlertVariant, LucideIcon> = {
  info: Info,
  warning: TriangleAlert,
  success: CircleCheck,
  destructive: CircleAlert,
};

/**
 * Modal dialogue, shadcn's Alert Dialog shape: icon, title, description,
 * footer actions.
 *
 * Built on the native `<dialog>` element with `showModal()`, which gives focus
 * trapping, Escape handling, background inertness, `::backdrop`, and top-layer
 * stacking for free. Hand-rolled modals get all five of those wrong, and the
 * focus trap in particular is where they hurt keyboard and screen reader users.
 *
 * Reserve this for genuine decision points — something that must be answered
 * before anything else can happen. Ambient status belongs in [Alert]: a
 * dialogue that interrupts someone mid-sentence to say "unsaved changes" is
 * worse than a banner, not better.
 */
export function Dialog({
  open,
  onDismiss,
  variant = "info",
  title,
  children,
  actions,
}: {
  open: boolean;
  /**
   * Escape or a backdrop click. Should map to the **safe** choice — for a
   * discard-confirmation that is "stay", never "discard".
   */
  onDismiss: () => void;
  variant?: AlertVariant;
  title: ReactNode;
  children?: ReactNode;
  actions?: ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const Icon = ICONS[variant];

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (open && !el.open) el.showModal();
    if (!open && el.open) el.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      className={`dialog dialog-${variant}`}
      // Escape fires `cancel`. Preventing the default close and routing through
      // onDismiss keeps React the single source of truth for whether it is
      // open — otherwise the element closes itself and state says otherwise.
      onCancel={(e) => {
        e.preventDefault();
        onDismiss();
      }}
      // A backdrop click lands on the dialog element itself; a click inside
      // lands on a child.
      onClick={(e) => {
        if (e.target === ref.current) onDismiss();
      }}
    >
      <div className="dialog-head">
        <Icon className="dialog-icon" size={22} aria-hidden="true" />
        <h2>{title}</h2>
      </div>
      {children && <div className="dialog-body">{children}</div>}
      {actions && <div className="dialog-actions">{actions}</div>}
    </dialog>
  );
}
