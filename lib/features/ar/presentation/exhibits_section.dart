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
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../audio/domain/audio_providers.dart";
import "../domain/ar_providers.dart";
import "../domain/exhibit_scanner.dart";
import "exhibit_sheet.dart";
import "exhibits_screen.dart";

/// A museum's Exhibits part on its page (D-18, D-19): Scan an Exhibit where
/// the phone can, then every exhibit as a photo; a photo opens its sheet.
/// Absent for every other place, and for a museum with nothing to show yet.
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
          .scan(
            placeName: widget.destination.name,
            markers: markers,
            colors: ScanColors.of(Theme.of(context).colorScheme),
          );
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
                  destinationId: _id,
                  exhibits: exhibits,
                  canScan:
                      support == ArSupport.available &&
                      exhibits.any((e) => e.isScannable),
                  scanning: _scanning,
                  onScan: () => _scan(exhibits),
                ),
        );
    return body ?? const SizedBox.shrink();
  }
}

class _Exhibits extends StatelessWidget {
  const _Exhibits({
    required this.destinationId,
    required this.exhibits,
    required this.canScan,
    required this.scanning,
    required this.onScan,
  });

  final String destinationId;
  final List<Exhibit> exhibits;
  final bool canScan;
  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canScan) ...[
          Pressable(
            enabled: !scanning,
            child: TextButton(
              onPressed: scanning ? null : onScan,
              style: TextButton.styleFrom(
                backgroundColor: brand.tint,
                minimumSize: const Size.fromHeight(AppSize.formButton),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.tileAll,
                ),
              ),
              child: FadeSwap(
                id: scanning,
                child: scanning
                    ? const SizedBox.square(
                        dimension: AppSize.spinner,
                        child: CircularProgressIndicator(
                          strokeWidth: AppStroke.bold,
                        ),
                      )
                    : const Text("Scan an Exhibit"),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x3),
        ],
        // A museum's handful of exhibits, inside the page's own scroll.
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpace.x2,
          crossAxisSpacing: AppSpace.x2,
          childAspectRatio: 6 / 5,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final exhibit in exhibits)
              MediaTile(
                key: ValueKey("exhibit-${exhibit.id}"),
                media: exhibit.markerPath.isEmpty
                    ? ColoredBox(color: brand.sky)
                    : StorageImage(path: exhibit.markerPath),
                aspectRatio: 6 / 5,
                overlay: true,
                dense: true,
                radius: AppRadii.md,
                title: exhibit.title,
                onTap: () => showExhibitSheet(
                  context,
                  destinationId: destinationId,
                  exhibit: exhibit,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
