import "package:flutter/foundation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../data/town_downloader.dart";
import "offline_bundle.dart";
import "offline_providers.dart";

part "downloads_controller.g.dart";

/// What a town is doing right now, as far as the screen is concerned.
@immutable
class TownDownload {
  const TownDownload({required this.progress, this.cancel, this.error});

  final DownloadProgress progress;

  /// Present while a download is in flight. Null once it settled.
  final CancelToken? cancel;

  /// Set when the last attempt failed. Cleared by starting another.
  final String? error;

  bool get isRunning => cancel != null;
}

/// Runs downloads and reports on them.
///
/// One notifier for every town rather than one per town: a phone should not be
/// pulling two towns at once over a rural connection, and a single map makes
/// "is anything running" a question with one answer.
@riverpod
class DownloadsController extends _$DownloadsController {
  @override
  Map<String, TownDownload> build() => const {};

  bool get isBusy => state.values.any((d) => d.isRunning);

  void _set(String townId, TownDownload value) {
    if (!ref.mounted) return;
    state = {...state, townId: value};
  }

  /// Fetch a town. Returns when it has finished, failed or been cancelled.
  Future<void> start(OfflineBundle bundle) async {
    if (state[bundle.townId]?.isRunning ?? false) return;

    final cancel = CancelToken();
    _set(
      bundle.townId,
      TownDownload(
        progress: const DownloadProgress(
          filesDone: 0,
          filesTotal: 0,
          bytesDone: 0,
        ),
        cancel: cancel,
      ),
    );

    try {
      // Derived from the destinations rather than read off the manifest, so
      // the two cannot drift. This is a handful of Firestore reads, all of
      // them already cached by the time somebody reaches this screen.
      final paths = await assetPathsFor(ref, bundle);

      await ref
          .read(townDownloaderProvider)
          .download(
            bundle,
            assetPaths: paths,
            cancel: cancel,
            onProgress: (progress) => _set(
              bundle.townId,
              TownDownload(progress: progress, cancel: cancel),
            ),
          );

      // Cleared rather than left at 100%: the row now reads its state from the
      // download record, and a lingering progress bar would sit under a town
      // that is finished.
      if (ref.mounted) {
        state = {...state}..remove(bundle.townId);
        ref.invalidate(townStatesProvider);
      }
    } on DownloadCancelled {
      if (ref.mounted) state = {...state}..remove(bundle.townId);
    } catch (e) {
      _set(
        bundle.townId,
        TownDownload(
          progress: const DownloadProgress(
            filesDone: 0,
            filesTotal: 0,
            bytesDone: 0,
          ),
          error: "$e",
        ),
      );
    }
  }

  void cancel(String townId) => state[townId]?.cancel?.cancel();

  Future<void> remove(String townId) async {
    await ref.read(townDownloaderProvider).delete(townId);
    if (ref.mounted) {
      state = {...state}..remove(townId);
      ref.invalidate(townStatesProvider);
    }
  }
}
