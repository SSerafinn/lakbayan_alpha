import type { ReactNode } from "react";
import {
  CircleAlert,
  CircleCheck,
  Info,
  TriangleAlert,
  type LucideIcon,
} from "lucide-react";

/**
 * Status message, in shadcn's Alert shape: an icon rail, a title, a
 * description, and optional trailing actions, driven by a variant.
 *
 * Replaces three ad-hoc boxes — `.warn-bar`, `.error-note` and the readiness
 * panel — that each invented their own padding, colour and weight. Notices that
 * look different for no reason read as unrelated, which is why they felt out of
 * place scattered down the editor.
 *
 * Icons are lucide-react, the same set shadcn uses. They inherit `currentColor`
 * from the variant, so a new variant needs no icon styling — and unlike a text
 * glyph they scale, stay optically centred, and carry no font dependency.
 *
 * Colours come from the semantic container tokens in `design/tokens.json`.
 * Note `warning` uses the gold *container* tint with gold/700 text: gold is an
 * accent here, never a fill behind body copy, and never an action.
 */
export type AlertVariant = "info" | "warning" | "success" | "destructive";

const ICONS: Record<AlertVariant, LucideIcon> = {
  info: Info,
  warning: TriangleAlert,
  success: CircleCheck,
  destructive: CircleAlert,
};

export function Alert({
  variant = "info",
  title,
  children,
  actions,
}: {
  variant?: AlertVariant;
  title: ReactNode;
  /** Optional detail. The title alone is fine for short notices. */
  children?: ReactNode;
  /** Buttons rendered on the trailing edge — Discard, Stay, and so on. */
  actions?: ReactNode;
}) {
  const Icon = ICONS[variant];
  return (
    // `destructive` is assertive so a failed save interrupts a screen reader
    // rather than waiting for a pause; the rest are polite.
    <div
      className={`alert alert-${variant}`}
      role={variant === "destructive" ? "alert" : "status"}
    >
      <Icon className="alert-icon" size={20} aria-hidden="true" />
      <div className="alert-body">
        <p className="alert-title">{title}</p>
        {children && <div className="alert-desc">{children}</div>}
      </div>
      {actions && <div className="alert-actions">{actions}</div>}
    </div>
  );
}
