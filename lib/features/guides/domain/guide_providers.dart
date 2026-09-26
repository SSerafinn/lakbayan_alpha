import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/guide.dart";
import "../../auth/domain/auth_providers.dart";
import "../data/guide_repository.dart";

part "guide_providers.g.dart";

@Riverpod(keepAlive: true)
GuideRepository guideRepository(Ref ref) =>
    GuideRepository(FirebaseFirestore.instance);

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
Uri? contactUri(String contact) {
  final email = RegExp(r"[\w.+-]+@[\w-]+\.[\w.]+").firstMatch(contact);
  if (email != null) return Uri(scheme: "mailto", path: email.group(0));
  final digits = contact.replaceAll(RegExp(r"[^\d+]"), "");
  if (digits.length >= 7) return Uri(scheme: "tel", path: digits);
  return null;
}
