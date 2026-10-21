import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

/// Puts AR marker images on this phone as files, which is what ARCore builds
/// its image database from (D-18).
///
/// A downloaded town already has them, and that copy wins. Otherwise the
/// image is fetched once and kept in the app's cache directory, under its
/// Storage path. That is safe to keep for as long as the OS lets it be,
/// because the CMS writes a replaced marker to a fresh
/// `{exhibitId}-{timestamp}.{ext}` path, the same as photos (see
/// `localAssetFor`): what is cached under a path is the right image for it.
class MarkerCache {
  MarkerCache({
    required this.cacheRoot,
    required this.fetch,
    required this.downloaded,
    this.fetchTimeout = const Duration(seconds: 20),
  });

  /// The app's cache directory. A function, so nothing asks the platform for
  /// it until a museum is scanned.
  final Future<Directory> Function() cacheRoot;

  final Future<Uint8List> Function(String storagePath) fetch;

  /// The downloaded town's copy of a Storage object, if there is one.
  final File? Function(String storagePath) downloaded;

  /// Storage retries for minutes with no signal. A visitor waiting at the
  /// scan button should hear sooner that this museum is not on the phone.
  final Duration fetchTimeout;

  /// A file for [storagePath], or null when there is none and none could be
  /// fetched.
  Future<File?> fileFor(String storagePath) async {
    final segments = storagePath.split("/");
    if (segments.any((s) => s.isEmpty || s == "." || s == "..")) return null;

    final local = downloaded(storagePath);
    if (local != null) return local;

    final root = await cacheRoot();
    final file = File(p.joinAll([root.path, "ar-markers", ...segments]));
    if (file.existsSync()) return file;

    try {
      final bytes = await fetch(storagePath).timeout(fetchTimeout);
      await file.parent.create(recursive: true);
      // Written aside and moved into place, so a scan started while a fetch
      // was cut short never reads half an image.
      final part = File("${file.path}.part");
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
      return file;
    } on Object catch (e) {
      debugPrint("AR marker '$storagePath' is not on this phone: $e");
      return null;
    }
  }
}
