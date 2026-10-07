import type { Status } from "./destination";

/**
 * Which actions the destination editor offers, by status and unsaved state.
 *
 * A table rather than conditions spread through the JSX, because the old
 * savebar showed Save as draft beside Publish on a document with nothing to
 * save, and Save on a published one with no changes — buttons that did
 * nothing visible. Every button here does something when pressed.
 *
 *   draft, clean      → Publish
 *   draft, dirty      → Save draft, Publish
 *   published, clean  → Unpublish
 *   published, dirty  → Unpublish, Save
 */
export type EditorActions = {
  /** The line beside the buttons. */
  state: string;
  discard: boolean;
  secondary: "unpublish" | "save-draft" | null;
  primary: "publish" | "save" | null;
};

export function editorActions({
  status,
  dirty,
  isNew,
}: {
  status: Status;
  dirty: boolean;
  isNew: boolean;
}): EditorActions {
  const state = dirty
    ? "Unsaved changes"
    : isNew
      ? "Not saved yet"
      : "All changes saved";

  if (status === "published") {
    return {
      state,
      discard: dirty,
      secondary: "unpublish",
      primary: dirty ? "save" : null,
    };
  }
  return {
    state,
    discard: dirty,
    secondary: dirty ? "save-draft" : null,
    primary: "publish",
  };
}
