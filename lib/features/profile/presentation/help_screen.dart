import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/app_settings.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/chrome/page_title.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../guides/domain/guide_providers.dart";
import "../data/settings_repository.dart";
import "../domain/settings_providers.dart";

/// Help. **One job:** reach someone. **Emotion:** steady; the number is
/// right there.
///
/// **Anatomy.** Back and the large title; the emergency lines first, each a
/// row that calls; then the tourism office as the province wrote it. No row
/// glyphs (D-19). Every value is shown as text as well as made tappable, so
/// a tablet with no dialer still has the number to read out.
///
/// Works offline: the lines come from the same document Explore reads for
/// its notice on every launch (`appSettingsProvider`), so they are cached
/// before anyone opens this. On a phone that has never been online there is
/// still 911 ([emergencyLines]).
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final app = settings.value;
    final contact = app?.contact;

    // Decided by what there is, a value or an error, never by isLoading:
    // Riverpod retries a failed provider, and reads as loading meanwhile.
    final Widget office;
    if (contact != null && _hasAny(contact)) {
      office = _Office(contact: contact);
    } else if (settings.hasValue) {
      office = const QuietNote(
        "The tourism office hasn't added its contact details yet.",
      );
    } else if (settings.error is SettingsNotYetLoaded) {
      office = const QuietNote(
        "The tourism office's details load the first time you're online, "
        "and stay on your phone after that. The lines above work now.",
      );
    } else if (settings.hasError) {
      office = const QuietNote("Couldn't load the tourism office's details.");
    } else {
      office = const SizedBox.shrink();
    }

    return EntranceScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.x2,
              AppSpace.gutter,
              MediaQuery.viewPaddingOf(context).bottom + AppSpace.section,
            ),
            children: [
              const PageTitle("Help"),
              const SizedBox(height: AppSpace.section),
              Entrance(
                order: 1,
                child: GroupedSection(
                  heading: "Emergency Lines",
                  children: [
                    for (final line in emergencyLines(app?.hotlines ?? []))
                      _ReachRow(title: line.label, value: line.number),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.section),
              Entrance(order: 2, child: office),
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasAny(OfficeContact c) => [
    c.office,
    c.phone,
    c.email,
    c.hours,
    c.address,
  ].any((v) => v?.trim().isNotEmpty ?? false);
}

/// The office as the province wrote it: each field it filled, in a fixed
/// order, phone and email tappable.
class _Office extends StatelessWidget {
  const _Office({required this.contact});

  final OfficeContact contact;

  @override
  Widget build(BuildContext context) {
    String? filled(String? v) => (v?.trim().isEmpty ?? true) ? null : v!.trim();
    final phone = filled(contact.phone);
    final email = filled(contact.email);
    final hours = filled(contact.hours);
    final address = filled(contact.address);

    return GroupedSection(
      heading: filled(contact.office) ?? "Tourism Office",
      children: [
        if (phone != null) _ReachRow(value: phone),
        if (email != null) _ReachRow(value: email),
        if (hours != null) GroupedRow(title: hours, dense: true),
        if (address != null) GroupedRow(title: address, dense: true),
      ],
    );
  }
}

/// A row that calls or emails [value]. With a [title] (a hotline's name) the
/// value is the second line; without, the value is the row.
///
/// Not tappable when [value] reads as neither a number nor an address
/// ([reachUri]); the text is still there to read.
class _ReachRow extends ConsumerWidget {
  const _ReachRow({required this.value, this.title});

  final String value;
  final String? title;

  /// Hand the number or address to the phone, and say so when it cannot
  /// take it, the same as a guide's card.
  Future<void> _reach(BuildContext context, WidgetRef ref, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(contactLauncherProvider)(uri);
    } catch (_) {
      // No handler for the scheme throws on some platforms rather than
      // answering false. Either way the answer is the same message.
    }
    if (opened) return;
    messenger.showSnackBar(
      SnackBar(content: Text("No app here can open that. It's $value.")),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = reachUri(value);
    return GroupedRow(
      title: title ?? value,
      subtitle: title == null ? null : value,
      dense: title == null,
      // A call, not a page: no chevron.
      trailing: GroupedRow.noAccessory,
      onTap: uri == null ? null : () => unawaited(_reach(context, ref, uri)),
    );
  }
}

/// Where tapping a Help row goes: what `contactUri` makes of it, or a call
/// to a short code.
///
/// `contactUri` wants a whole phone number, seven digits or more, because a
/// guide's contact is free text with digits in it that are not one. An
/// emergency line is different: 911, or the Red Cross's 143, is the whole
/// field, and is exactly the number someone needs to reach.
@visibleForTesting
Uri? reachUri(String value) {
  final uri = contactUri(value);
  if (uri != null) return uri;
  final short = RegExp(r"^\s*(\d{3,6})\s*$").firstMatch(value);
  return short == null ? null : Uri(scheme: "tel", path: short.group(1));
}
