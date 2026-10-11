/**
 * Detecting that someone else saved first.
 *
 * Every admin-written document carries `updatedAt`, a server timestamp set on
 * each write. An editor remembers the value it loaded; a save goes through
 * only if the stored value is still that one. Anything else means another
 * admin saved in between, and writing anyway would silently replace their
 * work with a version that never saw it — which, before this, is exactly what
 * happened: the last save won and the other person was never told.
 *
 * The version is the timestamp in milliseconds. Two saves of one document
 * within the same millisecond are not a case worth designing for.
 */

export type Conflict =
  | {
      kind: "changed";
      /** When the other save happened, in milliseconds. */
      updatedAt: number;
      /** Their uid, where the collection records one. */
      updatedBy: string | null;
    }
  | { kind: "deleted" };

/** A timestamp as a version number. A document never written with one is 0. */
export function versionOf(t?: { toMillis(): number } | null): number {
  return t?.toMillis() ?? 0;
}

/**
 * Null when the save may go ahead; otherwise what happened instead.
 *
 * `allowMissing` is for documents that may legitimately not exist yet — the
 * settings documents, before anyone has saved them. An editor that loaded
 * nothing (version 0) may then create one; one that loaded a document and
 * finds it gone still has a deletion to report.
 */
export function checkVersion(
  expected: number,
  current: {
    exists: boolean;
    updatedAt?: number;
    updatedBy?: string | null;
  },
  { allowMissing = false }: { allowMissing?: boolean } = {},
): Conflict | null {
  if (!current.exists) {
    return allowMissing && expected === 0 ? null : { kind: "deleted" };
  }
  const at = current.updatedAt ?? 0;
  if (at === expected) return null;
  return { kind: "changed", updatedAt: at, updatedBy: current.updatedBy ?? null };
}

/**
 * Who made the other change, as a sentence's subject.
 *
 * The signed-in admin's own uid means another tab or another machine — worth
 * saying, because "someone else" would be untrue and alarming.
 */
export function whoChanged(
  updatedBy: string | null,
  myUid: string | undefined,
  names: Map<string, string>,
): string {
  if (!updatedBy) return "Another admin";
  if (updatedBy === myUid) return "You, in another window,";
  return names.get(updatedBy) || "Another admin";
}
