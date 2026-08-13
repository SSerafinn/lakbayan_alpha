import "package:cached_network_image/cached_network_image.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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
/// rotation. The cost is this extra resolve step, after which
/// `cached_network_image` caches the bytes on disk — which is also what makes a
/// downloaded town's photos work offline.
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
