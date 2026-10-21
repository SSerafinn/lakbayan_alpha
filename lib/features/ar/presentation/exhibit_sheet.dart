import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/exhibit.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../audio/domain/audio_providers.dart";
import "../../audio/domain/narration.dart";
import "../domain/ar_providers.dart";

/// Opens [exhibit]'s sheet: what the camera found, or what was tapped in the
/// list.
Future<void> showExhibitSheet(
  BuildContext context, {
  required String destinationId,
  required Exhibit exhibit,
}) => showAppSheet<void>(
  context,
  builder: (_) => ExhibitSheet(destinationId: destinationId, exhibit: exhibit),
);

/// One exhibit: its line, its story, and Listen pinned below (D-18).
///
/// The narration is the audio guide's player with this exhibit as its only
/// stop, so it gets everything the guide has: a downloaded recording offline,
/// the script read aloud when there is no recording, the lock screen. It
/// plays under the museum's own id, which also means the guide's capsule on
/// the page beneath shows it playing and can pause it — one voice at a time.
class ExhibitSheet extends ConsumerWidget {
  const ExhibitSheet({
    required this.destinationId,
    required this.exhibit,
    super.key,
  });

  final String destinationId;
  final Exhibit exhibit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final description = exhibit.description?.trim() ?? "";
    final paragraphs = [
      for (final paragraph in (exhibit.story ?? "").split(_blankLine))
        if (paragraph.trim().isNotEmpty) paragraph.trim(),
    ];

    return AppSheet(
      title: exhibit.title,
      action: exhibit.hasNarration
          ? _Listen(destinationId: destinationId, exhibit: exhibit)
          : null,
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: SliverList.list(
            children: [
              if (description.isNotEmpty)
                Text(
                  description,
                  style: AppTypography.bodyLarge.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              for (final (index, paragraph) in paragraphs.indexed) ...[
                if (index > 0 || description.isNotEmpty)
                  const SizedBox(height: AppSpace.x4),
                Text(paragraph, style: AppTypography.bodyLarge),
              ],
              if (description.isEmpty && paragraphs.isEmpty)
                Text(
                  "No story for this exhibit yet.",
                  style: AppTypography.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static final _blankLine = RegExp(r"\n\s*\n");
}

/// Listen, Pause, Resume: the one button the exhibit's narration needs.
class _Listen extends ConsumerWidget {
  const _Listen({required this.destinationId, required this.exhibit});

  final String destinationId;
  final Exhibit exhibit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = exhibitNarration(exhibit);
    // This exhibit's phase, or null while anything else (or nothing) plays.
    final phase = ref.watch(
      audioGuideControllerProvider.select(
        (playback) =>
            playback.destinationId == destinationId &&
                playback.isCurrent(segment.id)
            ? playback.narrator.phase
            : null,
      ),
    );
    final (String label, IconData icon) = switch (phase) {
      NarratorPhase.playing => ("Pause", AppIcons.pause),
      NarratorPhase.paused => ("Resume", AppIcons.play),
      NarratorPhase.failed => ("Try again", AppIcons.play),
      _ => ("Listen", AppIcons.play),
    };
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return FilledButton.icon(
      onPressed: () => ref.read(audioGuideControllerProvider.notifier).toggle(
        destinationId,
        [segment],
        segment,
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.primaryButton),
      ),
      icon: phase == NarratorPhase.loading
          ? SizedBox.square(
              dimension: AppSize.glyph,
              child: CircularProgressIndicator(
                strokeWidth: AppStroke.bold,
                color: onPrimary,
              ),
            )
          : Icon(icon, size: AppSize.glyph),
      label: Text(label),
    );
  }
}
