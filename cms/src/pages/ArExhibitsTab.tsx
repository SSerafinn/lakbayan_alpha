import { useRef, useState, type Dispatch, type SetStateAction } from "react";
import {
  ChevronDown,
  ChevronUp,
  ImagePlus,
  Mic,
  Printer,
  ScanLine,
  Trash2,
} from "lucide-react";
import { AudioPreview } from "../components/AudioPreview";
import { Field } from "../components/Form";
import { ImageThumb } from "../components/ImageThumb";
import { useToast } from "../components/toast-context";
import {
  newExhibitId,
  uploadExhibitAudio,
  uploadMarker,
} from "../lib/exhibits";
import { ImageRejectedError } from "../lib/image";
import { useImageAspect } from "../lib/labels";
import { AUDIO_FORMATS, recordingProblem } from "../types/media";
import {
  countExhibitProblems,
  emptyExhibit,
  exhibitProblems,
  MAX_MARKER_WIDTH_M,
  MIN_MARKER_WIDTH_M,
  toCentimetres,
  toMetres,
  type ExhibitDraft,
} from "../types/exhibit";
import {
  LABEL_SIZE_ORDER,
  LABEL_SIZES,
  labelMarkerWidthM,
  labelSizeOf,
  printedPicture,
} from "../types/label";

/** What makes a marker the camera can find, at the point of choosing one. */
const MARKER_GUIDANCE =
  "A photo of the exhibit or its placard, taken straight on: flat, well lit and full of detail. Plain, glossy or repetitive surfaces scan poorly. For a Lakbayan label, any clear photo of the exhibit will do: the label prints it.";

/** Opens the labels page in its own tab, for every exhibit or some. */
function openLabels(destinationId: string, ids?: string[]) {
  const query = ids ? `?ids=${ids.map(encodeURIComponent).join(",")}` : "";
  window.open(
    `/print/labels/${encodeURIComponent(destinationId)}${query}`,
    "_blank",
    "noopener",
  );
}

/** Why Print is not on offer yet, or null when it is. */
function printBlock(destinationId: string | null, printable: boolean) {
  if (!destinationId) return "Save the destination first.";
  if (!printable) return "Save your changes first: labels print what is saved.";
  return null;
}

/**
 * Admin wireframe screen 6 — AR content for a museum (D-18).
 *
 * Built like the audio guide beside it, and for the same reasons: nothing here
 * writes to Firestore. Edits go back to the editor page through `onChange` and
 * land with the destination's own save, so the savebar, Ctrl+S, Discard and
 * the unsaved-changes guard cover exhibits too — and that save is what sets
 * `hasAR`, which has no switch of its own.
 *
 * Files go to Storage the moment they are picked, because a draft cannot hold
 * one. Unlike the audio guide, nothing here ever deletes one: Remove and
 * Replace change the draft alone, and a file the saved version used is
 * deleted after the save that drops it (`planExhibitSave`). Discard therefore
 * always finds the saved marker where it left it.
 */
export function ArExhibitsTab({
  destinationId,
  destinationName,
  exhibits,
  onChange,
  onSaveFirst,
  printable,
}: {
  /** Null until the destination has been written once. */
  destinationId: string | null;
  destinationName: string;
  exhibits: ExhibitDraft[];
  /**
   * Saved, with nothing unsaved: labels print from Firestore, so a label
   * printed now shows what the phones will scan for.
   */
  printable: boolean;
  /**
   * Takes an updater as well as a list. A marker resolves seconds after it was
   * picked, and patching the list as it stood then would undo whatever was
   * typed into another field in the meantime.
   */
  onChange: Dispatch<SetStateAction<ExhibitDraft[]>>;
  /** Creates the draft document and resolves to its id, or null if it failed. */
  onSaveFirst: () => Promise<string | null>;
}) {
  const { unmarked } = countExhibitProblems(exhibits);

  function update(id: string, patch: Partial<ExhibitDraft>) {
    onChange((list) =>
      list.map((e) => (e.id === id ? { ...e, ...patch } : e)),
    );
  }

  function add() {
    onChange((list) => [...list, emptyExhibit(newExhibitId())]);
  }

  /** One place up or down. Buttons rather than dragging, as on the guide. */
  function move(index: number, by: -1 | 1) {
    onChange((list) => {
      const to = index + by;
      if (to < 0 || to >= list.length) return list;
      const next = [...list];
      [next[index], next[to]] = [next[to], next[index]];
      return next;
    });
  }

  return (
    <div className="segments">
      <div className="row">
        <div>
          <h2 className="segments-title">AR exhibits</h2>
          <p className="hint">
            What the camera recognises
            {destinationName ? ` at ${destinationName}` : ""}. Pointing a phone
            at an exhibit's marker opens its card, story and narration; phones
            without AR list the exhibits in this order.
          </p>
        </div>
        <span className="spacer" />
        {exhibits.length > 0 && (
          <button
            className="btn-quiet"
            disabled={printBlock(destinationId, printable) !== null}
            title={printBlock(destinationId, printable) ?? undefined}
            onClick={() => destinationId && openLabels(destinationId)}
          >
            <Printer size={16} aria-hidden="true" />
            Print labels
          </button>
        )}
        <button className="btn-secondary" onClick={add}>
          Add exhibit
        </button>
      </div>

      {exhibits.length === 0 ? (
        <div className="empty">
          <ScanLine size={24} aria-hidden="true" />
          <p>
            No exhibits yet. Add one for each object the camera should
            recognise — the AR badge appears in the app once one has a marker.
          </p>
          <button className="btn-secondary" onClick={add}>
            Add the first exhibit
          </button>
        </div>
      ) : (
        <>
          {unmarked > 0 && (
            <p className="hint">
              {unmarked} exhibit{unmarked === 1 ? " is" : "s are"} not ready
              for the camera. The destination will not publish until every
              exhibit has a marker photo and its width.
            </p>
          )}
          <ol className="segment-list">
            {exhibits.map((exhibit, i) => (
              <ExhibitRow
                key={exhibit.id}
                exhibit={exhibit}
                index={i}
                count={exhibits.length}
                destinationId={destinationId}
                printable={printable}
                onPatch={(patch) => update(exhibit.id, patch)}
                onMove={(by) => move(i, by)}
                onRemove={() =>
                  onChange((list) => list.filter((e) => e.id !== exhibit.id))
                }
                onSaveFirst={onSaveFirst}
              />
            ))}
          </ol>
        </>
      )}
    </div>
  );
}

function ExhibitRow({
  exhibit,
  index,
  count,
  destinationId,
  onPatch,
  onMove,
  onRemove,
  onSaveFirst,
  printable,
}: {
  exhibit: ExhibitDraft;
  index: number;
  count: number;
  destinationId: string | null;
  printable: boolean;
  onPatch: (patch: Partial<ExhibitDraft>) => void;
  onMove: (by: -1 | 1) => void;
  onRemove: () => void;
  onSaveFirst: () => Promise<string | null>;
}) {
  const markerInput = useRef<HTMLInputElement>(null);
  const audioInput = useRef<HTMLInputElement>(null);
  // One at a time per row: for a destination not yet saved, each upload
  // would otherwise create the draft it is uploading to.
  const [uploading, setUploading] = useState<"marker" | "audio" | null>(null);
  const toast = useToast();
  const problems = exhibitProblems(exhibit);
  const markerReady = !problems.marker && !problems.width;
  const n = index + 1;
  // The marker's shape decides how wide a label prints it, so a label size
  // can be chosen only once the photo has loaded.
  const aspect = useImageAspect(exhibit.markerPath || undefined);
  const labelSize =
    aspect && exhibit.markerWidthM
      ? labelSizeOf(exhibit.markerWidthM, aspect)
      : null;
  const printBlocked =
    printBlock(destinationId, printable) ??
    (labelSize ? null : "Choose a label size first.");

  async function onPickMarker(files: FileList | null) {
    const file = files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      toast.toast({
        variant: "warning",
        title: "That file was not uploaded",
        description: "A marker has to be a photo.",
      });
      return;
    }

    setUploading("marker");
    try {
      // Same bargain as photos: rather than blocking with "save it first",
      // create the draft destination silently so the upload has somewhere to
      // go. See the note in MediaTab.
      const target = destinationId ?? (await onSaveFirst());
      if (!target) return; // The save failed and already reported why.

      // A new name each time, so the marker it replaces is untouched: the
      // saved exhibit points at that one until the save deletes it.
      onPatch({ markerPath: await uploadMarker(target, exhibit.id, file) });
      toast.success("Marker uploaded", "Save to keep it.");
    } catch (err) {
      if (err instanceof ImageRejectedError) {
        toast.toast({
          variant: "warning",
          title: "That photo was not uploaded",
          description: err.message,
        });
      } else {
        toast.error(
          "Upload failed",
          err instanceof Error ? err.message : String(err),
        );
      }
    } finally {
      setUploading(null);
      if (markerInput.current) markerInput.current.value = "";
    }
  }

  async function onPickAudio(files: FileList | null) {
    const file = files?.[0];
    if (!file) return;

    // storage.rules refuses it anyway; this says why, and what to do.
    const problem = recordingProblem(file);
    if (problem) {
      toast.toast({ variant: "warning", ...problem });
      return;
    }

    setUploading("audio");
    try {
      const target = destinationId ?? (await onSaveFirst());
      if (!target) return;

      // The recording it replaces is not deleted here, unlike on the guide:
      // one the saved exhibit uses goes only after the save that drops it.
      // (A recording of the same format lands on the same path — the schema
      // names narration after the exhibit — and so replaces it in place.)
      onPatch({
        audioUrl: await uploadExhibitAudio(target, exhibit.id, file),
      });
      toast.success("Recording uploaded", "Save to keep it.");
    } catch (err) {
      toast.error(
        "Upload failed",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setUploading(null);
      if (audioInput.current) audioInput.current.value = "";
    }
  }

  return (
    <li className="segment">
      <div className="segment-head">
        <span className="segment-no">{n}</span>
        <input
          className="segment-title"
          value={exhibit.title}
          onChange={(e) => onPatch({ title: e.target.value })}
          placeholder="Exhibit title — e.g. The Callao Man replica"
          aria-label={`Title of exhibit ${n}`}
        />
        <span className={markerReady ? "badge ok" : "badge warn"}>
          {markerReady
            ? "Scannable"
            : problems.marker
              ? "No marker"
              : "No width"}
        </span>
        <div className="segment-order">
          <button
            className="btn-quiet sm"
            onClick={() => onMove(-1)}
            disabled={index === 0}
            aria-label={`Move exhibit ${n} earlier`}
          >
            <ChevronUp size={16} aria-hidden="true" />
          </button>
          <button
            className="btn-quiet sm"
            onClick={() => onMove(1)}
            disabled={index === count - 1}
            aria-label={`Move exhibit ${n} later`}
          >
            <ChevronDown size={16} aria-hidden="true" />
          </button>
        </div>
        {/* No confirmation, as on the guide: removal only reaches Firestore
            on save, its files go only after that, and Discard puts it back. */}
        <button
          className="btn-quiet sm"
          onClick={onRemove}
          aria-label={`Remove exhibit ${n}`}
        >
          <Trash2 size={16} aria-hidden="true" />
        </button>
      </div>

      <div className="fgrid">
        <Field
          label="Description"
          hint="One line, on the card that appears when the camera finds it."
          wide
        >
          <input
            value={exhibit.description ?? ""}
            onChange={(e) => onPatch({ description: e.target.value })}
          />
        </Field>

        <Field
          label="Story"
          hint="The exhibit sheet, opened from the card. Leave a blank line between paragraphs."
          wide
        >
          <textarea
            rows={6}
            value={exhibit.story ?? ""}
            onChange={(e) => onPatch({ story: e.target.value })}
            placeholder="What it is, where it came from, why it matters."
          />
        </Field>

        <Field label="Marker photo" required hint={MARKER_GUIDANCE}>
          <div className="segment-audio">
            <button
              className="btn-secondary sm"
              disabled={uploading !== null}
              onClick={() => markerInput.current?.click()}
            >
              <ImagePlus size={14} aria-hidden="true" />
              {uploading === "marker"
                ? "Uploading…"
                : exhibit.markerPath
                  ? "Replace"
                  : "Upload"}
            </button>
            {exhibit.markerPath && (
              <button
                className="btn-quiet sm"
                onClick={() => onPatch({ markerPath: "" })}
              >
                Remove
              </button>
            )}
            <input
              ref={markerInput}
              type="file"
              accept="image/*"
              hidden
              onChange={(e) => void onPickMarker(e.target.files)}
            />
          </div>
          {/* Keyed on the path so a replacement starts from a blank thumb,
              not the previous marker or its "unavailable". */}
          {exhibit.markerPath && (
            <ImageThumb
              key={exhibit.markerPath}
              path={exhibit.markerPath}
              className="marker-preview"
            />
          )}
        </Field>

        <Field
          label="Marker width (cm)"
          required
          // A wrong width says so as it is typed; a missing one is the
          // badge's and the checklist's to mention, not a red line on arrival.
          error={exhibit.markerWidthM ? problems.width : undefined}
          hint="Set for you by a Lakbayan label below. For the exhibit's own placard, measure it edge to edge — on the placard, not on the photo."
        >
          <input
            type="number"
            inputMode="decimal"
            min={toCentimetres(MIN_MARKER_WIDTH_M)}
            max={toCentimetres(MAX_MARKER_WIDTH_M)}
            step={0.1}
            // Stored in metres (`markerWidthM`); nobody measures a placard in
            // them. 0 is "not measured yet" and shows as an empty field.
            value={
              exhibit.markerWidthM ? toCentimetres(exhibit.markerWidthM) : ""
            }
            onChange={(e) => {
              const cm = e.target.valueAsNumber;
              onPatch({ markerWidthM: Number.isFinite(cm) ? toMetres(cm) : 0 });
            }}
            placeholder="e.g. 30"
          />
        </Field>

        <Field
          label="Lakbayan label"
          hint={
            !exhibit.markerPath
              ? "Upload a marker photo first."
              : !aspect
                ? "Reading the photo…"
                : labelSize
                  ? `The ${LABEL_SIZES[labelSize].name} label prints this photo ${toCentimetres(labelMarkerWidthM(aspect, labelSize))} cm wide, and the width above is set to match. ${LABEL_SIZES[labelSize].use}`
                  : "Printing a Lakbayan label for it? Choose a size and the width is set to match. Leave this for the exhibit's own placard."
          }
        >
          <div className="segment-audio">
            <div className="size-choice" role="group" aria-label="Label size">
              {LABEL_SIZE_ORDER.map((size) => (
                <button
                  key={size}
                  className={labelSize === size ? "on" : undefined}
                  aria-pressed={labelSize === size}
                  disabled={!aspect}
                  title={
                    aspect
                      ? `Prints the photo ${printedPicture(aspect, size).widthMm / 10} cm wide`
                      : undefined
                  }
                  onClick={() =>
                    aspect &&
                    onPatch({ markerWidthM: labelMarkerWidthM(aspect, size) })
                  }
                >
                  {LABEL_SIZES[size].name}
                </button>
              ))}
            </div>
            <button
              className="btn-quiet sm"
              disabled={printBlocked !== null}
              title={printBlocked ?? undefined}
              onClick={() =>
                destinationId && openLabels(destinationId, [exhibit.id])
              }
            >
              <Printer size={14} aria-hidden="true" />
              Print
            </button>
          </div>
        </Field>

        <Field
          label="Recording"
          hint={`${AUDIO_FORMATS} — plays as-is in the app.`}
        >
          <div className="segment-audio">
            <button
              className="btn-secondary sm"
              disabled={uploading !== null}
              onClick={() => audioInput.current?.click()}
            >
              <Mic size={14} aria-hidden="true" />
              {uploading === "audio"
                ? "Uploading…"
                : exhibit.audioUrl
                  ? "Replace"
                  : "Upload"}
            </button>
            {exhibit.audioUrl && (
              <button
                className="btn-quiet sm"
                onClick={() => onPatch({ audioUrl: undefined })}
              >
                Remove
              </button>
            )}
            <input
              ref={audioInput}
              type="file"
              accept="audio/*"
              hidden
              onChange={(e) => void onPickAudio(e.target.files)}
            />
          </div>
          {exhibit.audioUrl && <AudioPreview path={exhibit.audioUrl} />}
        </Field>

        <Field
          label="Narration text"
          hint={
            exhibit.audioUrl
              ? "Unused while a recording exists — kept as the fallback if it is removed."
              : "Spoken by the device when there is no recording. Optional — an exhibit can be read rather than heard."
          }
        >
          <textarea
            rows={4}
            value={exhibit.ttsText ?? ""}
            onChange={(e) => onPatch({ ttsText: e.target.value })}
            placeholder="What the guide says about this exhibit."
          />
        </Field>
      </div>
    </li>
  );
}
