import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/widgets/chrome/app_menu.dart";
import "../../../core/widgets/chrome/page_title.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/downloads_controller.dart";
import "../domain/offline_bundle.dart";
import "../domain/offline_providers.dart";
import "town_download_button.dart";

/// Offline (wireframe 1f, D-19). **Job:** take a town with you before there
/// is no signal to fetch it with. **Emotion:** ready.
///
/// The offline-first guardrail in `CLAUDE.md` is about reads working from
/// cache; this is the other half, the deliberate act. Each town is its
/// photo with its name and size on it, and its state as the one control in
/// the corner: download, the ring while it runs, the emerald check once it
/// is on the phone, which opens Update and Remove.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = ref.watch(offlineBundlesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x2,
                AppSpace.gutter,
                AppSpace.section,
              ),
              sliver: SliverToBoxAdapter(child: PageTitle("Offline")),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                0,
                AppSpace.gutter,
                MediaQuery.viewPaddingOf(context).bottom + AppSpace.section,
              ),
              sliver: bundles.whenLocalFirst(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: QuietNote(
                    errorCopy(
                      "Couldn't load the towns.",
                      e,
                      offline:
                          "This needs a connection the first time. Towns "
                          "already on this phone still work.",
                    ),
                    onRetry: () => ref.invalidate(offlineBundlesProvider),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const SliverToBoxAdapter(
                        child: QuietNote("No towns are ready to download yet."),
                      )
                    : SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpace.x2,
                              crossAxisSpacing: AppSpace.x2,
                              childAspectRatio: _Town.aspect,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _Town(bundle: items[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A town as its photo, with its name and size on it and its state in the
/// corner. One the province is still preparing says so, with nothing to tap.
class _Town extends ConsumerWidget {
  const _Town({required this.bundle});

  final OfflineBundle bundle;

  static const aspect = 9 / 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(
      townsProvider.select(
        (towns) =>
            towns.where((town) => town.name == bundle.name).firstOrNull?.cover,
      ),
    );
    final stale = ref.watch(
      townStatesProvider.select(
        (states) => states[bundle.townId] == TownState.stale,
      ),
    );
    final ready = bundle.isDownloadable;

    return MediaTile(
      media: CoverImage(cover),
      aspectRatio: aspect,
      overlay: true,
      dense: true,
      radius: AppRadii.md,
      title: bundle.name,
      subtitle: _megabytes(bundle.size),
      pill: !ready
          ? const PhotoPill("Preparing")
          : stale
          ? const PhotoPill("Update Ready")
          : null,
      trailing: ready
          ? TownDownloadButton(
              bundle: bundle,
              done: _OnPhone(bundle: bundle, stale: stale),
            )
          : null,
    );
  }
}

/// On the phone: the emerald check, which opens Update when the province has
/// changed the town since, and Remove.
class _OnPhone extends ConsumerWidget {
  const _OnPhone({required this.bundle, required this.stale});

  final OfflineBundle bundle;
  final bool stale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final downloads = ref.read(downloadsControllerProvider.notifier);
    return AppMenu(
      groups: [
        if (stale)
          [
            AppMenuItem(
              label: "Update",
              icon: AppIcons.download,
              onSelected: () => unawaited(downloads.start(bundle)),
            ),
          ],
        [
          AppMenuItem(
            label: "Remove",
            icon: AppIcons.delete,
            destructive: true,
            onSelected: () => unawaited(downloads.remove(bundle.townId)),
          ),
        ],
      ],
      builder: (context, menu) => SymbolButton(
        icon: AppIcons.check,
        tooltip: "${bundle.name} is on this phone",
        background: scheme.primary,
        color: scheme.onPrimary,
        onTap: menu.open,
      ),
    );
  }
}

String _megabytes(int bytes) {
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
  return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
}
