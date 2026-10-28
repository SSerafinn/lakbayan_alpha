import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/models/destination.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/app_menu.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/bar_item_group.dart";
import "../../../core/widgets/controls/filter_chip_row.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../destinations/data/sample_destinations.dart";
import "../../destinations/presentation/save_heart.dart";
import "../../itineraries/presentation/stop_picker.dart";

/// A living specimen of the design system (3.0, D-19), rendered with the
/// real theme and the real widgets.
///
/// Reachable at `/design-system` in debug builds (Settings, Developer) so a
/// change can be eyeballed without wiring it into a feature first. If this
/// and `docs/DESIGN_SYSTEM.md` ever disagree, one of them is wrong.
class DesignSystemGallery extends StatelessWidget {
  const DesignSystemGallery({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Stack(children: [_Tokens(), StatusBarGround()]));
}

class _Tokens extends StatefulWidget {
  const _Tokens();

  @override
  State<_Tokens> createState() => _TokensState();
}

/// The specimen draws from the same `sampleDestinations` the debug preview
/// feeds the real screens, so the two can never show different content.
final _hero = sampleDestinations.firstWhere((d) => d.featured);
final _kinds = [
  for (final category in DestinationCategory.values)
    if (category != DestinationCategory.unknown) category,
];

class _TokensState extends State<_Tokens> {
  DestinationCategory? _kind = DestinationCategory.nature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final photo = _hero.coverImage == null
        ? const ImagePlaceholder()
        : StorageImage(path: _hero.coverImage!);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter,
        MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
        AppSpace.gutter,
        AppSpace.x12,
      ),
      children: [
        SymbolButton(
          icon: AppIcons.back,
          tooltip: "Back",
          onTap: () => Navigator.of(context).maybePop(),
          onGround: true,
        ),
        const SizedBox(height: AppSpace.x2),
        Text("Design System", style: AppTypography.display),

        const _Section("Surfaces"),
        _Swatches([
          ("paper", scheme.surface),
          ("card", scheme.surfaceContainerLowest),
          ("in card", scheme.surfaceContainerLow),
          ("high", scheme.surfaceContainerHigh),
          ("glass", brand.glass),
        ]),
        const _Section("Roles"),
        _Swatches([
          ("primary", scheme.primary),
          ("green text", brand.textOnLightGreen),
          ("tint", brand.tint),
          ("spatial", brand.spatial),
          ("save", brand.save),
          ("closed", brand.closed),
        ]),
        const SizedBox(height: AppSpace.x3),
        _Swatches([
          ("mint", brand.mint),
          ("sky", brand.sky),
          ("butter", brand.butter),
          ("blush", brand.blush),
        ]),

        const _Section("Type"),
        _Panel(
          children: [
            Text("Cagayan", style: AppTypography.display),
            Text("Callao Cave", style: AppTypography.hero),
            Text("Trips", style: AppTypography.titleLarge),
            Text("Popular", style: AppTypography.titleMedium),
            Text("Saved Tours", style: AppTypography.groupHeading),
            Text("Basilica Minore de Piat", style: AppTypography.titleSmall),
            Text(
              "The Pinacanauan River threads through limestone cliffs on its "
              "way to the Cagayan.",
              style: AppTypography.bodyLarge,
            ),
            Text(
              "Guides meet visitors at the barangay hall.",
              style: AppTypography.bodyMedium,
            ),
            Text("Add to Trip", style: AppTypography.labelLarge),
            Text("See All", style: AppTypography.labelMedium),
            Text(
              "Peñablanca",
              style: AppTypography.secondLine.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              "Photo: Provincial Tourism Office",
              style: AppTypography.labelSmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const _Section("Buttons"),
        _Panel(
          children: [
            Wrap(
              spacing: AppSpace.x2,
              runSpacing: AppSpace.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(onPressed: () {}, child: const Text("Sign In")),
                OutlinedButton(onPressed: () {}, child: const Text("Remove")),
                TextButton(onPressed: () {}, child: const Text("Reorder")),
                const FilledButton(onPressed: null, child: Text("Disabled")),
              ],
            ),
            Wrap(
              spacing: AppSpace.x2,
              runSpacing: AppSpace.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SymbolButton(
                  icon: AppIcons.back,
                  tooltip: "Back",
                  onTap: () {},
                  onGround: true,
                ),
                SymbolButton(
                  icon: AppIcons.add,
                  tooltip: "New trip",
                  onTap: () {},
                  background: scheme.primary,
                  color: scheme.onPrimary,
                ),
                SaveHeart(_hero.id, style: SaveHeartStyle.hero),
                SaveHeart(_hero.id, style: SaveHeartStyle.tile),
                const SelectionCircle(selected: true),
                const SelectionCircle(selected: false),
              ],
            ),
          ],
        ),

        const _Section("Chips and Pills"),
        FilterChipRow(
          items: [
            FilterChipItem(
              label: "All",
              selected: _kind == null,
              onTap: () => setState(() => _kind = null),
            ),
            for (final kind in _kinds)
              FilterChipItem(
                label: kind.label,
                selected: _kind == kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.x3),
        const Wrap(
          spacing: AppSpace.x2,
          runSpacing: AppSpace.x2,
          children: [
            PhotoPill.scan(),
            PhotoPill("1.2 km"),
            PhotoPill("14 to 15 Nov", glyph: AppIcons.calendar),
          ],
        ),

        const _Section("Field"),
        const TextField(decoration: InputDecoration(hintText: "Name")),

        const _Section("Photos"),
        SectionHeading("Popular", onSeeAll: () {}),
        MediaTile(
          media: photo,
          aspectRatio: 16 / 10,
          title: _hero.name,
          subtitle: _hero.town,
          overlay: true,
          pill: const PhotoPill.scan(),
          trailing: SaveHeart(_hero.id, style: SaveHeartStyle.tile),
          onTap: () {},
        ),

        const _Section("Rows on a Card"),
        GroupedSection(
          heading: "Stops",
          children: [
            for (final (index, place) in sampleDestinations.take(3).indexed)
              GroupedRow(
                mark: StopNumeral(index + 1),
                title: place.name,
                subtitle: place.town,
                leading: CoverImage(place.coverImage),
                onTap: () {},
              ),
          ],
        ),
        const SizedBox(height: AppSpace.section),
        GroupedSection(
          heading: "Settings",
          children: [
            GroupedRow(title: "Downloaded Towns", onTap: () {}),
            GroupedRow(
              title: "Reduce Motion",
              trailing: Switch(value: true, onChanged: (_) {}),
              onTap: () {},
            ),
          ],
        ),

        const _Section("Controls over a Photo, and a Menu"),
        SizedBox(
          height: AppSize.routePreview,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(borderRadius: AppRadii.lgAll, child: photo),
              Positioned(
                top: AppSpace.x2,
                left: AppSpace.x2,
                child: SymbolButton(
                  icon: AppIcons.back,
                  tooltip: "Back",
                  onTap: () {},
                ),
              ),
              Positioned(
                top: AppSpace.x2,
                right: AppSpace.x2,
                child: BarItemGroup.overMedia(
                  items: [
                    BarItem(
                      icon: AppIcons.share,
                      tooltip: "Share",
                      onPressed: () {},
                    ),
                    BarItem(
                      icon: AppIcons.more,
                      tooltip: "More",
                      menu: [
                        [
                          AppMenuItem(
                            label: "Change Dates",
                            icon: AppIcons.calendar,
                            onSelected: () {},
                          ),
                          AppMenuItem(
                            label: "Rename",
                            icon: AppIcons.rename,
                            onSelected: () {},
                          ),
                        ],
                        [
                          AppMenuItem(
                            label: "Delete",
                            icon: AppIcons.delete,
                            destructive: true,
                            onSelected: () {},
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const _Section("Dialog"),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => showAppDialog<void>(
              context,
              builder: (context) => AlertDialog(
                title: const Text("Delete Weekend in Santa Ana?"),
                content: const Text(
                  "The stops go with it. This cannot be undone.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Keep It"),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Delete"),
                  ),
                ],
              ),
            ),
            child: const Text("Open a Dialog"),
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
    padding: const EdgeInsets.only(top: AppSpace.x8, bottom: AppSpace.near),
    child: Text(title, style: AppTypography.titleMedium),
  );
}

/// A white card holding a specimen's pieces a short step apart.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpace.x2),
            child,
          ],
        ],
      ),
    ),
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
                    height: AppSize.minTouchTarget,
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
