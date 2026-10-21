import "package:lakbayan/features/ar/domain/exhibit_scanner.dart";

/// An [ExhibitScanner] with no camera behind it: it answers with whatever a
/// test sets, and records what it was asked to look for.
class FakeExhibitScanner implements ExhibitScanner {
  FakeExhibitScanner({
    this.supports = ArSupport.available,
    this.outcome = const ScanClosed(),
  });

  ArSupport supports;

  /// What the next scan comes back with.
  ScanOutcome outcome;

  /// The markers of every scan, in order.
  final scans = <List<ScanMarker>>[];
  String? lastPlaceName;

  @override
  Future<ArSupport> support() async => supports;

  @override
  Future<ScanOutcome> scan({
    required String placeName,
    required List<ScanMarker> markers,
    required ScanColors colors,
  }) async {
    lastPlaceName = placeName;
    scans.add(markers);
    return outcome;
  }
}
