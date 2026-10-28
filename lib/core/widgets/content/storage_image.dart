import "dart:ui" show ImageFilter;

import "package:cached_network_image/cached_network_image.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Core reaching into a feature, as `core/router` does: every photo is drawn
// here, so this is the one place the offline lookup can happen.
import "../../../features/offline/domain/local_assets.dart";
import "../../theme/app_dimens.dart";
import "../../theme/app_motion.dart";

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

/// Displays an image stored as a Storage path.
///
/// Paths survive token rotation; the resolve step is cached per session.
/// Downloaded towns short-circuit to a local file — no network call at all.
/// Decoded at display size to avoid holding a 4000px photo in memory for a 56dp slot.
class StorageImage extends StatelessWidget {
  const StorageImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.decodeWidth,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Decode at this many pixels wide, whatever the box: a tiny copy
  /// stretched over a large one reads as a soft blur with no filter at all
  /// (Keep or skip's stage). Null decodes at the box's own size.
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final width = decodeWidth;
    final child = width != null
        ? _Decoded(
            path: path,
            fit: fit,
            decode: _DecodeSize(width: width),
            radius: borderRadius,
          )
        : LayoutBuilder(
            builder: (context, constraints) => _Decoded(
              path: path,
              fit: fit,
              decode: _DecodeSize.of(context, constraints),
              radius: borderRadius,
            ),
          );

    return borderRadius == null
        ? child
        : ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

/// A soft photo stage shared by Keep or Skip and the photo viewer.
/// A small decode with an image-only Gaussian blur, isolated from foreground
/// motion. The translucent shade keeps the photo visible under white controls.
class SoftPhotoBackdrop extends StatelessWidget {
  const SoftPhotoBackdrop({
    required this.path,
    required this.fallback,
    super.key,
  });

  final String? path;
  final Color fallback;

  static const _decodeWidth = 32;
  static const _blurSigma = 8.0;
  static const _shade = 0.4;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: fallback),
          if (path case final photo?)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _blurSigma,
                sigmaY: _blurSigma,
                tileMode: TileMode.mirror,
              ),
              child: StorageImage(path: photo, decodeWidth: _decodeWidth),
            ),
          ColoredBox(
            color: Theme.of(context).colorScheme.scrim
                .withValues(alpha: _shade),
          ),
        ],
      ),
    ),
  );
}

/// The photo at [decode]: a bundled asset as it is, anything else from
/// Storage.
class _Decoded extends StatelessWidget {
  const _Decoded({
    required this.path,
    required this.fit,
    required this.decode,
    required this.radius,
  });

  final String path;
  final BoxFit fit;
  final _DecodeSize decode;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    // Sample photography is a bundled asset; nothing to resolve.
    if (path.startsWith("assets/")) {
      return Image.asset(
        path,
        fit: fit,
        cacheWidth: decode.width,
        cacheHeight: decode.height,
        frameBuilder: _fadeIn,
      );
    }
    return _Stored(path: path, fit: fit, decode: decode, radius: radius);
  }
}

/// Fades a decoded frame in, unless it was already in memory.
Widget _fadeIn(
  BuildContext context,
  Widget image,
  int? frame,
  bool wasSynchronouslyLoaded,
) => wasSynchronouslyLoaded
    ? image
    : AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: AppMotion.edge,
        child: image,
      );

/// A Storage object: off disk when its town is downloaded, else resolved and
/// fetched through the HTTP cache.
class _Stored extends ConsumerWidget {
  const _Stored({
    required this.path,
    required this.fit,
    required this.decode,
    required this.radius,
  });

  final String path;
  final BoxFit fit;
  final _DecodeSize decode;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = ImagePlaceholder(borderRadius: radius);

    // Downloaded: read it off disk and never mention the network.
    final local = ref.watch(localAssetProvider(path));
    if (local != null) {
      return Image.file(
        local,
        fit: fit,
        cacheWidth: decode.width,
        cacheHeight: decode.height,
        frameBuilder: _fadeIn,
        // The file existed a moment ago and could still be unreadable — a
        // half-written byte range, or a town removed between the check and the
        // decode. Falling back to the placeholder keeps the card intact.
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    return ref
        .watch(storageUrlProvider(path))
        .when(
          loading: () => placeholder,
          // A missing image should not blank out the card around it — the
          // rest of the content is still useful.
          error: (_, _) => placeholder,
          data: (resolved) => CachedNetworkImage(
            imageUrl: resolved,
            fit: fit,
            memCacheWidth: decode.width,
            memCacheHeight: decode.height,
            fadeInDuration: AppMotion.edge,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          ),
        );
  }
}

/// The size to decode a photo at so it covers its slot without waste.
///
/// Only one side is given, so the photo keeps its aspect. For a slot at
/// least as wide as tall the width is decoded, and for a taller slot the
/// height; either way the decoded side allows for a photo up to
/// [_widestPhoto] on its long side, so `BoxFit.cover` never has to upscale.
class _DecodeSize {
  const _DecodeSize({this.width, this.height});

  final int? width;
  final int? height;

  /// Photography in this app is at most 3:2 either way.
  static const _widestPhoto = 1.5;

  static _DecodeSize of(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (!width.isFinite && !height.isFinite) return const _DecodeSize();
    if (!height.isFinite || (width.isFinite && width >= height)) {
      final side = height.isFinite
          ? (width > height * _widestPhoto ? width : height * _widestPhoto)
          : width;
      return _DecodeSize(width: (side * ratio).ceil());
    }
    final side = width.isFinite
        ? (height > width * _widestPhoto ? height : width * _widestPhoto)
        : height;
    return _DecodeSize(height: (side * ratio).ceil());
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

/// Where a photo goes before it has arrived, or when there is none: a flat,
/// quiet surface tier, not a gradient, so the space reads as waiting rather
/// than decorated.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    this.height,
    this.width,
    this.borderRadius,
    super.key,
  });

  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      borderRadius: borderRadius ?? AppRadii.smAll,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
  );
}
