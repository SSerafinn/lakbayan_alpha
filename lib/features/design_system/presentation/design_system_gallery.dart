import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/app_card.dart";
import "../../../core/widgets/bar_item_group.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/models/destination.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/section_heading.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../../destinations/data/sample_destinations.dart";
import "../../destinations/presentation/save_heart.dart";
import "../../itineraries/presentation/stop_picker.dart";

/// A living specimen of the design system, rendered with the real theme and
/// the real widgets.
///
/// Reachable at `/design-system` in debug builds so a change can be eyeballed
/// without wiring it into a feature first. If this and `docs/DESIGN_SYSTEM.md`
/// ever disagree, one of them is wrong. The two home designs it once switched
/// between now *are* Explore and Browse.
class DesignSystemGallery extends StatelessWidget {
  const DesignSystemGallery({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: _Tokens());
}

class _Tokens extends StatefulWidget {
  const _Tokens();

  @override
  State<_Tokens> createState() => _TokensState();
}

/// The specimen draws from the same `sampleDestinations` the debug preview
/// feeds the real screens, so the two can never show different content.
final _hero = sampleDestinations.firstWhere((d) => d.featured);
final _categories = [
  "All",
  for (final category in DestinationCategory.values)
    if (category != DestinationCategory.unknown) category.label,
];

class _TokensState extends State<_Tokens> {
  String _category = "Nature";

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.x4,
        topInset + AppSpace.x6,
        AppSpace.x4,
        AppSpace.x12,
      ),
      children: [
        Text("Design system", style: AppTypography.titleLarge),
        const SizedBox(height: AppSpace.x2),
        Text(
          "Tokens 2.1.0. Satoshi, white first; green is the action and the "
          "selection, blue is spatial, red is closed and saved, gold is featured.",
          style: AppTypography.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        const _Section("Surfaces"),
        _Swatches([
          ("surface", scheme.surface),
          ("lowest", scheme.surfaceContainerLowest),
          ("low", scheme.surfaceContainerLow),
          ("container", scheme.surfaceContainer),
          ("high", scheme.surfaceContainerHigh),
          ("highest", scheme.surfaceContainerHighest),
        ]),
        const _Section("Roles"),
        _Swatches([
          ("primary", scheme.primary),
          ("green text", context.lakbayan.textOnLightGreen),
          ("spatial", context.lakbayan.spatial),
          ("closed", context.lakbayan.closed),
          ("save", context.lakbayan.save),
          ("error", scheme.error),
          ("featured", context.lakbayan.featured),
        ]),
        const SizedBox(height: AppSpace.x3),
        _Swatches([
          for (final category in DestinationCategory.values)
            if (category != DestinationCategory.unknown)
              (category.label, context.lakbayan.categoryColor(category)),
        ]),

        const _Section("Type"),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Cagayan", style: AppTypography.display),
              const SizedBox(height: AppSpace.x3),
              Text("Callao Cave", style: AppTypography.hero),
              const SizedBox(height: AppSpace.x3),
              Text("Itineraries", style: AppTypography.titleLarge),
              const SizedBox(height: AppSpace.x3),
              Text("Popular this week", style: AppTypography.titleMedium),
              const SizedBox(height: AppSpace.x3),
              Text("Saved tours", style: AppTypography.groupHeading),
              const SizedBox(height: AppSpace.x3),
              Text("Basilica Minore de Piat", style: AppTypography.titleSmall),
              const SizedBox(height: AppSpace.x3),
              Text(
                "The Pinacanauan River threads through limestone cliffs on "
                "its way to the Cagayan.",
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: AppSpace.x3),
              Text(
                "Guides meet visitors at the barangay hall. Tricycles run to "
                "the jump-off for a fixed fare.",
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpace.x3),
              Text("Start the walking tour", style: AppTypography.labelLarge),
              const SizedBox(height: AppSpace.x3),
              Text(
                "Peñablanca, 24 km out",
                style: AppTypography.secondLine.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.x3),
              Text(
                "Photo: Provincial Tourism Office",
                style: AppTypography.labelSmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const _Section("Buttons"),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.x3,
                runSpacing: AppSpace.x3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text("Start tour"),
                  ),
                  FilledButton.tonal(
                    onPressed: () {},
                    child: const Text("Open map"),
                  ),
                  OutlinedButton(onPressed: () {}, child: const Text("Remove")),
                  TextButton(onPressed: () {}, child: const Text("Skip")),
                  const FilledButton(onPressed: null, child: Text("Disabled")),
                ],
              ),
              const SizedBox(height: AppSpace.x4),
              Wrap(
                spacing: AppSpace.x3,
                runSpacing: AppSpace.x3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SymbolButton(
                    icon: AppIcons.search,
                    tooltip: "Search",
                    onTap: () {},
                  ),
                  SymbolButton(
                    icon: AppIcons.back,
                    tooltip: "Back",
                    onTap: () {},
                  ),
                  SaveHeart(_hero.id, style: SaveHeartStyle.hero),
                  SaveHeart(_hero.id, style: SaveHeartStyle.tile),
                  const SelectionCircle(selected: true),
                  const SelectionCircle(selected: false),
                ],
              ),
              const SizedBox(height: AppSpace.x4),
              Row(
                children: [
                  BarItemGroup(
                    items: [
                      BarItem(
                        icon: AppIcons.search,
                        tooltip: "Search",
                        onPressed: () {},
                      ),
                      BarItem(
                        icon: AppIcons.share,
                        tooltip: "Share",
                        onPressed: () {},
                      ),
                      BarItem(
                        icon: AppIcons.favorite,
                        tooltip: "Save",
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpace.x4),
                  FloatingActionButton.extended(
                    onPressed: () {},
                    icon: const Icon(AppIcons.add),
                    label: const Text("Plan a tour"),
                  ),
                ],
              ),
            ],
          ),
        ),

        const _Section("Chips and badges"),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.x2,
                runSpacing: AppSpace.x2,
                children: [
                  for (final label in _categories)
                    ChoiceChip(
                      label: Text(label),
                      selected: _category == label,
                      onSelected: (_) => setState(() => _category = label),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.x5),
              const Wrap(
                spacing: AppSpace.x2,
                runSpacing: AppSpace.x2,
                children: [
                  LakbayanBadge.featured(),
                  LakbayanBadge.ar(),
                  LakbayanBadge("On this phone", kind: BadgeKind.neutral),
                  LakbayanBadge("₱100 entry", kind: BadgeKind.info),
                  LakbayanBadge("Closed", kind: BadgeKind.closed),
                ],
              ),
            ],
          ),
        ),

        const _Section("Field"),
        const TextField(decoration: InputDecoration(hintText: "Your name")),

        const _Section("Media tile"),
        SectionHeading("Popular this week", onSeeAll: () {}),
        const SizedBox(height: AppSpace.x2),
        MediaTile(
          media: _hero.coverImage == null
              ? const ImagePlaceholder()
              : StorageImage(path: _hero.coverImage!),
          aspectRatio: 16 / 10,
          title: _hero.name,
          subtitle: "2.4 km away",
          subtitleColor: context.lakbayan.spatial,
          badge: const LakbayanBadge.ar(),
          trailing: SaveHeart(_hero.id, style: SaveHeartStyle.tile),
          onTap: () {},
        ),
        const SizedBox(height: AppSpace.x4),
        MediaTile(
          media: _hero.coverImage == null
              ? const ImagePlaceholder()
              : StorageImage(path: _hero.coverImage!),
          aspectRatio: 16 / 10,
          title: _hero.name,
          subtitle: _hero.town,
          overlay: true,
          onTap: () {},
        ),

        const _Section("Grouped section"),
        GroupedSection(
          children: [
            for (final place in sampleDestinations.take(2))
              GroupedRow(
                title: place.name,
                subtitle: place.town,
                leading: const ImagePlaceholder(),
                trailing: SaveHeart(place.id, style: SaveHeartStyle.row),
                onTap: () {},
              ),
            GroupedRow(
              title: "Getting there",
              subtitle: "24 km from Tuguegarao",
              subtitleColor: context.lakbayan.spatial,
              leadingGlyph: AppIcons.directions,
              glyphColor: context.lakbayan.spatial,
              onTap: () {},
            ),
          ],
        ),

        const _Section("Nested card"),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.x3),
          color: scheme.surfaceContainer,
          child: AppCard(
            inset: AppSpace.x3,
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Text(
              "Inner radius derives from the outer one minus the inset, so "
              "the gap stays even around the corner.",
              style: AppTypography.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.x8, bottom: AppSpace.x3),
    child: Text(title, style: AppTypography.titleMedium),
  );
}

class _Swatches extends StatelessWidget {
  const _Swatches(this.swatches);

  final List<(String, Color)> swatches;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (name, color) in swatches)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpace.x1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppRadii.xsAll,
                      // Specimen only: white on white needs an edge to be
                      // seen as a swatch. Not a pattern for the app.
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(height: AppSpace.x1),
                  Text(
                    name,
                    style: AppTypography.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
