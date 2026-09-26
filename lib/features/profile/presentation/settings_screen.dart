import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_theme_mode.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";

/// Settings. **One job:** make the app behave the way I need it to.
/// **Emotion:** calm control; nothing here surprises.
///
/// **Anatomy.** Back and the title; then one group per concern under its
/// heading: Appearance as a segmented row, Reduce motion as a row with its
/// switch. No plates. Reached from Profile.
///
/// **The foundation.** The sections are the list [_groups], so a new setting
/// is a new row widget in the right group, not a new screen. Only settings
/// that do something are listed; a placeholder row would be a promise the
/// app does not keep.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _groups = [
    _Group(heading: "General", rows: [_AppearanceRow()]),
    _Group(heading: "Accessibility", rows: [_ReduceMotionRow()]),
  ];

  @override
  Widget build(BuildContext context) => EntranceScope(
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
            Row(
              children: [
                SymbolButton(
                  icon: AppIcons.back,
                  tooltip: "Back",
                  onTap: () => context.popOrHome(),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Text("Settings", style: AppTypography.titleLarge),
                ),
              ],
            ),
            for (final (index, group) in _groups.indexed) ...[
              const SizedBox(height: AppSpace.section),
              Entrance(order: index + 1, child: group),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.heading, required this.rows});

  final String heading;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(heading, style: AppTypography.groupHeading),
      const SizedBox(height: AppSpace.x2),
      ...rows,
    ],
  );
}

/// System, light or dark, as one segmented row: the three choices are all
/// in view at once, and the chosen one is the solid green segment.
class _AppearanceRow extends ConsumerWidget {
  const _AppearanceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: [
        for (final option in ThemeMode.values)
          ButtonSegment(value: option, label: Text(option.label)),
      ],
      selected: {mode},
      onSelectionChanged: (choice) =>
          ref.read(appThemeModeProvider.notifier).select(choice.single),
    );
  }
}

/// Calmer motion: springs become cross-fades everywhere, on top of the
/// phone's own setting. The row and the switch are one target.
class _ReduceMotionRow extends ConsumerWidget {
  const _ReduceMotionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(reduceMotionProvider);
    void flip() => ref.read(reduceMotionProvider.notifier).set(!on);
    return MergeSemantics(
      child: GroupedRow(
        title: "Reduce motion",
        subtitle: "Fades instead of movement",
        dense: true,
        trailing: Switch(value: on, onChanged: (_) => flip()),
        onTap: flip,
      ),
    );
  }
}
