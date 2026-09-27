# Design system

**Version 2.3.0** (D-13, amended by D-14, D-15 and D-16). Values live in `design/tokens.json`;
the Dart under `lib/core/theme/` transcribes them. If the two disagree,
`tokens.json` wins and the Dart is corrected.

The *reasoning* behind the values is a separate, longer reference kept by the
frontend lead (an adaptation of Apple's HIG foundations and the 2025 design
system update for an Android/Flutter target). This document is the committed
statement of what that reasoning decided. Where it says **Rule**, deviating
needs a written reason in the PR.

Live specimen: run the app in debug and open **`/design-system`** (Profile tab,
"Design system"). It renders the real theme with the real widgets. Every
screen is on this system since the 2a–2k redesign (D-14); each screen's class
comment states its one job, its emotion and its anatomy.

## Where things live

| Concern | File |
|---|---|
| Colour values, surface ladder | `lib/core/theme/app_colors.dart` |
| Spacing and fixed sizes | `lib/core/theme/app_dimens.dart` |
| Shape: fixed radii, capsule, concentric helpers | `lib/core/theme/app_shape.dart` |
| Width classes | `_WidthClass` in `browse_screen.dart`, its one user |
| Type ramp | `lib/core/theme/app_typography.dart` |
| Action to glyph map | `lib/core/theme/app_icons.dart` |
| Brand tokens outside `ColorScheme` (gold, badges) | `lib/core/theme/lakbayan_colors.dart` |
| `ThemeData` and every component theme | `lib/core/theme/app_theme.dart` |
| Shared primitives | `lib/core/widgets/` |

Reach for the theme, not the raw constants:

```dart
final scheme = Theme.of(context).colorScheme;   // roles: primary, surfaceContainerLow…
final brand  = context.lakbayan;                // gold, badge fills
Text("Callao Cave", style: AppTypography.titleSmall);
Icon(AppIcons.search)                           // never CupertinoIcons.x or Icons.x directly
```

`AppColors.*` is for building the theme. Using it in a widget bypasses dark
mode, the same as a hex literal.

## The rules that carry accessibility

Unchanged from 1.0.0. These are requirements, not preferences.

- **Gold is never a button.** It is the FEATURED badge and nothing else. It is
  deliberately absent from every `ColorScheme` action role; it lives in
  `LakbayanColors` so Material can never pick it up.
- **Green text on a light background must be `/700` or darker.** `green/500`
  on white is ~3.6:1 and fails AA. Use `context.lakbayan.textOnLightGreen`.
- **Never white text on gold.** Use `onGoldContainer` (ink).
- **48dp minimum touch target** on anything tappable; the theme sets
  `MaterialTapTargetSize.padded`.
- **Body text meets AA against its actual rendered background**, including
  over photographs. Text on a photo needs the `MediaTile` scrim.
- **Meaning is never carried by colour alone.** A status has a label; a
  selection has a shape change; an error has a border and a glyph.
- **Every screen survives the largest system text scale** without losing
  essential content. Test it as part of review, not afterwards.

## Emphasis without decoration

**Rule.** Hierarchy comes from, in order: position, grouping, size, weight, a
single tint, surface tone. Borders, drop shadows and per-item background plates
are not on the list. If a screen cannot express its hierarchy with those six,
it has too many competing elements.

What this means in code:

- The ground is **white**. Cards, sheets and menus are a barely visible grey
  step up (`surfaceContainerLow` for a card, `surfaceContainerHigh` for each
  group of a menu). `elevation` is 0 everywhere; shadows do not exist in this
  system.
- On a white ground a **1dp hairline** (`outlineVariant`) bounds the things
  that need an edge to exist: chips at rest, outlined badges, form fields,
  the secondary button. It is not an emphasis mechanism and it is never a
  divider between rows.
- `Divider` **draws nothing** (the theme zeroes it). Separate rows with the
  padding inside a `GroupedSection`; separate sections with space.
- **No grey plate (D-16).** Rows sit on the white ground
  (`GroupedSection`), compact, with a 56 photo and one second line. A card
  never holds a card.
- **No coloured tiles** (retired 2026-09-26, D-16 amendment). Shortcuts and
  small actions are rows on the white ground, a glyph in its meaning's
  colour leading (the saved heart red, downloads blue). A fact is words
  where it is needed: the one that decides now on one line, the rest in a
  sheet behind a quiet button (Place detail's Plan your visit).
- Exactly **one primary action per screen**, a solid green
  `FloatingActionButton` or `FilledButton`, separated from every bar group.
- Bar actions sit in a `BarItemGroup`: two to four symbol-only items on one
  capsule. A text button never joins a symbol group. Overflow goes to a menu,
  which the group's last item can open (`BarItem(menu:)`). Over a photo or a
  map the group is `BarItemGroup.overMedia`, a white capsule the height of a
  `SymbolButton`.

## Shape

Every rounded element is one of three types (`app_shape.dart`):

| Type | Use | Code |
|---|---|---|
| **Fixed** | standalone cards, media tiles, sheets, grouped sections | `AppRadii.xs / sm / md / lg / sheet` (8, 12, 16, 24, 28) |
| **Capsule** | buttons, chips, search fields, bar groups, nav indicators | `capsule` (a `StadiumBorder`) |
| **Concentric** | anything inside a rounded container | `concentricOf(context, padding:, fallback:)` via `ParentRadius` |

**Rule.** Never hard-code an inner radius. `inner = outer - padding`. A card
inside a card, a photo inside a row, a highlight inside a section all derive
from their parent. `AppCard`, `GroupedSection` and `MediaTile` do this for you.

**Rule.** Large controls are capsules; dense controls (form fields, small
segmented controls) are rounded rectangles at `AppRadii.sm`. This reverses the
2026-08 note that reserved the pill for chips: at 52dp a full-width capsule
reads as the one focal action on the surface, which is the emphasis we want,
and it is inherently concentric with whatever it sits in.

On a phone, a control near the screen corner gets extra margin rather than a
matched curve. `x4` from the edge for cards and hero media.

## Colour

**White first, four colours with one job each.** The interface is white and
near-black. Four colours carry meaning and nothing is washed in a tint
(`role.*` in `tokens.json`, `context.lakbayan` in Dart):

| Role | Value | Used on |
|---|---|---|
| `primary` green | `#168240` | the one primary action per screen; selection (chip, segment, nav indicator); the brand block on Profile |
| green on light | `#0F6431` | green text on white (`textOnLightGreen`) |
| `spatial` blue | `#0B6BCB` | map pins, distances, getting there, offline and download, the inline "See all". Never a button fill |
| `featured` gold | `#9A6300` | the FEATURED badge, white text. Nothing else; white never sits on the `#E9A21A` base |
| `closed` red | `#E5322A` | the CLOSED badge, Sign out, Delete, the SKIP stamp |
| `save` red | `#E5322A` | the saved heart, filled. Same value as `closed`, its own role |
| error | `#C42B1B` | field error border and warning glyph |

The saved heart is red (`save`), reversed from D-14 on the first device pass:
green made a kept place look like a selected control. `categoryColor` keeps
a colour per kind (nature green, churches and museums ink, heritage earth
`#A4620D`, food red, landmarks blue) for the specimen; since D-16 Explore's
kinds are plain chips, and selection is still solid green.

Everything else is neutral: `onSurface` near-black for text,
`onSurfaceVariant` for second lines, `outlineVariant` for the hairline, and
the surface ladder (`surface` white, `surfaceContainerLow` `#F6F6F4` for
cards, grouped sections and glyph circles, `Container` and `High` for media
placeholders, `Highest` for thumbnails and disabled fills).

- **No muted tints.** `primaryContainer` and `secondaryContainer` exist for
  Material's sake and for pressed states; a badge, a chip, a card or a section
  is never filled with a pale version of a brand colour.

Optionally, and sparingly, a full-bleed solid green block may carry brand
presence (an onboarding header, the Profile card). This is a screen-level
decision, made once, not a component default.

Dark mode is **live**: `themeMode` follows the phone by default and the
Profile tab offers System, Light or Dark (`AppThemeMode`, kept in
`AppPreferences`). The dark palette has not had its review yet; treat it as
the next design pass, not as finished.

## Type

One family, **Satoshi**, bundled as a variable font (offline-first; no
`google_fonts`), set heavy: Satoshi draws light at phone sizes, so the ramp
sits above a desktop ramp and Regular is not in it. Since 2.2.0 (D-15) it
sits half a step lighter than 2.0, which read heavy on a device: display
800, headings 750, labels 650, body 550, never below 550. Satoshi is
variable, so the in-between weights are real instances, not rounding. Tracking
tightens as size grows. A same-family
hierarchy is the quietest system there is, and it leaves **Barabara** as the
one loud voice: the landing greetings and the LAKBAYAN wordmark only (a
Philippine tourism trademark face, uppercase only, never a ramp step).

The ramp (`AppTypography`): `display` 38/800, `hero` 28/750 (a place name
over its photo), `titleLarge` 24/750, `titleMedium` 19/750, `groupHeading`
17/750 (over a grouped section), `titleSmall` 17/650; `bodyLarge` 17/550,
`bodyMedium` 15/550; `labelLarge` 15/650, `labelMedium` 13/650, `secondLine`
13/550 (a row's second line), `labelSmall` 12/550,
`tabLabel` 11/650 (11/750 selected); `caps` 11/750 with wide tracking for
badges and the swipe stamp only. Headings are sentence case; there are no
all-caps eyebrows. Each step is distinguishable from its neighbour at arm's
length; that is the whole point of a ramp.

**Rule.** No `TextStyle` literals at call sites. Titles and body are left
aligned. Colour comes from the scheme (`onSurface` by default,
`onSurfaceVariant` for secondary text), not from the style.

Every style sets the `wght` axis through `FontVariation` because on a variable
font `fontWeight` alone selects the file's default instance; `fontWeight` is
the nearest named weight, for anything that reads it instead of the axis. If a
weight looks wrong, that is why.

## Icons

**`CupertinoIcons` is the one icon family**, mapped in `AppIcons`. This is a
deliberate exception to the reference guidance of "Material icons for a
Material app": the glyph set is the team's choice for its lighter stroke,
and it carries no Cupertino *widgets* with it. Material widgets throughout,
styled after the reference platform in our own theme: the menu, the bar
group over media and the dialog look and move like iOS, and none of them is
a Cupertino widget (D-15). Cupertino widgets read `CupertinoTheme`, not
this theme; their page route's edge swipe fights Android's back gesture and
skips predictive back; their action sheets and alerts rise from a fixed
edge rather than from their source.

**Rule.** A symbol stands alone only when the action has a reliable shorthand
(search, share, add, close, back, play, pause, download, favourite).
Everything else carries a text label. A symbol-only control always has a
`tooltip`. The same symbol means the same thing everywhere; add an action to
`AppIcons` rather than picking a glyph at the call site.

Do not put an icon on a control that already has a label unless the pair is
conventional (trash + Delete). An icon on everything is noise.

## Badges and chips

A **badge** (`LakbayanBadge`) is a read-only 24dp capsule, all caps, 11/800:
FEATURED is solid deep gold (`featured`, gold/700) with white text; AR is
solid ink with white text; neutral states ("On this phone") are white with a hairline and green
text; factual metadata (`₱100 ENTRY`) is white with a hairline and ink text;
CLOSED is solid red with white text. The label always says what the colour
means. There is no OPEN NOW: `openHours` is free text and cannot be computed
against (`docs/DATA_MODEL.md`).

A **chip** is interactive and 38dp: white with the hairline and an ink label
at rest, solid green with white text when selected. Selection looks the same
on a chip, a segmented button and the navigation bar.

The **save heart** (`SaveHeart`) is the save control: filled red (`save`)
when saved and it pops a beat larger on the tap, outlined when not; a 48 white circle over a hero, a 32 circle on a
media tile, or a bare glyph as a row's trailing accessory. Always its own tap
target, never the row's only action.

## Fields

White with a hairline; the hairline turns green and 2dp on focus. The label is the placeholder. **No helper text, no counter, no error
line under the field**: an error is the error border plus a trailing
`AppIcons.warning` with a tooltip. Search fields are capsules; form fields are
`AppRadii.sm`.

## Structure

- **Content is edge to edge; interface is inset.** `Scaffold(extendBody: true)`
  so content flows under the navigation bar; the last item pads itself past
  the bar.
- **Nothing scrolls under the status bar** (2026-09-26, D-16 amendment).
  Every screen keeps an opaque ground there in the page's white
  (`StatusBarGround`); the home shell carries one for every tab, so lists
  and the map start below it. A header photo or map at rest (Place detail,
  a trip) still reaches the top edge, and the ground closes in under the
  status bar as the page reaches it.
- **No scroll edge treatment** (removed 2026-09-26, D-16 amendment). No
  blur and no fade where content scrolls under a pinned control: a pinned
  control carries its own surface (the tab bar's white capsule, a
  `SymbolButton`'s circle, a `BarItemGroup`). The progressive blur this
  replaced redrew two full-screen `BackdropFilter`s on every scroll frame
  and was the largest cost on every scrolling screen. The bar does not tint
  itself (the theme sets `scrolledUnderElevation: 0`). A home tab pads its
  scroll end by `FloatingTabBar.clearance`.
- **Tabs are built once and kept** (2026-09-26). The home shell builds a tab
  the first time it is chosen and keeps it, offstage and with its tickers
  muted while another is shown, so a tab switch never rebuilds a screen and
  scroll position, the map's camera and the carousel's page survive it.
- **The tab bar (D-16, revised 2026-09-26)** is one hairlined white capsule
  holding the four sections, then search as its last cell, all equal and
  all drawn in one stroke and box. It is glyph-only. Each item's name is its semantics label and its long-press
  tooltip. The glyphs are drawn (`TabGlyph`) and animate their selection
  once. The green indicator slides between sections and never lands on
  search. It **shrinks on a deliberate scroll.** `HomeChrome` holds the
  state: after ~48dp of downward travel, well past the header, the whole
  bar scales down to one touch target tall (`bottomNavCollapsed`), its
  base in place, every cell still one tap; it never changes shape. The
  shrink is one transform over the bar's kept picture, not a layout. A
  short scroll up, reaching the top, a tab switch, or a tap on the chosen
  section brings it back. Reduced motion gets a cross-fade instead.
- **Page transitions (2026-09-26).** Every pushed screen slides in from the
  trailing edge, opaque, while the one beneath drifts a third back and
  dims a touch; back plays the same path and follows the finger under
  Android's back gesture (`PushPageTransitionsBuilder`). A place opened
  from its photo zooms instead (`ZoomPage`): the photo (`PhotoHero`) grows
  from its tile into the page's, the page fades in around it, the screen
  beneath stays still, and back shrinks it home. A pushed screen arrives
  whole, without its sections fading in over the slide. A tab switch is a
  200ms cross-fade, the chosen tab over the one it replaces. No
  fade-through or shared axis between screens.
- **Keep or skip (2026-09-26)** is the one screen on a dark stage in either
  appearance: the front card's photo, decoded tiny and stretched (a blur
  with no filter), fills the screen and changes in step with the drag.
  Keep and Skip are buttons as well as the gesture, in the card's colour:
  its kind's deep tone (`role.kind`) until photos carry their own.
- **A trip's page** has one way into its map, the map itself: no pill and
  no floating button. The full-screen map carries Open in Map and each
  stop's directions. Each stop after the first says how far it is from
  the one before, in blue.
- **Search is the tab bar's last cell.** It grows into a field docked above
  the keyboard while the capsule slides away. Close, back and a picked
  result retrace the same `t`. No screen has a search field of its own. A
  town picked elsewhere reaches the Map and Browse as a removable chip.
- **Presented surfaces come from their source.** Menus are `AppMenu`
  (`app_menu.dart`), on `RawMenuAnchor`: it grows from the control that
  opened it and folds back into it on one spring, whether closed by an item,
  a tap outside or back. A row is the label, then its glyph trailing on a
  shared axis; every item has a glyph; groups are separate grey surfaces a
  gap apart, never divided; a destructive item is last, alone, red, with the
  trash. A menu of choices adds a leading check slot. Sheets via
  `showAppSheet` (with scrim, for an interrupting task) or `showBottomSheet`
  (no scrim, parallel task); dialogs via `showAppDialog`.
- **Predictive back is on** (`enableOnBackInvokedCallback` in the manifest).
  The app's own transitions (`PushPageTransitionsBuilder`, `ZoomPage`) hand
  the gesture's progress to the route, so the page follows the finger. Use
  `PopScope`, never `WillPopScope`. A screen the system back gesture cannot
  dismiss is a defect.
- **Compact first.** `FloatingTabBar` is the shipped navigation; the rail and
  drawer forms for medium and expanded widths are a later pass (the
  `AdaptiveNavigation` shell was removed unused in D-14). Browse's
  `_WidthClass` still drives its grid's column count; no widget contains a
  raw width number.
- **Spacing is the 2.3 tight rhythm (D-16):** screen gutter 12, 12 between
  sections, 4 inside a grouped section, 8 of row padding
  (`AppSpace.gutter / section / groupInset / rowPad`). Grouped sections are
  radius 16 with an 11 thumbnail derived inside; media tiles 14; heroes and
  the Profile block 24; sheets 28.

## Motion

Two springs, `AppMotion.chrome` and `AppMotion.arrive` (`motor`), carry
everything; where a built-in route takes only a curve, the spring is handed
over as a `SpringCurve` (modal sheets ride `chrome` up and back down).
Every route rides one push (`PushPageTransitionsBuilder`, on the same
spring), and tabs cross-fade (see Structure). A place's photo becomes its
page by zooming (`ZoomPage` with `PhotoHero`); a trip's row grows into its
route map as the page slides in. A map camera flies on its own declared
motion (`CameraFlight`), no bounce. Motion settles on
identity values in the same widget tree, never by swapping in the bare
child, which would rebuild it the moment it lands. A dialog settles in from a beat larger and
leaves by fading. Motion explains a change; if an animation does not say
where something came from, remove it. Honour `MediaQuery.disableAnimationsOf`
with a cross-fade, not a zero duration.

## Shared primitives

Each one's class comment carries its contract (purpose, anatomy, shape,
states, behaviour, adaptation). `lib/core/widgets/` is grouped by job:
`motion/` (how things move), `chrome/` (the app's frame: bars, sheets,
menus, the floating action), `controls/` (things you press or pick) and
`content/` (things that show content). Paths below are relative to it
unless they name a feature.

| Widget | File | What it is |
|---|---|---|
| `AppMotionBuilder`, `Pressable`, `SymbolSwap`, `Fold`, `FadeSwap`, `PopIn`, `Entrance`, `SpringCurve`, `showAppDialog` | `motion/motion.dart` | every shared motion, each settling on identity values in the same tree |
| `PushPageTransitionsBuilder`, `ZoomPage`, `PhotoHero` | `motion/page_transitions.dart` | every route's push, in from the trailing edge with the page beneath drifting back; a place opened from its photo zooms instead, the photo (`PhotoHero`) scaled, never re-decoded. Both follow Android's back gesture |
| `FloatingTabBar`, `TabBarLayout`, `TabGlyph` | `chrome/floating_tab_bar.dart` | one capsule, the four sections then search, all drawn glyphs; shrinks on scroll as one transform, slides away for search |
| `SystemBars`, `StatusBarGround` | `chrome/system_bars.dart` | the bars' icon style for a region; the opaque ground under the status bar (`.below` closes in under a resting header) |
| `_PinnedAction`, `_PinnedActionScope` | private in `destination_detail_screen.dart`, its one user | the floating primary action; folds into a circle while reading |
| `AppMenu`, `AppMenuItem` | `chrome/app_menu.dart` | the anchored menu: label then trailing glyph, grouped surfaces, grows from its source |
| `showAppSheet` | `chrome/app_sheet.dart` | the modal sheet, riding the keyboard |
| `SymbolButton` | `controls/symbol_button.dart` | a symbol-only control on its own white circle over photography |
| `BarItemGroup` | `controls/bar_item_group.dart` | two to four symbol-only actions on one capsule; `.overMedia` over a photo or map; an item may open a menu, or be a control of its own (`BarItem.control`, the save heart) |
| `FilterChipRow` | `controls/filter_chip_row.dart` | the single-select chips (the inline date picker is private in `trip_dates.dart`) |
| `MediaTile`, `MediaScrim` | `content/media_tile.dart` | a photograph with a caption below, or a title on a tested scrim; a trailing slot for the save heart |
| `StorageImage`, `CoverImage` | `content/storage_image.dart` | every photo, decoded at its box's size (or a fixed tiny width for a blur) |
| `GroupedSection`, `GroupedRow` | `content/grouped_section.dart` | comparable rows on the white ground, no dividers, no plate; a 56 photo and one second line; a row may carry a mark (a stop's numeral) |
| `AppCard` | `content/app_card.dart` | a tonal surface with a concentric-or-fallback radius, whole surface tappable |
| `LakbayanBadge` | `content/lakbayan_badge.dart` | read-only annotation |
| `StopNumeral` | `content/stop_numeral.dart` | a stop's number on a blue circle, the same on its pin and its row |
| `PageDots` | `content/page_dots.dart` | where you are in a swipeable row; a sliding window of dots past seven pages |
| `SectionHeading` | `content/section_heading.dart` | a sentence-case heading with an optional blue "See all" |
| `AudioGuideSection` | `features/audio/presentation/audio_guide_section.dart` | one white capsule on the page that opens the player sheet: the stop playing, progress, transport and every stop |
| `SaveHeart` | `features/destinations/presentation/save_heart.dart` | the save control in its four sizes, `bar` inside a `BarItemGroup` |
| `SelectionCircle`, `StopPicker` | `features/itineraries/presentation/stop_picker.dart` | the green check circle and selectable place rows |
| `CameraFlight`, `Basemap` | `features/maps/presentation/map_view.dart` | a map camera's flight (pull back, cross, settle in) and the tiles every map draws, appearing without a fade |
| `TourTile`, `TourRail` | `features/itineraries/presentation/tour_tile.dart` | a province tour as a 3:4 poster, and a row of them |

## Migrating from 1.0.0

Done. Every 1.0.0 forwarder (`AppRadius`, `AppShadow`, `appHairline`,
`AppTypography.h1` to `overline`, `context.lakbayan.line`, `textSecondary`,
the tints) was deleted in D-14 once nothing referenced it; `Icons.*` does not
appear in `lib/`. `DestinationCard`, `LakbayanListRow` and
`AdaptiveNavigation` are gone. If an old branch brings a name back, the
replacements are `AppRadii` and `capsule`, the ramp steps above, and the
`ColorScheme` roles.

## Precedence: design system vs wireframes

**The design system governs visual design. The wireframes govern app
structure.** When they disagree about what a screen contains or how navigation
works, the wireframes win. When they disagree about colour, type, shape or
component styling, this document wins.

Resolved under that rule:

- **Bottom navigation** is *Explore · Map · Itineraries · Profile* (wireframes).
- **Auth providers** are email/password + Google only (D-06); provider choice
  is scope, not structure.
- **Home's primary action is "Add to a tour" on the featured card in the
  middle of the carousel** (redesign 2a, D-16); building a trip from scratch
  is the Itineraries tab's New itinerary, a tinted `+` beside its title
  (2026-09-24, no longer a FAB). The wireframe's "create your own tour"
  entry survives there; structure is preserved, the form and the screen it
  lives on changed.
- **The Map tab lands on the map** (2c); the Browse photo grid is one symbol
  away. Wireframe 1c drew the grid first with a map toggle; the redesign
  inverts the default because a map is the tab's name and its job.
