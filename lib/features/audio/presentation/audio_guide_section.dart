import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/app_card.dart";
import "../../../core/widgets/grouped_section.dart";
import "../domain/audio_providers.dart";
import "../domain/narration.dart";

/// The audio guide on Place detail (wireframe 1e, on the 2.1 design).
///
/// The stop list and the player are one widget because they are one control
/// surface: tapping a row is how you start a stop, and the card underneath is
/// how you steer the one that is running. Stops are comparable rows on one
/// grouped surface; the running one is marked by its solid green play glyph,
/// the selection idiom, not by a tinted row.
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
    final scheme = Theme.of(context).colorScheme;

    if (segments.isEmpty) {
      return Text(
        "No audio guide for this stop yet.",
        style: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    // The player belongs to whichever destination started it. Without this a
    // second destination's sheet would show a bar steering audio from the
    // first, which reads as a bug even though the audio is correct.
    final showPlayer =
        playback.destinationId == destinationId && playback.segmentId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          children: [
            for (final (i, segment) in segments.indexed)
              _SegmentRow(
                // Stable per stop, so a test can address a row without going
                // through its title, which the player repeats once something
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
          ],
        ),
        if (showPlayer) ...[
          const SizedBox(height: AppSpace.x3),
          _PlayerCard(
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
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = playback.isCurrent(segment.id);
    final isPlaying = playback.isPlaying(segment.id);
    final isLoading = playback.isLoading(segment.id);

    // A stop with a script but no recording is read by the device. Saying so
    // sets the expectation before the voice starts.
    final spoken =
        (segment.audioUrl == null || segment.audioUrl!.isEmpty) &&
        (segment.ttsText?.trim().isNotEmpty ?? false);
    final description = segment.description?.trim() ?? "";
    final subtitle = !segment.isPlayable
        ? "No recording or script yet"
        : description.isNotEmpty
        ? description
        : spoken
        ? "Read aloud by your device"
        : null;

    final Widget trailing;
    if (isLoading) {
      trailing = const SizedBox(
        width: AppSize.minTouchTarget,
        height: AppSize.minTouchTarget,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else {
      trailing = IconButton(
        onPressed: onTap,
        icon: Icon(isPlaying ? AppIcons.pause : AppIcons.play, size: 18),
        tooltip: onTap == null
            ? "Nothing to play for this stop"
            : isPlaying
            ? "Pause"
            : "Play stop $index",
        style: IconButton.styleFrom(
          backgroundColor: isCurrent
              ? scheme.primary
              : scheme.surfaceContainerHigh,
          foregroundColor: isCurrent ? scheme.onPrimary : scheme.onSurface,
          fixedSize: const Size.square(AppSize.symbolButton),
          shape: const CircleBorder(),
        ),
      );
    }

    return Semantics(
      selected: isCurrent,
      label: "Stop $index, ${segment.title}",
      child: GroupedRow(
        title: segment.title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// Transport for the stop that is running. One tonal card, no border.
class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({required this.segment, required this.playback});

  final Segment segment;
  final GuidePlayback playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(audioGuideControllerProvider.notifier);
    final n = playback.narrator;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  segment.title,
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (n.duration case final total?)
                Text(
                  "${_clock(n.position)} of ${_clock(total)}",
                  style: AppTypography.secondLine.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.x2),

          // A scrubber only when the source can actually be scrubbed. Speech
          // reports no length and cannot seek, so it gets an indeterminate bar;
          // drawing a draggable one over it would be a fabrication.
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
                borderRadius: capsuleRadius,
              ),
            ),

          if (n.error case final message?) ...[
            const SizedBox(height: AppSpace.x2),
            Text(
              message,
              style: AppTypography.secondLine.copyWith(color: scheme.error),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: controller.skipPrevious,
                icon: const Icon(AppIcons.skipPrevious),
                tooltip: "Previous stop",
              ),
              IconButton.filled(
                // togglePlayPause, not toggle: this card has no segment list
                // to pass, and handing over an empty one would clear the queue.
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  n.phase == NarratorPhase.playing
                      ? AppIcons.pause
                      : AppIcons.play,
                ),
                tooltip: n.phase == NarratorPhase.playing ? "Pause" : "Play",
              ),
              IconButton(
                onPressed: controller.skipNext,
                icon: const Icon(AppIcons.skipNext),
                tooltip: "Next stop",
              ),
              IconButton(
                onPressed: controller.stop,
                icon: const Icon(AppIcons.stop),
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
