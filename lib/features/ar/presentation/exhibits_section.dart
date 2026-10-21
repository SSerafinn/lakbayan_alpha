import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/exhibit.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../audio/domain/audio_providers.dart";
import "../domain/ar_providers.dart";
import "../domain/exhibit_scanner.dart";
import "exhibit_sheet.dart";
import "exhibits_screen.dart";

/// A museum's exhibits on its page (D-18): Scan an exhibit where the phone
/// can, and the plain list where it cannot. Absent for every other place,
/// and for a museum with nothing to show yet.
///
/// A scan opens the native scan screen; the exhibit the visitor taps there
/// opens here, in the same sheet the list uses. Whatever stops the camera —
/// a refused permission, ARCore that will not start, marker images that are
/// not on the phone — lands on the list, saying why.
class ExhibitsSection extends ConsumerStatefulWidget {
  const ExhibitsSection({required this.destination, super.key});

  final Destination destination;

  @override
  ConsumerState<ExhibitsSection> createState() => _ExhibitsSectionState();
}

class _ExhibitsSectionState extends ConsumerState<ExhibitsSection> {
  /// From the tap until the scan screen returns: fetching any marker images
  /// not on the phone, then the camera itself. One scan at a time.
  bool _scanning = false;

  String get _id => widget.destination.id;

  void _openList([ExhibitsWhy why = ExhibitsWhy.browse]) =>
      context.push(Routes.exhibits(_id, why: why));

  Future<void> _scan(List<Exhibit> exhibits) async {
    setState(() => _scanning = true);
    try {
      final markers = await scanMarkersFor(
        exhibits,
        ref.read(markerFileResolverProvider),
      );
      if (!mounted) return;
      if (markers.isEmpty) {
        _openList(ExhibitsWhy.notOnPhone);
        return;
      }

      final outcome = await ref
          .read(exhibitScannerProvider)
          .scan(placeName: widget.destination.name, markers: markers);
      if (!mounted) return;
      switch (outcome) {
        case ExhibitRecognised(:final exhibitId):
          // The latest copy: an edit may have landed while the camera ran.
          final latest =
              ref.read(destinationExhibitsProvider(_id)).value ?? exhibits;
          final exhibit = latest.where((e) => e.id == exhibitId).firstOrNull;
          if (exhibit != null) {
            unawaited(
              showExhibitSheet(context, destinationId: _id, exhibit: exhibit),
            );
          }
        case ScanClosed():
          break;
        case ScanUnavailable(problem: ScanProblem.cameraDenied):
          _openList(ExhibitsWhy.cameraDenied);
        case ScanUnavailable(problem: ScanProblem.arUnavailable):
          _openList(ExhibitsWhy.arUnavailable);
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.destination.hasAR) return const SizedBox.shrink();

    // An exhibit's narration plays on the guide's player, which would
    // otherwise go with the sheet that started it.
    ref.listen(audioGuideControllerProvider, (_, _) {});
    final support = ref.watch(arSupportProvider).value;
    final Widget? body = ref
        .watch(destinationExhibitsProvider(_id))
        .whenLocalFirst(
          // Both answer from the phone in moments; the section arrives once,
          // rather than as a list that turns into a camera.
          loading: () => null,
          error: (error, _) => QuietNote(
            errorCopy("Couldn't load the exhibits.", error),
            onRetry: () => ref.invalidate(destinationExhibitsProvider(_id)),
          ),
          data: (exhibits) => exhibits.isEmpty || support == null
              ? null
              : _Exhibits(
                  count: exhibits.length,
                  canScan:
                      support == ArSupport.available &&
                      exhibits.any((e) => e.isScannable),
                  scanning: _scanning,
                  onScan: () => _scan(exhibits),
                  onList: _openList,
                ),
        );
    if (body == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x6),
      child: body,
    );
  }
}

class _Exhibits extends StatelessWidget {
  const _Exhibits({
    required this.count,
    required this.canScan,
    required this.scanning,
    required this.onScan,
    required this.onList,
  });

  final int count;
  final bool canScan;
  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = canScan
        ? "Point your camera at an exhibit or its label to hear its story."
        : count == 1
        ? "One exhibit, with its story."
        : "$count exhibits, each with its story.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // With the camera on offer, the list is the lesser way in.
        SectionHeading("Exhibits", onSeeAll: canScan ? onList : null),
        const SizedBox(height: AppSpace.x1),
        Text(
          caption,
          style: AppTypography.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpace.x3),
        SizedBox(
          width: double.infinity,
          child: Pressable(
            enabled: !scanning,
            child: canScan
                ? OutlinedButton.icon(
                    onPressed: scanning ? null : onScan,
                    icon: scanning
                        ? const SizedBox.square(
                            dimension: AppSize.glyph,
                            child: CircularProgressIndicator(
                              strokeWidth: AppStroke.bold,
                            ),
                          )
                        : const Icon(AppIcons.scan, size: AppSize.glyph),
                    label: const Text("Scan an exhibit"),
                  )
                : OutlinedButton(
                    onPressed: onList,
                    child: const Text("See the exhibits"),
                  ),
          ),
        ),
      ],
    );
  }
}
