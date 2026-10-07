import { describe, expect, it } from "vitest";
import { editorActions } from "./editor";

describe("editorActions", () => {
  it("offers only Publish on a draft with nothing to save", () => {
    expect(
      editorActions({ status: "draft", dirty: false, isNew: false }),
    ).toEqual({
      state: "All changes saved",
      discard: false,
      secondary: null,
      primary: "publish",
    });
  });

  it("adds Save draft and Discard once a draft has edits", () => {
    expect(
      editorActions({ status: "draft", dirty: true, isNew: false }),
    ).toMatchObject({
      state: "Unsaved changes",
      discard: true,
      secondary: "save-draft",
      primary: "publish",
    });
  });

  it("offers Unpublish, and no Save, on a published place with no edits", () => {
    // The old savebar showed Save here, which wrote nothing.
    expect(
      editorActions({ status: "published", dirty: false, isNew: false }),
    ).toMatchObject({ secondary: "unpublish", primary: null, discard: false });
  });

  it("offers Save beside Unpublish once a published place has edits", () => {
    expect(
      editorActions({ status: "published", dirty: true, isNew: false }),
    ).toMatchObject({ secondary: "unpublish", primary: "save", discard: true });
  });

  it("says a brand-new destination has not been saved, rather than that it has", () => {
    expect(
      editorActions({ status: "draft", dirty: false, isNew: true }).state,
    ).toBe("Not saved yet");
  });
});
