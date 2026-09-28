import "dart:io";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

import "../domain/offline_bundle.dart";
import "asset_fetcher.dart";
import "download_store.dart";

/// How far along a town's download is.
@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    this.currentPath,
  });

  final int filesDone;
  final int filesTotal;
  final int bytesDone;

  /// The object being fetched, for a status line.
  final String? currentPath;

  /// 0 to 1 by **file count**, not bytes.
  ///
  /// Bytes would be the better measure and we do not have them: the manifest
  /// gives one total, not a size per object, so a byte-based bar would jump
  /// unevenly as large photos land. Counting files is honest about what it
  /// knows.
  double get fraction => filesTotal == 0 ? 0 : filesDone / filesTotal;
}

/// Raised when a caller cancels. Distinct from a failure so the UI can say
/// "cancelled" rather than "something went wrong".
class DownloadCancelled implements Exception {
  const DownloadCancelled();

  @override
  String toString() => "Download cancelled";
}

/// Cooperative cancellation. Checked between files, so a cancel takes effect
/// after the object in flight rather than tearing a write in half.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Fetches everything a town needs and puts it on disk.
///
/// Knows nothing about Firestore: it is handed a bundle and the list of Storage
/// paths to pull. Deriving that list belongs to the caller, which already reads
/// the destinations and their segments.
class TownDownloader {
  const TownDownloader({
    required AssetFetcher fetcher,
    required Directory root,
    required DownloadStore store,
  }) : this._(fetcher, root, store);

  const TownDownloader._(this._fetcher, this._root, this._store);

  final AssetFetcher _fetcher;
  final Directory _root;
  final DownloadStore _store;

  Directory townDirectory(String townId) =>
      Directory(p.join(_root.path, "offline", townId));

  Directory _stagingDirectory(String townId) =>
      Directory(p.join(_root.path, "offline", "$townId.partial"));

  /// Absolute path a Storage object lands at, mirroring its Storage path.
  ///
  /// Mirroring rather than hashing keeps the tree readable on a device, and
  /// means the tile pack ends up at exactly `tilePackRef` under the town —
  /// so the map layer needs no second lookup table.
  String localPathFor(String townId, String storagePath) =>
      p.join(townDirectory(townId).path, p.joinAll(p.posix.split(storagePath)));

  /// Download a town. Returns the record that was stored.
  ///
  /// Everything lands in a `.partial` directory first and is moved into place
  /// once the last file arrives. A download that fails, or is cancelled, or is
  /// killed with the app, therefore leaves **no** trace that the town is
  /// present — which is the only safe direction to fail. A town that claims to
  /// be downloaded and is missing its map is worse than one that admits it was
  /// never downloaded.
  Future<DownloadRecord> download(
    OfflineBundle bundle, {
    required List<String> assetPaths,
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    // The pack rides along as just another Storage path. De-duplicated because
    // two destinations can reference the same photo and nobody should pay for
    // it twice.
    final paths = <String>{
      ...assetPaths,
      bundle.tilePackRef,
    }.where((path) => path.isNotEmpty).toList();

    final staging = _stagingDirectory(bundle.townId);
    // A leftover from an earlier attempt is not a resume point: we cannot tell
    // which of its files came from which version of the bundle.
    if (staging.existsSync()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    var bytes = 0;
    try {
      for (final (index, path) in paths.indexed) {
        if (cancel?.isCancelled ?? false) throw const DownloadCancelled();

        onProgress?.call(
          DownloadProgress(
            filesDone: index,
            filesTotal: paths.length,
            bytesDone: bytes,
            currentPath: path,
          ),
        );

        final data = await _fetcher.fetch(path);
        final file = File(p.join(staging.path, p.joinAll(p.posix.split(path))));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data, flush: true);
        bytes += data.length;
      }

      if (cancel?.isCancelled ?? false) throw const DownloadCancelled();

      final target = townDirectory(bundle.townId);

      // Order matters. The record is dropped *before* the old directory is,
      // so a crash mid-swap leaves the town looking absent rather than
      // downloaded-but-missing. Re-downloading is cheap; a phantom town is a
      // bug report.
      await _store.remove(bundle.townId);
      if (target.existsSync()) await target.delete(recursive: true);
      await target.parent.create(recursive: true);
      await staging.rename(target.path);

      final record = DownloadRecord(
        townId: bundle.townId,
        version: bundle.version,
        bytes: bytes,
        completedAt: DateTime.now(),
        packPath: localPathFor(bundle.townId, bundle.tilePackRef),
      );
      await _store.save(record);

      onProgress?.call(
        DownloadProgress(
          filesDone: paths.length,
          filesTotal: paths.length,
          bytesDone: bytes,
        ),
      );
      return record;
    } catch (_) {
      if (staging.existsSync()) {
        try {
          await staging.delete(recursive: true);
        } catch (e) {
          // Worth saying, not worth masking the original failure with.
          debugPrint("Could not clean up $staging: $e");
        }
      }
      rethrow;
    }
  }

  /// Remove a downloaded town from this device.
  ///
  /// Record first, for the same reason as above.
  Future<void> delete(String townId) async {
    await _store.remove(townId);
    final dir = townDirectory(townId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
