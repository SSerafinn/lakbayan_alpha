import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

import "../domain/exhibit_scanner.dart";

/// [ExhibitScanner] over the method channel to `ExhibitScanActivity`
/// (D-18), the native scan screen in `android/`.
///
/// Every failure to reach it reads as "this phone cannot scan": a missing
/// plugin on the web or iOS, an error from a phone ARCore has never heard of.
/// The exhibits are still there as a list, so nothing here throws.
class ChannelExhibitScanner implements ExhibitScanner {
  const ChannelExhibitScanner([this._channel = channel]);

  static const channel = MethodChannel("ph.gov.cagayan.lakbayan/ar");

  final MethodChannel _channel;

  @override
  Future<ArSupport> support() async {
    try {
      final answer = await _channel.invokeMethod<String>("support");
      // "installable" and "unknown" still get the camera: the scan screen
      // offers the install, and checks again before it opens the camera.
      return answer == null || answer == "unsupported"
          ? ArSupport.unsupported
          : ArSupport.available;
    } on MissingPluginException {
      return ArSupport.unsupported;
    } on PlatformException catch (e) {
      debugPrint("Couldn't ask whether this phone runs ARCore: $e");
      return ArSupport.unsupported;
    }
  }

  @override
  Future<ScanOutcome> scan({
    required String placeName,
    required List<ScanMarker> markers,
    required ScanColors colors,
  }) async {
    try {
      final answer = await _channel.invokeMapMethod<String, Object?>("scan", {
        "placeName": placeName,
        "markers": [for (final marker in markers) marker.toMap()],
        "colors": colors.toMap(),
      });
      return switch (answer) {
        {"result": "found", "id": final String id} => ExhibitRecognised(id),
        {"result": "cameraDenied"} => const ScanUnavailable(
          ScanProblem.cameraDenied,
        ),
        {"result": "unavailable"} => const ScanUnavailable(
          ScanProblem.arUnavailable,
        ),
        _ => const ScanClosed(),
      };
    } on MissingPluginException {
      return const ScanUnavailable(ScanProblem.arUnavailable);
    } on PlatformException catch (e) {
      debugPrint("The scan screen failed: $e");
      return const ScanUnavailable(ScanProblem.arUnavailable);
    }
  }
}
