import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/models/app_settings.dart";
import "../data/settings_repository.dart";

part "settings_providers.g.dart";

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(
  FirebaseFirestore.instance,
  reporter: ref.watch(errorReporterProvider),
);

/// The tourism office, the emergency lines and the Explore notice.
///
/// Kept alive and watched by Explore on every launch, for its notice. That is
/// also what keeps the emergency lines on the phone: Firestore caches the
/// document Explore read, so Help opens offline even if it never has before.
@Riverpod(keepAlive: true)
Stream<AppSettings?> appSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchApp();

/// The privacy policy and terms, read when one is opened.
@riverpod
Stream<PolicySettings?> policies(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchPolicies();

/// Explore's notice now, or null: none written, its text cleared, or past its
/// end. Until it loads there is no notice rather than a placeholder for one.
@riverpod
Announcement? liveAnnouncement(Ref ref) {
  final notice = ref.watch(appSettingsProvider).value?.announcement;
  return notice != null && notice.isLiveAt(DateTime.now()) ? notice : null;
}

/// The national emergency number, reachable from anywhere in the
/// Philippines.
const nationalEmergency = Hotline(label: "National emergency", number: "911");

/// The lines Help lists: the province's, in its order, then
/// [nationalEmergency] unless the province already lists 911.
///
/// 911 is there before anything has loaded, so Help is never an empty
/// screen at the moment someone most needs it — offline on a phone that has
/// never been online, or before the province has written any.
List<Hotline> emergencyLines(List<Hotline> province) {
  final listed = province.any(
    (line) => line.number.replaceAll(RegExp(r"\D"), "") == "911",
  );
  return [...province, if (!listed) nationalEmergency];
}
