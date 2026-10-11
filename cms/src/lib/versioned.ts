import {
  runTransaction,
  type DocumentReference,
  type Transaction,
} from "firebase/firestore";
import { db } from "./firebase";
import { checkVersion, type Conflict } from "../types/conflict";

/** Thrown by a checked write that found the document changed or gone. */
export class ConflictError extends Error {
  readonly conflict: Conflict;
  constructor(conflict: Conflict) {
    super(
      conflict.kind === "deleted"
        ? "It was deleted while you were editing."
        : "Someone else saved it while you were editing.",
    );
    this.name = "ConflictError";
    this.conflict = conflict;
  }
}

/**
 * Write only if the document is still the version the editor loaded.
 *
 * A transaction rather than a read followed by a write: between the two, a
 * second admin's save could land, which is the race this exists to close. The
 * transaction reads, checks and writes as one step, and retries itself if the
 * document moves under it — at which point the check fails, as it should.
 */
export async function writeIfUnchanged(
  ref: DocumentReference,
  expected: number,
  write: (tx: Transaction) => void,
): Promise<void> {
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const conflict = checkVersion(expected, {
      exists: snap.exists(),
      updatedAt: data?.updatedAt?.toMillis?.(),
      updatedBy: data?.updatedBy ?? null,
    });
    if (conflict) throw new ConflictError(conflict);
    write(tx);
  });
}
