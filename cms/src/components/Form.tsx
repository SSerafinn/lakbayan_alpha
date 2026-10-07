import type { ReactNode } from "react";

/**
 * The form primitives every editor tab is built from.
 *
 * They started inside `DestinationEditorPage`, which was fine while it was the
 * only editor. The Audio Guide tab needs the same label, hint and error
 * treatment, and a tab importing them from a page is backwards — a page is
 * where things are assembled, not where shared parts live.
 */

/** Groups related fields so a tab reads as sections, not a wall of inputs. */
export function Section({
  title,
  hint,
  action,
  single,
  children,
}: {
  title: string;
  hint?: string;
  /** A control for the whole section, on the heading's trailing edge. */
  action?: ReactNode;
  /** One column instead of two — for the editor's narrow right-hand rail. */
  single?: boolean;
  children: ReactNode;
}) {
  return (
    <section className="fsection">
      <header className={action ? "split" : undefined}>
        <div>
          <h2>{title}</h2>
          {hint && <p className="hint">{hint}</p>}
        </div>
        {action}
      </header>
      <div className={single ? "fgrid one" : "fgrid"}>{children}</div>
    </section>
  );
}

export function Field({
  label,
  children,
  hint,
  error,
  required,
  wide,
}: {
  label: string;
  children: ReactNode;
  hint?: string;
  error?: string;
  required?: boolean;
  wide?: boolean;
}) {
  return (
    <div className={wide ? "f wide" : "f"}>
      <label>
        {label}
        {required && <span className="req">*</span>}
      </label>
      {children}
      {error ? (
        <span className="field-error">{error}</span>
      ) : hint ? (
        <span className="hint">{hint}</span>
      ) : null}
    </div>
  );
}

export function Toggle({
  label,
  hint,
  on,
  onChange,
}: {
  label: string;
  /** What switching it on does, in the app's terms — one short line. */
  hint?: string;
  on: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="toggle">
      <input
        type="checkbox"
        role="switch"
        checked={on}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span className="toggle-text">
        {label}
        {hint && <span className="hint">{hint}</span>}
      </span>
    </label>
  );
}
