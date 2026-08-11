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
  children,
}: {
  title: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <section className="fsection">
      <header>
        <h2>{title}</h2>
        {hint && <p className="hint">{hint}</p>}
      </header>
      <div className="fgrid">{children}</div>
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
  on,
  onChange,
}: {
  label: string;
  on: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="toggle">
      <input
        type="checkbox"
        checked={on}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span>{label}</span>
    </label>
  );
}
