import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../domain/downloads_controller.dart";
import "../domain/offline_bundle.dart";
import "../domain/offline_providers.dart";

/// Wireframe 1f — download a town for offline use.
///
/// The offline-first guardrail in `CLAUDE.md` is about *reads* working from
/// cache. This screen is the other half: the deliberate act of taking a town
/// with you before there is no signal to fetch it with.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = ref.watch(offlineBundlesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Download a town")),
      body: bundles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          "Couldn't load the list of towns.\n\n"
          "This screen needs a connection the first time. Towns you have "
          "already downloaded still work.\n\n$e",
        ),
        data: (items) => items.isEmpty
            ? const _Message(
                "No towns are ready to download yet.\n\n"
                "The province builds these; one will appear here once a town "
                "has been prepared.",
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpace.x4),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.x3),
                itemBuilder: (context, i) => i == 0
                    ? const _Explainer()
                    : _TownTile(bundle: items[i - 1]),
              ),
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Container(
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        color: c.greenSubtle,
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        "A download keeps a town's map, photos and audio guides on this phone, "
        "so they work with no signal. Use Wi-Fi if you can.",
        style: AppTypography.body,
      ),
    );
  }
}

class _TownTile extends ConsumerWidget {
  const _TownTile({required this.bundle});

  final OfflineBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final controller = ref.read(downloadsControllerProvider.notifier);
    final downloads = ref.watch(downloadsControllerProvider);
    final store = ref.watch(downloadStoreProvider);

    final active = downloads[bundle.townId];
    final record = store.recordFor(bundle.townId);
    final townState = townStateFor(bundle, record);

    return Container(
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bundle.name, style: AppTypography.title),
                    const SizedBox(height: 2),
                    Text(
                      [
                        "${bundle.destinationIds.length} place"
                            "${bundle.destinationIds.length == 1 ? "" : "s"}",
                        _megabytes(bundle.size),
                      ].join(" · "),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              _StateBadge(bundle: bundle, townState: townState),
            ],
          ),

          if (active?.isRunning ?? false) ...[
            const SizedBox(height: AppSpace.x3),
            LinearProgressIndicator(
              value: active!.progress.filesTotal == 0
                  // Nothing to measure yet: the asset list is still being
                  // worked out. Indeterminate is honest about that.
                  ? null
                  : active.progress.fraction,
              borderRadius: AppRadius.smAll,
            ),
            const SizedBox(height: AppSpace.x2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    active.progress.filesTotal == 0
                        ? "Working out what to fetch…"
                        : "${active.progress.filesDone} of "
                              "${active.progress.filesTotal} files",
                    style: AppTypography.caption,
                  ),
                ),
                TextButton(
                  onPressed: () => controller.cancel(bundle.townId),
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ] else ...[
            if (active?.error case final message?) ...[
              const SizedBox(height: AppSpace.x2),
              Text(
                // Nothing was kept, so the honest instruction is "try again"
                // rather than anything about repairing a partial download.
                "That download didn't finish, and nothing was kept. $message",
                style: AppTypography.caption.copyWith(color: c.badgeErrorText),
              ),
            ],
            const SizedBox(height: AppSpace.x3),
            _Actions(
              bundle: bundle,
              townState: townState,
              onDownload: () => controller.start(bundle),
              onRemove: () => controller.remove(bundle.townId),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.bundle, required this.townState});

  final OfflineBundle bundle;
  final TownState townState;

  @override
  Widget build(BuildContext context) {
    // A bundle the province has not finished preparing outranks whatever this
    // phone has: there is nothing useful to say about downloading it yet.
    // `closed` because it genuinely cannot be had, not because anything failed.
    if (!bundle.isDownloadable) {
      return const LakbayanBadge("Not ready", kind: BadgeKind.closed);
    }
    return switch (townState) {
      // `neutral` is the design system's green "downloaded, available" — the
      // exact case its own comment names.
      TownState.current => const LakbayanBadge(
        "On this phone",
        kind: BadgeKind.neutral,
      ),
      // `info` rather than a warning colour: an out-of-date town still works
      // offline, it is simply not the newest.
      TownState.stale => const LakbayanBadge(
        "Update available",
        kind: BadgeKind.info,
      ),
      TownState.absent => const SizedBox.shrink(),
    };
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.bundle,
    required this.townState,
    required this.onDownload,
    required this.onRemove,
  });

  final OfflineBundle bundle;
  final TownState townState;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!bundle.isDownloadable) {
      return Text(
        "The province is still preparing this town.",
        style: AppTypography.caption,
      );
    }

    // The primary action flexes and Remove keeps its natural width. A Spacer
    // between two intrinsic-width buttons overflowed by 20px at 400dp — an
    // ordinary phone — once both were on screen with the longest label.
    return Row(
      children: [
        if (townState != TownState.absent) ...[
          OutlinedButton(onPressed: onRemove, child: const Text("Remove")),
          const SizedBox(width: AppSpace.x2),
        ],
        Expanded(
          child: FilledButton(
            onPressed: onDownload,
            child: Text(
              switch (townState) {
                TownState.absent => "Download",
                // "Update", not "Re-download": the whole town is fetched
                // either way, but what the person wants is newer content.
                TownState.stale => "Update",
                TownState.current => "Download again",
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.x8),
      child: Text(text, style: AppTypography.body, textAlign: TextAlign.center),
    ),
  );
}

String _megabytes(int bytes) {
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
  return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
}
