import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../itineraries/domain/itinerary_copy.dart";
import "../data/settings_repository.dart";
import "../domain/settings_providers.dart";

/// Which of the province's two texts a [PolicyScreen] shows.
enum Policy {
  privacy("Privacy policy"),
  terms("Terms of use");

  const Policy(this.title);

  final String title;
}

/// The privacy policy or the terms of use, as the province wrote them in the
/// CMS. **One job:** read it. Back, the title, when it last changed, then the
/// text: plain paragraphs, selectable so a passage can be quoted.
///
/// The Play Store requires the privacy policy to be reachable in the app;
/// this is where Profile sends it.
class PolicyScreen extends ConsumerWidget {
  const PolicyScreen({required this.policy, super.key});

  final Policy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final policies = ref.watch(policiesProvider);

    // Decided by what there is, a value or an error, never by isLoading:
    // Riverpod retries a failed provider, and reads as loading meanwhile.
    List<Widget> body() {
      final error = policies.error;
      if (!policies.hasValue) {
        return [
          if (error is SettingsNotYetLoaded)
            const QuietNote(
              "This loads the first time you're online, and stays on your "
              "phone after that.",
            )
          else if (error != null)
            QuietNote("Couldn't load the ${policy.title.toLowerCase()}."),
        ];
      }
      final p = policies.value;
      final text = (policy == Policy.privacy ? p?.privacy : p?.terms) ?? "";
      final updated = policy == Policy.privacy
          ? p?.privacyUpdatedAt
          : p?.termsUpdatedAt;
      if (text.trim().isEmpty) {
        return [
          QuietNote(
            "The province hasn't published its "
            "${policy.title.toLowerCase()} yet.",
          ),
        ];
      }
      return [
        if (updated != null)
          Text(
            "Last updated ${shortDate(updated)} ${updated.year}",
            style: AppTypography.secondLine.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpace.x3),
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final paragraph in paragraphs(text))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x3),
                  child: Text(paragraph, style: AppTypography.bodyLarge),
                ),
            ],
          ),
        ),
      ];
    }

    return Scaffold(
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
            Row(
              children: [
                SymbolButton(
                  icon: AppIcons.back,
                  tooltip: "Back",
                  onTap: () => context.popOrHome(),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(policy.title, style: AppTypography.titleLarge),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.section),
            ...body(),
          ],
        ),
      ),
    );
  }
}

/// The CMS's plain text as paragraphs: blank lines separate them
/// (`docs/DATA_MODEL.md`). Single line breaks inside one are kept, so a
/// list the province typed one item per line stays a list.
@visibleForTesting
List<String> paragraphs(String text) => [
  for (final block in text.replaceAll("\r\n", "\n").split(RegExp(r"\n\s*\n")))
    if (block.trim().isNotEmpty) block.trim(),
];
