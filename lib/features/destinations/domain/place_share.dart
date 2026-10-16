import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:share_plus/share_plus.dart";

import "../../../core/models/destination.dart";

part "place_share.g.dart";

/// Hands text to the phone's share sheet. Throws when the sheet cannot be
/// opened; a person closing it without picking anything is not a failure.
///
/// A function behind a provider, the same arrangement as `contactLauncher`:
/// the share sheet is a plugin call and a widget test has none, so this is
/// the one line a test replaces to see what a tap on Share sends.
typedef TextSharer = Future<void> Function(String text, {String? subject});

@Riverpod(keepAlive: true)
TextSharer textSharer(Ref ref) =>
    (text, {subject}) =>
        SharePlus.instance.share(ShareParams(text: text, subject: subject));

/// What Share on Place detail sends: the name, where it is, a short line of
/// description, and a Google Maps link to the coordinates.
///
/// **Text, not a link into the app.** There is no public web page and no
/// app-link domain yet, so there is nothing for a Lakbayan link to open on a
/// friend's phone, and no store listing to send them to either. The map link
/// is what lets somebody without the app find the place. It is all built from
/// the cached document, so sharing works offline.
///
/// Only the coordinates are certain to be there. A blank name, town or
/// description drops its line rather than leaving a gap.
String placeShareText(Destination place) {
  final name = place.name.trim();
  final description = shortDescription(place.description);
  return [
    if (name.isNotEmpty) name,
    _whereIn(place.town),
    if (description != null) "\n$description",
    "\n${placeMapUri(lat: place.coords.lat, lng: place.coords.lng)}",
  ].join("\n");
}

/// The share sheet's subject, which an email app uses as the subject line.
/// Null when the place has no name, so the app picks its own.
String? placeShareSubject(Destination place) {
  final name = place.name.trim();
  return name.isEmpty ? null : name;
}

/// The town with the province after it: a friend in Manila does not know
/// where Peñablanca is. The province alone when the town is blank, and the
/// town alone when it already says Cagayan.
String _whereIn(String town) {
  final trimmed = town.trim();
  if (trimmed.isEmpty) return "Cagayan";
  if (trimmed.toLowerCase().contains("cagayan")) return trimmed;
  return "$trimmed, Cagayan";
}

/// A couple of sentences: enough to say what the place is without the
/// message turning into the whole page.
const shareDescriptionLimit = 200;

/// [description] with its whitespace folded to single spaces and, past
/// [limit] characters, cut at the last whole word with an ellipsis. Null when
/// there is nothing to say.
///
/// No attempt at ending on a sentence: the province's names are full of
/// abbreviations ("Sta. Ana", "Sto. Niño"), and taking their full stop for a
/// sentence's would end the message on "Sta.". A cut word is the only worse
/// outcome, so a single run longer than [limit] (a pasted link, say) is the
/// one place it happens.
String? shortDescription(
  String description, {
  int limit = shareDescriptionLimit,
}) {
  final text = description.trim().replaceAll(RegExp(r"\s+"), " ");
  if (text.isEmpty) return null;
  if (text.length <= limit) return text;
  // One past the limit, so a space exactly there still counts as a break.
  final space = text.substring(0, limit + 1).lastIndexOf(" ");
  final cut = space > 0 ? text.substring(0, space) : text.substring(0, limit);
  // "…the river," + "…" reads as a stutter; the ellipsis is the punctuation.
  return "${cut.replaceFirst(RegExp(r"[\s.,;:!?\-–—]+$"), "")}…";
}

/// Google Maps searching on the coordinates, which drops a pin there in the
/// app or the browser — whichever the friend's phone has.
///
/// The sibling of `directionsWebUri` in `maps/domain/directions.dart`, built
/// the same way; that one asks for a route from wherever the reader is, which
/// is not what a recommendation is. A pin, not a search on the name: the name
/// may match somewhere else, or nothing at all; the coordinates are the place.
Uri placeMapUri({required double lat, required double lng}) => Uri.https(
  "www.google.com",
  "/maps/search/",
  {"api": "1", "query": "$lat,$lng"},
);
