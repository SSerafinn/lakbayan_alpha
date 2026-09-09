import "dart:typed_data";

import "package:firebase_storage/firebase_storage.dart";

/// Pulls one Storage object into memory.
///
/// An interface for the same reason [Narrator] is one: the real implementation
/// is a plugin that does not run in a widget test, and a download manager whose
/// failure paths cannot be exercised is a download manager whose failure paths
/// are wrong.
abstract interface class AssetFetcher {
  /// Bytes at a Storage **path** — documents hold paths, not URLs, because a
  /// path survives token rotation (`docs/DATA_MODEL.md`).
  Future<Uint8List> fetch(String storagePath);
}

class StorageAssetFetcher implements AssetFetcher {
  const StorageAssetFetcher({this.maxBytes = 64 * 1024 * 1024});

  /// Ceiling for a single object. A town pack is a few MB and a photo far
  /// less; anything approaching this is a mistake upstream, and `getData`
  /// needs *some* bound or a bad path can exhaust memory on a cheap phone.
  final int maxBytes;

  @override
  Future<Uint8List> fetch(String storagePath) async {
    final data = await FirebaseStorage.instance
        .ref(storagePath)
        .getData(maxBytes);
    if (data == null) {
      // getData returns null when the object exists but is larger than the
      // cap. Saying which path is the difference between a five-minute fix
      // and an afternoon.
      throw StateError(
        "'$storagePath' is larger than the ${maxBytes ~/ (1024 * 1024)} MB "
        "download limit.",
      );
    }
    return data;
  }
}
