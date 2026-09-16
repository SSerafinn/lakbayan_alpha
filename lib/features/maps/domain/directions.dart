import "package:url_launcher/url_launcher.dart";

/// Hand a destination to whatever map app the phone has.
///
/// Driving directions need live traffic and a routing engine, which no offline
/// pack can provide (D-11), so this is a hand-off rather than something the app
/// draws. The route on our own map is the authored polyline; this is the "take
/// me there" that leaves.
///
/// `geo:lat,lng?q=lat,lng(Label)` rather than a bare `geo:lat,lng`: the bare
/// form centres a map on the coordinate without marking anything, so there is
/// nothing to ask directions *to*. The `q` is what makes it a destination.
///
/// Falls back to Google Maps over https when no app claims `geo:` — a phone
/// with no map app still has a browser, and refusing outright would be worse
/// than opening a web page. Both schemes need their `<queries>` entry in
/// `AndroidManifest.xml` or [canLaunchUrl] answers false on API 30 and up.
///
/// Returns false when nothing could be opened, so the caller can say so rather
/// than leave a tap looking ignored.
Future<bool> openDirections({
  required double lat,
  required double lng,
  required String label,
}) async {
  final geo = directionsUri(lat: lat, lng: lng, label: label);

  try {
    if (await canLaunchUrl(geo)) {
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) {
        return true;
      }
    }
  } catch (_) {
    // A platform that has no notion of `geo:` at all. The web fallback below
    // is the answer for it too, so there is nothing to report here.
  }

  try {
    return await launchUrl(
      directionsWebUri(lat: lat, lng: lng),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// The `geo:` URI [openDirections] hands to the device.
///
/// Built through [Uri] rather than interpolated into a string so the label is
/// percent-encoded: a place called "Our Lady of Piat, Cagayan" carries a comma,
/// and a comma is the separator inside `q`.
Uri directionsUri({
  required double lat,
  required double lng,
  required String label,
}) => Uri(
  scheme: "geo",
  path: "$lat,$lng",
  queryParameters: {"q": "$lat,$lng($label)"},
);

/// The browser fallback, for a phone with no app that claims `geo:`.
Uri directionsWebUri({required double lat, required double lng}) => Uri.https(
  "www.google.com",
  "/maps/dir/",
  {"api": "1", "destination": "$lat,$lng"},
);
