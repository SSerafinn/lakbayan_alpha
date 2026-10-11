import { useAuth } from "../auth/auth-context";
import { relativeTime } from "../types/dashboard";
import { whoChanged, type Conflict } from "../types/conflict";
import { Dialog } from "./Dialog";
import { useAdminNames } from "./useAdminNames";

/**
 * What a save that found someone else's newer version says, and offers.
 *
 * Three ways out, none of them silent: take their version and lose these
 * edits, keep these and replace theirs, or go back to editing and decide
 * later. Escape and the backdrop mean the last one — the only choice that
 * throws nothing away.
 */
export function ConflictDialog({
  conflict,
  noun,
  busy,
  onLoadTheirs,
  onOverwrite,
  onDiscard,
  onDismiss,
}: {
  conflict: Conflict | null;
  /** "destination", "tour", "guide" — what was being edited. */
  noun: string;
  busy?: boolean;
  onLoadTheirs: () => void;
  onOverwrite: () => void;
  /** Deleted case only: give up the edits and close or leave. */
  onDiscard: () => void;
  onDismiss: () => void;
}) {
  const { user } = useAuth();
  const by = conflict?.kind === "changed" ? conflict.updatedBy : null;
  const names = useAdminNames(Boolean(by && by !== user?.uid));

  if (conflict?.kind === "deleted") {
    return (
      <Dialog
        open
        onDismiss={onDismiss}
        variant="destructive"
        title={`This ${noun} was deleted`}
        actions={
          <>
            <button className="btn-quiet" onClick={onDismiss}>
              Keep this page open
            </button>
            <button className="btn-secondary" onClick={onDiscard}>
              Discard my changes
            </button>
          </>
        }
      >
        Another admin deleted it while you were editing. Your changes are still
        on screen, but there is nothing left to save them to — copy anything
        you need before you go.
      </Dialog>
    );
  }

  const who = whoChanged(by, user?.uid, names);
  const when =
    conflict?.kind === "changed" && conflict.updatedAt
      ? relativeTime(conflict.updatedAt, Date.now())
      : "";

  return (
    <Dialog
      open={conflict !== null}
      onDismiss={onDismiss}
      variant="warning"
      title={`Someone else saved this ${noun}`}
      actions={
        <>
          <button className="btn-quiet" onClick={onDismiss} disabled={busy}>
            Keep editing
          </button>
          <button
            className="btn-secondary"
            onClick={onLoadTheirs}
            disabled={busy}
          >
            Load their version
          </button>
          <button
            className="btn-secondary"
            onClick={onOverwrite}
            disabled={busy}
          >
            Overwrite with mine
          </button>
        </>
      }
    >
      {who} saved changes {when} while you were editing. Saving yours now would
      replace them. Load their version to start again from it, or overwrite if
      you are sure yours should win.
    </Dialog>
  );
}
