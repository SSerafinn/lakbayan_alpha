import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../domain/audio_providers.dart";
import "../domain/narration.dart";

/// The audio guide on the Destination Detail sheet — wireframe 1e.
///
/// The stop list and the player are one widget because they are one control
/// surface: tapping a row is how you start a stop, and the bar underneath is
/// how you steer the one that is running.
class AudioGuideSection extends ConsumerWidget {
  const AudioGuideSection({
    required this.destinationId,
    required this.segments,
    super.key,
  });

  final String destinationId;
  final List<Segment> segments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(audioGuideControllerProvider);
    final c = context.lakbayan;

    if (segments.isEmpty) {
      return Text(
        "No audio guide for this stop yet.",
        style: AppTypography.body.copyWith(color: c.textSecondary),
      );
    }

    // The player belongs to whichever destination started it. Without this a
    // second destination's sheet would show a bar steering audio from the
    // first, which reads as a bug even though the audio is correct.
    final showPlayer =
        playback.destinationId == destinationId && playback.segmentId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, segment) in segments.indexed)
          _SegmentRow(
            // Stable per stop, so a test can address a row without going
            // through its title — which the player bar repeats once something
            // is playing.
            key: Key("stop-${segment.id}"),
            index: i + 1,
            segment: segment,
            playback: playback,
            onTap: segment.isPlayable
                ? () => ref
                      .read(audioGuideControllerProvider.notifier)
                      .toggle(destinationId, segments, segment)
                : null,
          ),
        if (showPlayer) ...[
          const SizedBox(height: AppSpace.x3),
          _PlayerBar(
            segment: segments.firstWhere(
              (s) => s.id == playback.segmentId,
              orElse: () => segments.first,
            ),
            playback: playback,
          ),
        ],
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.index,
    required this.segment,
    required this.playback,
    required this.onTap,
    super.key,
  });

  final int index;
  final Segment segment;
  final GuidePlayback playback;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final isCurrent = playback.isCurrent(segment.id);
    final isPlaying = playback.isPlaying(segment.id);
    final isLoading = playback.isLoading(segment.id);

    // A stop with a script but no recording is read by the device. Saying so
    // sets the expectation before the voice starts, rather than leaving
    // someone wondering why one stop sounds like a person and the next does
    // not.
    final spoken =
        (segment.audioUrl == null || segment.audioUrl!.isEmpty) &&
        (segment.ttsText?.trim().isNotEmpty ?? false);

    return Semantics(
      button: onTap != null,
      selected: isCurrent,
      label: "Stop $index, ${segment.title}",
      child: Material(
        color: isCurrent ? c.greenSubtle : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpace.x2,
              horizontal: AppSpace.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$index · ${segment.title}",
                        style: AppTypography.title.copyWith(
                          color: isCurrent ? c.textOnLightGreen : null,
                        ),
                      ),
                      if (segment.description case final d?
                          when d.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          d,
                          style: AppTypography.body.copyWith(
                            color: c.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (!segment.isPlayable)
                        Text(
                          "No recording or script yet",
                          style: AppTypography.caption,
                        )
                      else if (spoken)
                        Text(
                          "Read aloud by your device",
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                SizedBox(
                  width: AppSize.minTouchTarget,
                  height: AppSize.minTouchTarget,
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filledTonal(
                          onPressed: onTap,
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          tooltip: onTap == null
                              ? "Nothing to play for this stop"
                              : isPlaying
                              ? "Pause"
                              : "Play stop $index",
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transport for the stop that is running.
class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({required this.segment, required this.playback});

  final Segment segment;
  final GuidePlayback playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final controller = ref.read(audioGuideControllerProvider.notifier);
    final n = playback.narrator;

    return Container(
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        color: c.greenSubtle,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  segment.title,
                  style: AppTypography.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (n.duration case final total?)
                Text(
                  "${_clock(n.position)} / ${_clock(total)}",
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.x2),

          // A scrubber only when the source can actually be scrubbed. Speech
          // reports no length and cannot seek, so it gets an indeterminate bar
          // — drawing a draggable one over it would be a fabrication.
          if (n.canSeek && n.duration != null)
            Slider(
              value: n.position.inMilliseconds
                  .clamp(0, n.duration!.inMilliseconds)
                  .toDouble(),
              max: n.duration!.inMilliseconds.toDouble(),
              onChanged: (v) =>
                  controller.seek(Duration(milliseconds: v.round())),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
              child: LinearProgressIndicator(
                value: n.phase == NarratorPhase.playing ? null : 0,
                borderRadius: AppRadius.smAll,
              ),
            ),

          if (n.error case final message?) ...[
            const SizedBox(height: AppSpace.x2),
            Text(
              message,
              style: AppTypography.caption.copyWith(color: c.badgeErrorText),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: controller.skipPrevious,
                icon: const Icon(Icons.skip_previous),
                tooltip: "Previous stop",
              ),
              IconButton.filled(
                // togglePlayPause, not toggle: this bar has no segment list to
                // pass, and handing over an empty one would clear the queue.
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  n.phase == NarratorPhase.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                tooltip: n.phase == NarratorPhase.playing ? "Pause" : "Play",
              ),
              IconButton(
                onPressed: controller.skipNext,
                icon: const Icon(Icons.skip_next),
                tooltip: "Next stop",
              ),
              IconButton(
                onPressed: controller.stop,
                icon: const Icon(Icons.stop),
                tooltip: "Stop the audio guide",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _clock(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
  return "$minutes:$seconds";
}
