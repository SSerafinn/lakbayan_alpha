/**
 * Stands in for a screen that is planned but not built.
 *
 * Naming the phase is deliberate: an empty screen with no explanation reads as
 * a bug, and someone will file it.
 */
export function PlaceholderPage({
  title,
  phase,
}: {
  title: string;
  phase: string;
}) {
  return (
    <section className="page">
      <header className="page-head">
        <h1>{title}</h1>
        <p className="hint">
          Planned for <strong>{phase}</strong> — see PLAN.md, Track B.
        </p>
      </header>
      <div className="empty">
        <p>Nothing here yet.</p>
      </div>
    </section>
  );
}
