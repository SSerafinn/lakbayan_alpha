import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/models/guide.dart";
import "../../auth/domain/auth_providers.dart";
import "../data/guide_repository.dart";

part "guide_providers.g.dart";

@Riverpod(keepAlive: true)
GuideRepository guideRepository(Ref ref) => GuideRepository(
  FirebaseFirestore.instance,
  reporter: ref.watch(errorReporterProvider),
);

/// Hands a guide's `tel:` or `mailto:` link to the phone, and says whether
/// anything took it.
///
/// A function behind a provider, the same arrangement as `audioUrlResolver`:
/// `launchUrl` is a plugin call and a widget test has no dialer, so this is
/// the one line a test replaces to prove what a failed tap does.
typedef ContactLauncher = Future<bool> Function(Uri uri);

@Riverpod(keepAlive: true)
ContactLauncher contactLauncher(Ref ref) => launchUrl;

/// The province's local guides. Empty for a guest rather than an error: the
/// rules only let a signed-in person read somebody's contact details.
@riverpod
Stream<List<Guide>> guides(Ref ref) {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return Stream.value(const []);
  return ref.watch(guideRepositoryProvider).watchAll();
}

/// Where tapping a guide goes: a call when the contact reads as a number,
/// an email when it reads as an address, otherwise nowhere (the text itself
/// is on the card).
///
/// **The first number, not every digit.** `contact` is free text
/// (`docs/DATA_MODEL.md`), and a guide with two phones writes both. Stripping
/// the whole field down to its digits used to join them into one number
/// nobody owns — "0917 123 4567 / 0918 765 4321" dialled
/// `09171234567` + `09187654321`. Each number-shaped run is read on its own,
/// with the spaces, dots, dashes and brackets people put inside a number.
Uri? contactUri(String contact) {
  final email = RegExp(r"[\w.+-]+@[\w-]+\.[\w.]+").firstMatch(contact);
  if (email != null) return Uri(scheme: "mailto", path: email.group(0));
  for (final run in _numberRun.allMatches(contact)) {
    final number = run.group(0)!.replaceAll(RegExp(r"[^\d+]"), "");
    final digits = number.length - (number.startsWith("+") ? 1 : 0);
    // Seven is a Philippine landline without its area code. Past fifteen —
    // the E.164 ceiling — the run is two numbers with only a space between
    // them, and there is no telling where one ends: better no link, and the
    // text on the card, than a call to a number that does not exist.
    if (digits >= 7 && digits <= 15) return Uri(scheme: "tel", path: number);
  }
  return null;
}

/// A run that can be one phone number: an optional `+`, then digits with the
/// separators people type between them. Starts and ends on a digit, so the
/// slash or "or" between two numbers ends the run.
///
/// A plain space, not `\s`: a line break is how a CMS text field most often
/// separates two numbers, and `\s` would read straight across it.
final _numberRun = RegExp(r"\+?\d[\d ().-]*\d");
