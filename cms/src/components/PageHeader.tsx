import type { ReactNode } from "react";

/**
 * The top of every screen: title and status on the left, the screen's
 * actions on the right, one line of facts beneath.
 *
 * One component rather than markup repeated per page, because the repeated
 * version drifted — six of eight pages had picked up a class that centred the
 * title and stacked the primary button under it, while the dashboard stayed
 * left-aligned. Polaris puts the page's actions in this spot for the same
 * reason the CMS now does: they are where the eye already is.
 */
export function PageHeader({
  title,
  badge,
  meta,
  actions,
}: {
  title: ReactNode;
  /** Beside the title — a status, never an action. */
  badge?: ReactNode;
  /** Counts or facts about what is on the page. */
  meta?: ReactNode;
  /** At most one primary button; the rest secondary or quiet. */
  actions?: ReactNode;
}) {
  return (
    <header className="page-head">
      <div className="page-title">
        <h1>{title}</h1>
        {badge}
      </div>
      {actions ? <div className="page-actions">{actions}</div> : <span />}
      {meta && <p className="page-meta">{meta}</p>}
    </header>
  );
}
