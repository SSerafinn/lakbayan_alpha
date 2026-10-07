import { PageHeader } from "../components/PageHeader";

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
      <PageHeader
        title={title}
        meta={
          <>
            Planned for <strong>{phase}</strong> — see PLAN.md, Track B.
          </>
        }
      />
      <div className="empty">
        <p>Nothing here yet.</p>
      </div>
    </section>
  );
}
