import "package:cached_network_image/cached_network_image.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// core reaching into a feature, which the layout otherwise avoids — the same
// exception `core/router` makes. Every photo in the app is drawn by the widget
// below, so this is the one place the offline lookup has to happen; pushing it
// out to the eleven screens that use it would be worse in every way.
import "../../features/offline/domain/local_assets.dart";
import "lakbayan_badge.dart";

/// Resolves a Cloud Storage path to a download URL.
///
/// Kept as a provider so the round trip is cached per path for the session — a
/// grid of cards would otherwise re-resolve the same URL on every rebuild and
/// scroll. `keepAlive` because these URLs are stable and the cost is a network
/// call we do not want to repeat.
final storageUrlProvider = FutureProvider.family<String, String>((
  ref,
  path,
) async {
  ref.keepAlive();
  return FirebaseStorage.instance.ref(path).getDownloadURL();
});

/// Displays an image stored as a Storage **path** (see `docs/DATA_MODEL.md`).
///
/// Documents hold paths rather than download URLs because a path survives token
/// rotation. The cost is a resolve step, after which `cached_network_image`
/// caches the bytes on disk.
///
/// A downloaded town short-circuits all of that: [localAssetProvider] finds the
/// file `TownDownloader` already wrote and it is read straight off disk. That
/// path involves no network call at all, which is the difference between a
/// downloaded town working in a cave and merely having been downloaded. The
/// HTTP cache is not a substitute — it only holds what this phone happened to
/// have looked at.
class StorageImage extends ConsumerWidget {
  const StorageImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sample photography is a bundled asset; nothing to resolve.
    if (path.startsWith("assets/")) {
      final asset = Image.asset(path, fit: fit);
      return borderRadius == null
          ? asset
          : ClipRRect(borderRadius: borderRadius!, child: asset);
    }

    // Downloaded: read it off disk and never mention the network.
    final local = ref.watch(localAssetProvider(path));
    if (local != null) {
      final file = Image.file(
        local,
        fit: fit,
        // The file existed a moment ago and could still be unreadable — a
        // half-written byte range, or a town removed between the check and the
        // decode. Falling back to the placeholder keeps the card intact.
        errorBuilder: (_, _, _) => ImagePlaceholder(borderRadius: borderRadius),
      );
      return borderRadius == null
          ? file
          : ClipRRect(borderRadius: borderRadius!, child: file);
    }

    final url = ref.watch(storageUrlProvider(path));

    final child = url.when(
      loading: () => ImagePlaceholder(borderRadius: borderRadius),
      // A missing image should not blank out the card around it — the rest of
      // the content is still useful.
      error: (_, _) => ImagePlaceholder(borderRadius: borderRadius),
      data: (resolved) => CachedNetworkImage(
        imageUrl: resolved,
        fit: fit,
        placeholder: (_, _) => ImagePlaceholder(borderRadius: borderRadius),
        errorWidget: (_, _, _) => ImagePlaceholder(borderRadius: borderRadius),
      ),
    );

    return borderRadius == null
        ? child
        : ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

/// A cover photo by Storage path, or the placeholder when there is none.
class CoverImage extends StatelessWidget {
  const CoverImage(this.path, {super.key});

  final String? path;

  @override
  Widget build(BuildContext context) => path == null
      ? const ImagePlaceholder(borderRadius: BorderRadius.zero)
      : StorageImage(path: path!);
}
