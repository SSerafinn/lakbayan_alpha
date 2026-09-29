import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/filter_chip_row.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/domain/recently_viewed.dart";
import "../domain/home_tab.dart";

/// Search surface that grows out of the bar's search cell. Finds a place
/// or town by name; picking a row or system back folds it back into the cell.
class SearchSurface extends StatefulWidget {
  const SearchSurface({
    required this.open,
    required this.origin,
    required this.controller,
    required this.onChanged,
    required this.onClose,
    required this.onFolded,
    super.key,
  });

  final bool open;

  /// The search cell's rect in this surface's space; the field grows out of
  /// it and folds back into it. Null places the field at its docked spot.
  final Rect? origin;

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  /// Once folded back into the cell: the moment to forget the query, so
  /// the rows do not change under a person while they fold.
  final VoidCallback onFolded;

  @override
  State<SearchSurface> createState() => _SearchSurfaceState();
}

class _SearchSurfaceState extends State<SearchSurface> {
  final _focus = FocusNode();

  @override
  void didUpdateWidget(SearchSurface old) {
    super.didUpdateWidget(old);
    // The keyboard leaves first, so it is not still rising as the field
    // folds.
    if (old.open && !widget.open) _focus.unfocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _settled() {
    if (widget.open) {
      // Focus once the field has arrived, so the keyboard does not resize the
      // screen while the capsule is still growing.
      _focus.requestFocus();
    } else {
      widget.onFolded();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Built once per build and handed down, so a frame of the grow only
    // places and fades them; the text field is never rebuilt mid-motion
    // (STANDARDS 10.10).
    final input = TextField(
      focusNode: _focus,
      controller: widget.controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyLarge,
      decoration: const InputDecoration(
        isDense: true,
        hintText: "Places or towns",
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
    final close = IconButton(
      icon: const Icon(AppIcons.close, size: AppSize.glyphMd),
      tooltip: "Close search",
      onPressed: widget.onClose,
    );
    // Measured outside the motion: the constraints change with the keyboard,
    // not with `t`.
    return LayoutBuilder(
      builder: (context, constraints) => AppMotionBuilder(
        end: widget.open ? 1 : 0,
        onEnd: _settled,
        child: _SearchBody(onLeave: widget.onClose),
        builder: (context, t, body) {
          if (t <= 0 && !widget.open) return const SizedBox.shrink();
          return _Layout(
            t: t,
            constraints: constraints,
            origin: widget.origin,
            input: input,
            close: close,
            body: body!,
          );
        },
      ),
    );
  }
}

/// The docked field's height: the primary button's, and taller when the
/// person's text size needs it, so the text never overflows the capsule
/// (STANDARDS 6.7).
double _fieldHeight(BuildContext context) {
  final text = MediaQuery.textScalerOf(context)
      .lineHeightOf(AppTypography.bodyLarge);
  final needed = text + AppSpace.x4;
  return (needed > AppSize.primaryButton ? needed : AppSize.primaryButton)
      .ceilToDouble();
}

/// The ground, the body above the field, and the field on its way from the
/// bar's search cell to the dock.
class _Layout extends StatelessWidget {
  const _Layout({
    required this.t,
    required this.constraints,
    required this.origin,
    required this.input,
    required this.close,
    required this.body,
  });

  final double t;
  final BoxConstraints constraints;
  final Rect? origin;
  final Widget input;
  final Widget close;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The spring overshoots: sizes may follow it, opacity may not.
    final fade = t.clamp(0.0, 1.0);
    // Padding, not viewPadding: the body already sits above the keyboard, and
    // the gesture inset is zero while the keyboard is up.
    final bottom = MediaQuery.paddingOf(context).bottom + AppSpace.x3;
    final height = _fieldHeight(context);
    final docked = Rect.fromLTWH(
      AppSpace.gutter,
      constraints.maxHeight - bottom - height,
      constraints.maxWidth - 2 * AppSpace.gutter,
      height,
    );
    final rect = Rect.lerp(origin ?? docked, docked, t)!;
    final field = _Field(t: t, lead: rect.height, input: input, close: close);

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: scheme.surface.withValues(alpha: fade)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.paddingOf(context).top,
          bottom: constraints.maxHeight - docked.top + AppSpace.x2,
          // The same tree at rest (full opacity, no offset), so the body is
          // not rebuilt from nothing the moment the field arrives.
          child: Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(0, (1 - fade) * AppSpace.x6),
              child: body,
            ),
          ),
        ),
        Positioned.fromRect(rect: rect, child: field),
      ],
    );
  }
}

/// A capsule at every width: the glyph keeps its place at the leading end
/// and travels with it; the text and the close glyph come in once there is
/// room. Its hairline turns green once it is a field (focus, doc 03).
class _Field extends StatelessWidget {
  const _Field({
    required this.t,
    required this.lead,
    required this.input,
    required this.close,
  });

  final double t;

  /// The field's height, so the glyph sits in a circle that size: at the
  /// start it is centred in the bar's search cell, where it came from.
  final double lead;
  final Widget input;
  final Widget close;

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
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: lead,
            child: const Icon(AppIcons.search, size: AppSize.tabGlyph),
          ),
          if (reveal > 0)
            Positioned.fill(
              left: lead,
              child: Opacity(
                opacity: reveal,
                child: Row(
                  children: [
                    Expanded(child: input),
                    close,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What sits above the search field: the kinds, then either somewhere to
/// start (what you looked at last, the towns) or the matches.
///
/// The body arrives in order each time it changes between those two, not on
/// every keystroke, so typing reads as the list narrowing rather than
/// replaying ([EntranceScope] keyed on the mode).
class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.onLeave});

  /// Called before a row takes somebody elsewhere, so search folds away.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searching =
        ref.watch(homeQueryProvider).trim().isNotEmpty ||
        ref.watch(searchCategoryProvider) != null;
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    return EntranceScope(
      key: ValueKey(searching),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.only(
              top: AppSpace.x2,
              bottom: AppSpace.section,
            ),
            sliver: SliverToBoxAdapter(child: Entrance(child: _Kinds())),
          ),
          if (searching)
            SliverPadding(
              padding: gutter,
              sliver: _Matches(onLeave: onLeave),
            )
          else ...[
            SliverPadding(
              padding: gutter,
              sliver: SliverToBoxAdapter(child: _Recent(onLeave: onLeave)),
            ),
            SliverPadding(
              padding: gutter,
              sliver: _Towns(onLeave: onLeave),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x3)),
        ],
      ),
    );
  }
}

/// The kinds of place, single-select. Tapping the chosen one clears it.
class _Kinds extends ConsumerWidget {
  const _Kinds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(searchCategoryProvider);
    return FilterChipRow(
      items: [
        for (final kind in DestinationCategory.values)
          if (kind != DestinationCategory.unknown)
            FilterChipItem(
              label: kind.label,
              selected: chosen == kind,
              onTap: () =>
                  ref.read(searchCategoryProvider.notifier).toggle(kind),
            ),
      ],
    );
  }
}

class _Matches extends ConsumerWidget {
  const _Matches({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    if (results.isEmpty) {
      final loading = ref.watch(
        allDestinationsProvider.select((value) => value.isLoading),
      );
      return SliverToBoxAdapter(
        child: QuietNote(
          loading ? "Looking…" : "Nothing matches. Try another word or kind.",
        ),
      );
    }
    return SliverGroupedSection(
      itemCount: results.length,
      itemBuilder: (context, index) => Entrance(
        order: index,
        child: _PlaceRow(place: results[index], onLeave: onLeave),
      ),
    );
  }
}

/// The last places opened, so going back to one is a tap. A history, so
/// the section is not there until there is one.
class _Recent extends ConsumerWidget {
  const _Recent({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedDestinationsProvider);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Entrance(
      order: 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeading("Recently viewed"),
            const SizedBox(height: AppSpace.x2),
            GroupedSection(
              children: [
                for (final place in recent.take(4))
                  _PlaceRow(place: place, onLeave: onLeave),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Every town. A town is a tab switch to the map, its name as the filter.
class _Towns extends ConsumerWidget {
  const _Towns({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final towns = ref.watch(townsProvider);
    if (towns.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: Entrance(
            order: 2,
            child: Padding(
              padding: EdgeInsets.only(bottom: AppSpace.x2),
              child: SectionHeading("Towns"),
            ),
          ),
        ),
        SliverGroupedSection(
          itemCount: towns.length,
          itemBuilder: (context, index) {
            final town = towns[index];
            return Entrance(
              order: 3 + index,
              child: GroupedRow(
                title: town.name,
                subtitle: town.placesLine,
                leading: CoverImage(town.cover),
                onTap: () {
                  onLeave();
                  ref.read(browseQueryProvider.notifier).update(town.name);
                  ref.read(browseCategoryProvider.notifier).select(null);
                  ref
                      .read(selectedHomeTabProvider.notifier)
                      .select(HomeTab.map);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A place: its photo flies into detail.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.onLeave});

  final Destination place;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => GroupedRow(
    title: place.name,
    subtitle: place.town,
    leading: PhotoHero(
      tag: coverHeroTag(place.id, HeroSource.search),
      child: CoverImage(place.coverImage),
    ),
    onTap: () {
      onLeave();
      context.push(Routes.destination(place.id, from: HeroSource.search));
    },
  );
}
