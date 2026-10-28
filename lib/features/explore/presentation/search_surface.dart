import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/presentation/explore_sections.dart";
import "../../destinations/presentation/place_photo.dart";

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
    final input = PlacesSearchInput(
      focusNode: _focus,
      controller: widget.controller,
      onChanged: widget.onChanged,
    );
    final close = SymbolButton(
      icon: AppIcons.close,
      tooltip: "Close search",
      onTap: widget.onClose,
      onGround: true,
      size: _fieldHeight(context),
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

/// The shared place/town input; its caller supplies the field's surface.
class PlacesSearchInput extends StatelessWidget {
  const PlacesSearchInput({
    required this.controller,
    required this.onChanged,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: AppTypography.bodyLarge,
    decoration: const InputDecoration(
      isDense: true,
      hintText: "Places and Towns",
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
  );
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

/// The ground, the body above the field, the field on its way from the
/// bar's search cell to the dock, and close beside it once it is there.
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
      constraints.maxWidth - 2 * AppSpace.gutter - height - AppSpace.x2,
      height,
    );
    final rect = Rect.lerp(origin ?? docked, docked, t)!;
    final field = _Field(t: t, lead: rect.height, input: input);
    final reveal = ((t - 0.5) * 2).clamp(0.0, 1.0);

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
        Positioned(
          left: docked.right + AppSpace.x2,
          top: docked.top,
          child: Opacity(opacity: reveal, child: close),
        ),
      ],
    );
  }
}

/// A capsule at every width: the glyph keeps its place at the leading end
/// and travels with it; the text comes in once there is room. Its hairline
/// turns emerald and 2dp once it is a field (focus, doc 03).
class _Field extends StatelessWidget {
  const _Field({required this.t, required this.lead, required this.input});

  final double t;

  /// The field's height, so the glyph sits in a circle that size: at the
  /// start it is centred in the bar's search cell, where it came from.
  final double lead;
  final Widget input;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reveal = ((t - 0.5) * 2).clamp(0.0, 1.0);
    final focused = t > 0.5;

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: StadiumBorder(
        side: BorderSide(
          color: focused ? scheme.primary : scheme.outlineVariant,
          width: focused ? AppStroke.bold : AppStroke.hairline,
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
              right: AppSpace.x4,
              child: Opacity(
                opacity: reveal,
                child: Align(alignment: Alignment.centerLeft, child: input),
              ),
            ),
        ],
      ),
    );
  }
}

/// What sits above the search field: towns and places, or the matches,
/// all as photos (D-19).
///
/// The body arrives in order each time it changes between those two, not on
/// every keystroke, so typing reads as the grid narrowing rather than
/// replaying ([EntranceScope] keyed on the mode).
class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.onLeave});

  /// Called before a tile takes somebody elsewhere, so search folds away.
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
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x3)),
          if (searching)
            SliverPadding(
              padding: gutter,
              sliver: _Matches(onLeave: onLeave),
            )
          else ...[
            SliverToBoxAdapter(child: _Towns(onLeave: onLeave)),
            SliverPadding(
              padding: gutter,
              sliver: _Places(onLeave: onLeave),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x3)),
        ],
      ),
    );
  }
}

class _Matches extends ConsumerWidget {
  const _Matches({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(searchResultsProvider)
      .whenLocalFirst(
        loading: () => const SliverToBoxAdapter(child: QuietNote("Looking…")),
        error: (error, _) => SliverToBoxAdapter(
          child: QuietNote(
            errorCopy("Couldn't search places.", error),
            onRetry: () => ref.invalidate(allDestinationsProvider),
          ),
        ),
        data: (results) => results.isEmpty
            ? const SliverToBoxAdapter(
                child: QuietNote("Nothing matches. Try another word."),
              )
            : _Grid(places: results, onLeave: onLeave),
      );
}

/// Every town as a small photo with its name, opening its page.
class _Towns extends ConsumerWidget {
  const _Towns({required this.onLeave});

  final VoidCallback onLeave;

  /// A town's tile, 4:3, a rail tile's width.
  static const _width = AppSize.tourTile;
  static const _height = _width * 3 / 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final towns = ref.watch(townsProvider);
    if (towns.isEmpty) {
      // Hidden while loading and when empty, but not on an error: before a
      // search, the towns are what this surface starts with, so a failure
      // is said here rather than left as a blank.
      final failure = ref.watch(
        allDestinationsProvider.select(
          (all) => all.hasValue ? null : all.error,
        ),
      );
      return failure == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: QuietNote(
                errorCopy("Couldn't load the towns.", failure),
                onRetry: () => ref.invalidate(allDestinationsProvider),
              ),
            );
    }

    return Entrance(
      order: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading("Towns"),
          ),
          SizedBox(
            height: _height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              itemCount: towns.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.near),
              itemBuilder: (context, index) => SizedBox(
                width: _width,
                child: TownPhoto(
                  town: towns[index],
                  from: HeroSource.search,
                  onOpen: onLeave,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.section),
        ],
      ),
    );
  }
}

/// Every place, three photos to a row.
class _Places extends ConsumerWidget {
  const _Places({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The towns above say when this list fails.
    final all = ref.watch(allDestinationsProvider).value ?? const [];
    if (all.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: Entrance(order: 2, child: SectionHeading("Places")),
        ),
        _Grid(places: all, onLeave: onLeave),
      ],
    );
  }
}

/// Places as a grid of photos, each name on its photo; a photo flies into
/// the place's page.
class _Grid extends StatelessWidget {
  const _Grid({required this.places, required this.onLeave});

  final List<Destination> places;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: AppSpace.near,
      crossAxisSpacing: AppSpace.near,
      childAspectRatio: 7 / 8,
    ),
    itemCount: places.length,
    itemBuilder: (context, index) {
      // Three to a row: too narrow for a pill and the name both.
      return PlacePhoto(
        place: places[index],
        from: HeroSource.search,
        aspectRatio: 7 / 8,
        tags: false,
        onOpen: onLeave,
      );
    },
  );
}
