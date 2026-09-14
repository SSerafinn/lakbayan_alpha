import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/app_destination.dart";
import "../../../core/widgets/app_motion_builder.dart";
import "../../../core/widgets/floating_tab_bar.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/storage_image.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/home_chrome.dart";
import "../domain/home_tab.dart";

/// The home shell's chrome over the tab content: the floating tab bar at the
/// bottom and, on Explore, a search circle pinned top-right over the hero.
/// Tapping the circle grows it leftward into a field, the screen dims, and
/// matches drop down under the field (design doc 04: an interrupting task,
/// presented from its source). Everything rides one `t`, so the three ways
/// out (close glyph, tap outside, back) retrace the same path.
///
/// In the Scaffold body rather than its bottom slot so the bar rides the
/// keyboard and Explore's feed never reflows.
class HomeChromeLayer extends ConsumerStatefulWidget {
  const HomeChromeLayer({required this.tab, required this.child, super.key});

  final HomeTab tab;

  /// The selected tab's content, under the chrome.
  final Widget child;

  @override
  ConsumerState<HomeChromeLayer> createState() => _HomeChromeLayerState();
}

class _HomeChromeLayerState extends ConsumerState<HomeChromeLayer> {
  bool _open = false;
  final _controller = TextEditingController();

  void _openSearch() => setState(() => _open = true);

  void _close() {
    if (!_open) return;
    _controller.clear();
    ref.read(homeQueryProvider.notifier).update("");
    setState(() => _open = false);
  }

  @override
  void didUpdateWidget(HomeChromeLayer old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab) _close();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_open,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: AppMotionBuilder(
            end: _open ? 1 : 0,
            builder: (context, t, _) => _Overlay(
              t: t,
              tab: widget.tab,
              controller: _controller,
              onOpen: _openSearch,
              onClose: _close,
            ),
          ),
        ),
      ],
    ),
  );
}

const _tabs = [
  AppDestination(
    icon: AppIcons.explore,
    selectedIcon: AppIcons.exploreFilled,
    label: "Explore",
  ),
  AppDestination(
    icon: AppIcons.map,
    selectedIcon: AppIcons.mapFilled,
    label: "Map",
  ),
  AppDestination(
    icon: AppIcons.itineraries,
    selectedIcon: AppIcons.itinerariesFilled,
    label: "Itineraries",
  ),
  AppDestination(
    icon: AppIcons.profile,
    selectedIcon: AppIcons.profileFilled,
    label: "Profile",
  ),
];

/// Scrim, results panel, the search capsule at the top and the bar at the
/// bottom. The capsule is a circle at rest and only on Explore.
class _Overlay extends ConsumerWidget {
  const _Overlay({
    required this.t,
    required this.tab,
    required this.controller,
    required this.onOpen,
    required this.onClose,
  });

  final double t;
  final HomeTab tab;
  final TextEditingController controller;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final query = ref.watch(homeQueryProvider).trim();
    final chrome = ref.watch(homeChromeProvider);
    final padding = MediaQuery.paddingOf(context);
    // The spring overshoots a little; only widths may follow it.
    final fade = t.clamp(0.0, 1.0);
    final top = padding.top + AppSpace.x2;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          if (t > 0)
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                child: ColoredBox(
                  color: scheme.scrim.withValues(alpha: 0.4 * fade),
                ),
              ),
            ),
          if (t > 0 && query.isNotEmpty)
            Positioned(
              left: AppSpace.gutter,
              right: AppSpace.gutter,
              top: top + AppSize.minTouchTarget + AppSpace.x2,
              child: Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(0, -AppSpace.x2 * (1 - fade)),
                  child: _Panel(
                    maxHeight: constraints.maxHeight * 0.45,
                    onPick: onClose,
                  ),
                ),
              ),
            ),
          Positioned(
            left: AppSpace.gutter,
            right: AppSpace.gutter,
            top: top,
            child: AppMotionBuilder(
              end: tab == HomeTab.explore ? 1 : 0,
              builder: (context, shown, _) => shown <= 0
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.topRight,
                        heightFactor: 1,
                        child: IgnorePointer(
                          ignoring: shown < 1,
                          child: Opacity(
                            opacity: shown.clamp(0.0, 1.0),
                            child: _Capsule(
                              width: lerpDouble(
                                AppSize.minTouchTarget,
                                constraints.maxWidth,
                                t,
                              )!,
                              t: t,
                              controller: controller,
                              onOpen: onOpen,
                              onClose: onClose,
                              onChanged: ref
                                  .read(homeQueryProvider.notifier)
                                  .update,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Clipped at the body's bottom edge so a hidden bar is truly off
          // screen, keyboard or not. Padding, not viewPadding: it is zero
          // while the keyboard is up.
          Positioned(
            left: AppSpace.gutter,
            right: AppSpace.gutter,
            bottom: 0,
            child: ClipRect(
              child: Padding(
                padding: EdgeInsets.only(bottom: padding.bottom + AppSpace.x3),
                child: FloatingTabBar(
                  destinations: _tabs,
                  selectedIndex: tab.index,
                  collapsed: chrome == HomeChromeState.collapsed,
                  // Search owns the screen while open, so the bar leaves the way
                  // it does for the Map's sheet, and comes back the same way.
                  hidden: chrome == HomeChromeState.hidden || t > 0,
                  onExpand: ref.read(homeChromeProvider.notifier).expand,
                  onSelected: (i) {
                    ref.read(homeChromeProvider.notifier).reset();
                    ref
                        .read(selectedHomeTabProvider.notifier)
                        .select(HomeTab.values[i]);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A capsule at every width: the glyph sits at its left edge and travels
/// with it, the field and close glyph fade in once there is room for them.
/// At rest it is one 48dp target; open, its hairline turns green for focus.
class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.width,
    required this.t,
    required this.controller,
    required this.onOpen,
    required this.onClose,
    required this.onChanged,
  });

  final double width;
  final double t;
  final TextEditingController controller;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  static const _glyph = 20.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reveal = ((t - 0.5) * 2).clamp(0.0, 1.0);

    return Material(
      color: scheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: t > 0.5 ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: AppSize.minTouchTarget,
        child: Stack(
          children: [
            if (t == 0)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: "Search places or towns",
                  child: Tooltip(
                    message: "Search places or towns",
                    child: InkWell(customBorder: capsule, onTap: onOpen),
                  ),
                ),
              ),
            const Positioned(
              left: (AppSize.minTouchTarget - _glyph) / 2,
              top: 0,
              bottom: 0,
              child: Icon(AppIcons.search, size: _glyph),
            ),
            if (reveal > 0)
              Positioned.fill(
                left: AppSize.minTouchTarget,
                child: Opacity(
                  opacity: reveal,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          controller: controller,
                          onChanged: onChanged,
                          textInputAction: TextInputAction.search,
                          style: AppTypography.bodyMedium,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: "Search places or towns",
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(AppIcons.close, size: 18),
                        tooltip: "Close search",
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Matches for the query, nearest the thumb first row, on their own surface.
class _Panel extends ConsumerWidget {
  const _Panel({required this.maxHeight, required this.onPick});

  final double maxHeight;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final results = ref.watch(homeResultsProvider);
    final loading = ref.watch(allDestinationsProvider).isLoading;

    return Material(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: results.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Text(
                  loading ? "Looking…" : "Nothing matches. Try another word.",
                  style: AppTypography.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            : ParentRadius(
                radius: concentricRadius(
                  parentRadius: AppRadii.md,
                  padding: AppSpace.groupInset,
                  fallback: AppRadii.sm,
                ),
                // Bounded above and short, so it may hug (STANDARDS 3.4).
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(AppSpace.groupInset),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final place = results[index];
                    return GroupedRow(
                      title: place.name,
                      subtitle: place.town,
                      leading: place.coverImage == null
                          ? const ImagePlaceholder(
                              borderRadius: BorderRadius.zero,
                            )
                          : StorageImage(path: place.coverImage!),
                      onTap: () {
                        onPick();
                        context.push(Routes.destination(place.id));
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}
