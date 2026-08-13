import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/destination_card.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/lakbayan_list_row.dart";

/// A living specimen of the Lakbayan design system, rendered with the real
/// theme and the real widgets.
///
/// This is the counterpart to the Claude Design HTML specimen: if the two ever
/// diverge, one of them is wrong. Reachable at `/design-system` in debug builds
/// so the team can eyeball a change without wiring it into a feature first.
class DesignSystemGallery extends StatefulWidget {
  const DesignSystemGallery({super.key});

  @override
  State<DesignSystemGallery> createState() => _DesignSystemGalleryState();
}

class _DesignSystemGalleryState extends State<DesignSystemGallery> {
  String _category = "Nature";
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Design system"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: c.line, height: 1),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: "Explore",
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: "Map",
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: "Itineraries",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x4,
          AppSpace.x4,
          AppSpace.x4,
          AppSpace.x8,
        ),
        children: [
          _section("Colour"),
          _ramp("Green — primary", const [
            ("900", AppColors.green900),
            ("700", AppColors.green700),
            ("500", AppColors.green500),
            ("300", AppColors.green300),
            ("100", AppColors.green100),
            ("50", AppColors.green50),
          ]),
          _ramp("Blue — secondary", const [
            ("700", AppColors.blue700),
            ("500", AppColors.blue500),
            ("300", AppColors.blue300),
            ("100", AppColors.blue100),
            ("50", AppColors.blue50),
          ]),
          _ramp("Gold — accent", const [
            ("700", AppColors.gold700),
            ("500", AppColors.gold500),
            ("300", AppColors.gold300),
            ("100", AppColors.gold100),
          ]),
          _ramp("Neutrals", const [
            ("ink900", AppColors.ink900),
            ("ink700", AppColors.ink700),
            ("slate500", AppColors.slate500),
            ("slate300", AppColors.slate300),
            ("line", AppColors.line),
          ]),

          _section("Type"),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Discover Cagayan", style: AppTypography.display),
                const SizedBox(height: AppSpace.x3),
                Text("Callao Cave & the Pinacanauan", style: AppTypography.h1),
                const SizedBox(height: AppSpace.x3),
                Text("Nearby heritage stops", style: AppTypography.h2),
                const SizedBox(height: AppSpace.x3),
                Text("Basilica Minore de Piat", style: AppTypography.h3),
                const SizedBox(height: AppSpace.x3),
                Text(
                  "Open daily · 7:00 AM – 5:00 PM",
                  style: AppTypography.title,
                ),
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
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpace.x3),
                Text("Start the walking tour", style: AppTypography.label),
                const SizedBox(height: AppSpace.x3),
                Text(
                  "Photo: Provincial Tourism Office · 2.4 km away",
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpace.x3),
                const Overline("Heritage trail"),
              ],
            ),
          ),

          _section("Buttons"),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.x3,
                  runSpacing: AppSpace.x3,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text("Start tour"),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text("Open map"),
                    ),
                    TextButton(onPressed: () {}, child: const Text("Skip")),
                    const FilledButton(
                      onPressed: null,
                      child: Text("Disabled"),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.x4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.lgAll,
                      ),
                    ),
                    child: const Text("Full-width primary — 16dp radius"),
                  ),
                ),
                const SizedBox(height: AppSpace.x3),
                Text(
                  "Primary = green/500 fill. Secondary = blue/500 outline. "
                  "Gold is never a button.",
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),

          _section("Chips & badges"),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final label in const [
                      "All",
                      "Nature",
                      "Heritage",
                      "Food",
                      "Festivals",
                    ])
                      FilterChip(
                        label: Text(label),
                        selected: _category == label,
                        onSelected: (_) => setState(() => _category = label),
                        side: BorderSide(
                          color: _category == label
                              ? AppColors.green500
                              : c.line,
                        ),
                      ),
                  ],
                ),
                const Divider(height: AppSpace.x8),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    LakbayanBadge.ar(),
                    LakbayanBadge.featured(),
                    LakbayanBadge("Open now", kind: BadgeKind.neutral),
                    LakbayanBadge("2.4 km", kind: BadgeKind.info),
                    LakbayanBadge("Closed", kind: BadgeKind.closed),
                  ],
                ),
              ],
            ),
          ),

          _section("Destination card"),
          const DestinationCard(
            town: "Peñablanca",
            name: "Callao Cave",
            description:
                "Seven limestone chambers and a chapel lit by a natural "
                "skylight.",
            hasAr: true,
            status: "Open now",
            meta: "2.4 km · 45 min drive",
          ),

          _section("List rows"),
          _card(
            const Column(
              children: [
                LakbayanListRow(
                  title: "Buntun Bridge",
                  subtitle: "Tuguegarao · Viewpoint",
                ),
                LakbayanListRow(
                  title: "Palaui Island",
                  subtitle: "Santa Ana · Protected landscape",
                  selected: true,
                  trailing: LakbayanBadge.featured(),
                ),
                LakbayanListRow(
                  title: "Piat Basilica",
                  subtitle: "Piat · Pilgrimage",
                  showDivider: false,
                ),
              ],
            ),
          ),

          _section("App bar"),
          _card(
            Column(
              children: [
                _appBarSample(
                  background: AppColors.green500,
                  foreground: Colors.white,
                  title: "Callao Cave",
                ),
                const SizedBox(height: 14),
                _appBarSample(
                  background: AppColors.surface,
                  foreground: AppColors.ink900,
                  title: "Explore",
                  border: true,
                ),
                const SizedBox(height: AppSpace.x3),
                Text(
                  "Green bar over photography-led detail screens; white bar "
                  "over scrolling content.",
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.x6, bottom: AppSpace.x4),
    child: Text(title, style: AppTypography.h2),
  );

  Widget _card(Widget child) => Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(AppSpace.x5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.lakbayan.line),
        boxShadow: AppShadow.card,
      ),
      child: child,
    ),
  );

  Widget _ramp(String label, List<(String, Color)> swatches) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Overline(label),
        const SizedBox(height: AppSpace.x2),
        Row(
          children: [
            for (final (name, color) in swatches)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpace.x1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: AppRadius.smAll,
                          border: Border.all(color: AppColors.line),
                        ),
                      ),
                      const SizedBox(height: AppSpace.x1),
                      Text(name, style: AppTypography.caption),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _appBarSample({
    required Color background,
    required Color foreground,
    required String title,
    bool border = false,
  }) => Container(
    height: AppSize.appBarHeight,
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: AppRadius.mdAll,
      border: border ? Border.all(color: AppColors.line) : null,
    ),
    child: Row(
      children: [
        Icon(Icons.arrow_back, color: foreground, size: 22),
        const SizedBox(width: 14),
        Text(title, style: AppTypography.h3.copyWith(color: foreground)),
      ],
    ),
  );
}
