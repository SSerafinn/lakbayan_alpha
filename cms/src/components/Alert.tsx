import type { ReactNode } from "react";

/**
 * Status message, in shadcn's Alert shape: a bordered container with an icon
 * rail, a title, and a description, driven by a variant.
 *
 * Replaces three ad-hoc boxes — `.warn-bar`, `.error-note` and the readiness
 * panel — that each invented their own padding, colour and weight. Notices that
 * look different for no reason read as unrelated, which is why they felt out of
 * place scattered down the editor.
 *
 * Colours come from the semantic container tokens in `design/tokens.json`.
 * Note `warning` uses the gold *container* tint with gold/700 text: gold is an
 * accent here, never a fill behind body copy, and never an action.
 */
export type AlertVariant = "info" | "warning" | "success" | "destructive";

const ICONS: Record<AlertVariant, string> = {
  info: "i",
  warning: "!",
  success: "✓",
  destructive: "!",
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
  return (
    <div className={`alert alert-${variant}`} role="status">
      <span className="alert-icon" aria-hidden="true">
        {ICONS[variant]}
      </span>
      <div className="alert-body">
        <p className="alert-title">{title}</p>
        {children && <div className="alert-desc">{children}</div>}
      </div>
      {actions && <div className="alert-actions">{actions}</div>}
    </div>
  );
}
