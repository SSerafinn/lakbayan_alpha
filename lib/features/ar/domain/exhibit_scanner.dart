import "package:flutter/material.dart";

/// Whether this phone can scan exhibits with its camera (D-18).
enum ArSupport {
  /// ARCore runs here. It may still need installing or updating from the
  /// Play Store; the scan screen asks for that itself.
  available,

  /// No ARCore on this phone, or not an Android phone at all. Exhibits are a
  /// plain list.
  unsupported,
}

/// One image the scan screen looks for, and what it shows when it finds it.
@immutable
class ScanMarker {
  const ScanMarker({
    required this.exhibitId,
    required this.filePath,
    required this.widthM,
    required this.title,
    this.description,
  });

  final String exhibitId;

  /// A file on this phone: ARCore builds its image database from bitmaps,
  /// not from Storage paths.
  final String filePath;

  /// The marker's real width in metres.
  final double widthM;

  /// On the card that appears over the camera when the image is found.
  final String title;
  final String? description;

  Map<String, Object?> toMap() => {
    "id": exhibitId,
    "path": filePath,
    "widthM": widthM,
    "title": title,
    "description": description,
  };
}

/// The app's colours for the native scan screen, which cannot read the
/// Flutter theme: handed over with every scan, so `lib/core/theme/` stays
/// the one place they are defined.
@immutable
class ScanColors {
  const ScanColors({
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  ScanColors.of(ColorScheme scheme)
    : primary = scheme.primary,
      onPrimary = scheme.onPrimary,
      surface = scheme.surface,
      onSurface = scheme.onSurface,
      onSurfaceVariant = scheme.onSurfaceVariant;

  final Color primary;
  final Color onPrimary;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;

  /// As Android colour ints, ARGB.
  Map<String, int> toMap() => {
    "primary": primary.toARGB32(),
    "onPrimary": onPrimary.toARGB32(),
    "surface": surface.toARGB32(),
    "onSurface": onSurface.toARGB32(),
    "onSurfaceVariant": onSurfaceVariant.toARGB32(),
  };
}

/// What came of opening the scan screen.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// The visitor found an exhibit and tapped its card.
final class ExhibitRecognised extends ScanOutcome {
  const ExhibitRecognised(this.exhibitId);

  final String exhibitId;
}

/// The visitor closed the scan screen without choosing anything.
final class ScanClosed extends ScanOutcome {
  const ScanClosed();
}

/// The scan screen could not run. The visitor gets the exhibits as a list.
final class ScanUnavailable extends ScanOutcome {
  const ScanUnavailable(this.problem);

  final ScanProblem problem;
}

enum ScanProblem {
  /// The visitor refused the camera.
  cameraDenied,

  /// ARCore would not start: not installed and could not be, or a session
  /// that failed to open.
  arUnavailable,
}

/// The camera side of the AR pilot, behind an interface so everything around
/// it runs, and is tested, without a camera. On Android it is a separate
/// native screen over a method channel (D-18); everywhere else it reports
/// [ArSupport.unsupported].
abstract interface class ExhibitScanner {
  Future<ArSupport> support();

  /// Opens the scan screen for [markers], under [placeName], and waits for
  /// the visitor to find an exhibit or leave.
  Future<ScanOutcome> scan({
    required String placeName,
    required List<ScanMarker> markers,
    required ScanColors colors,
  });
}
