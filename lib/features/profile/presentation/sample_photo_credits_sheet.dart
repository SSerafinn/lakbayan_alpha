import "dart:async";

import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../destinations/data/sample_photo_credits.dart";

/// Who took the sample preview's photographs, and under what licence.
///
/// The licences ask for the credit to travel with the photographs, and a
/// file in the repository does not reach somebody holding the app. This is
/// the credit where the photographs are: beside the switch that shows them.
Future<void> showSamplePhotoCredits(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const _CreditsSheet());

class _CreditsSheet extends StatelessWidget {
  const _CreditsSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSheet(
      title: "Photo Credits",
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: SliverList.list(
            children: [
              Text(
                "The sample preview's photographs are other people's work, "
                "from Wikimedia Commons, resized and otherwise unchanged. "
                "Tap one to see the original.",
                style: AppTypography.bodyMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.x3),
              for (final credit in samplePhotoCredits)
                _CreditRow(credit: credit),
            ],
          ),
        ),
      ],
    );
  }
}

/// One credit, wrapping rather than truncating.
///
/// Not `GroupedRow`: that holds each line to one with an ellipsis, which is
/// right for a list of places and wrong here. An attribution cut off after
/// the author's name has lost its licence, and one cut off before it has
/// lost the author — either way it has stopped being the credit.
class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final SamplePhotoCredit credit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final second = AppTypography.secondLine.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Semantics(
      button: true,
      label:
          "${credit.place}. Photograph by ${credit.author}, "
          "${credit.licence}. Opens the original.",
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadii.smAll,
        // Failure is swallowed, as on the map's attribution: the credit is
        // on screen either way, and the link is the courtesy on top of it.
        onTap: () => unawaited(
          launchUrl(
            Uri.parse(credit.source),
            mode: LaunchMode.externalApplication,
          ).catchError((_) => false),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(credit.place, style: AppTypography.titleSmall),
                Text(credit.author, style: second),
                Text(credit.licence, style: second),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
