import { useRef, useState } from "react";
import { ChevronDown, ChevronUp, Mic, Trash2, Volume2 } from "lucide-react";
import { AudioPreview } from "../components/AudioPreview";
import { Field } from "../components/Form";
import { useToast } from "../components/toast-context";
import { deleteAudio, newSegmentId, uploadAudio } from "../lib/segments";
import { AUDIO_FORMATS, recordingProblem } from "../types/media";
import {
  emptySegment,
  narrationSource,
  segmentProblems,
  type SegmentDraft,
} from "../types/segment";

/**
 * Admin wireframe screen 5 — the audio guide for one destination.
 *
 * Nothing here writes to Firestore. Edits go back to the editor page through
 * `onChange` and land with the destination's own save, so the savebar, Ctrl+S,
 * Discard and the unsaved-changes guard all cover the guide too. The one
 * exception is a recording: it goes to Storage the moment it is picked,
 * because there is no way to hold a file in a draft.
 */
export function AudioGuideTab({
  destinationId,
  destinationName,
  segments,
  onChange,
  onSaveFirst,
}: {
  /** Null until the destination has been written once. */
  destinationId: string | null;
  destinationName: string;
  segments: SegmentDraft[];
  onChange: (next: SegmentDraft[]) => void;
  /** Creates the draft document and resolves to its id, or null if it failed. */
  onSaveFirst: () => Promise<string | null>;
}) {
  const { silent } = segmentProblems(segments);

  function update(id: string, patch: Partial<SegmentDraft>) {
    onChange(segments.map((s) => (s.id === id ? { ...s, ...patch } : s)));
  }

  function add() {
    onChange([...segments, emptySegment(newSegmentId())]);
  }

  /**
   * Move a stop one place up or down.
   *
   * Buttons rather than drag-and-drop. A guide is a handful of stops, so the
   * ceiling on effort is low either way — and buttons work from the keyboard
   * and are announced by a screen reader, which hand-rolled HTML5 dragging is
   * not without a great deal more code than this screen is worth.
   */
  function move(index: number, by: -1 | 1) {
    const to = index + by;
    if (to < 0 || to >= segments.length) return;
    const next = [...segments];
    [next[index], next[to]] = [next[to], next[index]];
    onChange(next);
  }

  return (
    <div className="segments">
      <div className="row">
        <div>
          <h2 className="segments-title">Audio guide</h2>
          <p className="hint">
            Stops play in this order
            {destinationName ? ` at ${destinationName}` : ""}. Each one needs
            either a recording or narration text.
          </p>
        </div>
        <span className="spacer" />
        <button className="btn-secondary" onClick={add}>
          Add stop
        </button>
      </div>

      {segments.length === 0 ? (
        <div className="empty">
          <Volume2 size={24} aria-hidden="true" />
          <p>
            No audio guide yet. This is optional — add stops only if this place
            has narration.
          </p>
          <button className="btn-secondary" onClick={add}>
            Add the first stop
          </button>
        </div>
      ) : (
        <>
          {silent > 0 && (
            <p className="hint">
              {silent} stop{silent === 1 ? "" : "s"} cannot be played yet. The
              destination will not publish until every stop has a recording or
              narration text.
            </p>
          )}
          <ol className="segment-list">
            {segments.map((segment, i) => (
              <SegmentRow
                key={segment.id}
                segment={segment}
                index={i}
                count={segments.length}
                destinationId={destinationId}
                onPatch={(patch) => update(segment.id, patch)}
                onMove={(by) => move(i, by)}
                onRemove={() =>
                  onChange(segments.filter((s) => s.id !== segment.id))
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

const SOURCE_LABEL = {
  recording: "Recorded",
  tts: "Read aloud",
  none: "Silent",
} as const;

function SegmentRow({
  segment,
  index,
  count,
  destinationId,
  onPatch,
  onMove,
  onRemove,
  onSaveFirst,
}: {
  segment: SegmentDraft;
  index: number;
  count: number;
  destinationId: string | null;
  onPatch: (patch: Partial<SegmentDraft>) => void;
  onMove: (by: -1 | 1) => void;
  onRemove: () => void;
  onSaveFirst: () => Promise<string | null>;
}) {
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const toast = useToast();
  const source = narrationSource(segment);

  async function onPick(files: FileList | null) {
    const file = files?.[0];
    if (!file) return;

    // storage.rules refuses it anyway; this says why, and what to do.
    const problem = recordingProblem(file);
    if (problem) {
      toast.toast({ variant: "warning", ...problem });
      return;
    }

    setUploading(true);
    try {
      // Same bargain as photos: rather than blocking with "save it first",
      // create the draft destination silently so the upload has somewhere to
      // go. See the note in MediaTab.
      const target = destinationId ?? (await onSaveFirst());
      if (!target) return; // The save failed and already reported why.

      const previous = segment.audioUrl;
      const path = await uploadAudio(target, segment.id, file);
      onPatch({ audioUrl: path });

      // Replacing mp3 with m4a writes a second object under the same segment
      // id; only the new one is referenced, so the old one is litter.
      if (previous && previous !== path) await deleteAudio(previous);

      toast.success("Recording uploaded", "Save to keep it.");
    } catch (err) {
      toast.error(
        "Upload failed",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setUploading(false);
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  return (
    <li className="segment">
      <div className="segment-head">
        <span className="segment-no">{index + 1}</span>
        <input
          className="segment-title"
          value={segment.title}
          onChange={(e) => onPatch({ title: e.target.value })}
          placeholder="Stop title — e.g. The cathedral facade"
          aria-label={`Title of stop ${index + 1}`}
        />
        <span className={source === "none" ? "badge warn" : "badge ok"}>
          {SOURCE_LABEL[source]}
        </span>
        <div className="segment-order">
          <button
            className="btn-quiet sm"
            onClick={() => onMove(-1)}
            disabled={index === 0}
            aria-label={`Move stop ${index + 1} earlier`}
          >
            <ChevronUp size={16} aria-hidden="true" />
          </button>
          <button
            className="btn-quiet sm"
            onClick={() => onMove(1)}
            disabled={index === count - 1}
            aria-label={`Move stop ${index + 1} later`}
          >
            <ChevronDown size={16} aria-hidden="true" />
          </button>
        </div>
        {/* No confirmation: removal only reaches Firestore on save, and
            Discard puts the row back. A dialog here would guard nothing. */}
        <button
          className="btn-quiet sm"
          onClick={onRemove}
          aria-label={`Remove stop ${index + 1}`}
        >
          <Trash2 size={16} aria-hidden="true" />
        </button>
      </div>

      <div className="fgrid">
        <Field
          label="Description"
          hint="Optional caption shown beside the stop in the player."
          wide
        >
          <textarea
            rows={2}
            value={segment.description ?? ""}
            onChange={(e) => onPatch({ description: e.target.value })}
          />
        </Field>

        <Field
          label="Recording"
          hint={`${AUDIO_FORMATS} — plays as-is in the app.`}
        >
          <div className="segment-audio">
            <button
              className="btn-secondary sm"
              disabled={uploading}
              onClick={() => fileInput.current?.click()}
            >
              <Mic size={14} aria-hidden="true" />
              {uploading
                ? "Uploading…"
                : segment.audioUrl
                  ? "Replace"
                  : "Upload"}
            </button>
            {segment.audioUrl && (
              <button
                className="btn-quiet sm"
                onClick={() => {
                  const path = segment.audioUrl!;
                  onPatch({ audioUrl: undefined });
                  void deleteAudio(path);
                }}
              >
                Remove
              </button>
            )}
            <input
              ref={fileInput}
              type="file"
              accept="audio/*"
              hidden
              onChange={(e) => void onPick(e.target.files)}
            />
          </div>
          {segment.audioUrl && <AudioPreview path={segment.audioUrl} />}
        </Field>

        <Field
          label="Narration text"
          hint={
            segment.audioUrl
              ? "Unused while a recording exists — kept as the fallback if it is removed."
              : "Spoken by the device when there is no recording."
          }
        >
          <textarea
            rows={4}
            value={segment.ttsText ?? ""}
            onChange={(e) => onPatch({ ttsText: e.target.value })}
            placeholder="What the guide says at this stop."
          />
        </Field>
      </div>
    </li>
  );
}
