# Design system

**Version 2.1.0** (D-13, amended by D-14). Values live in `design/tokens.json`;
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
| Width classes | `lib/core/theme/app_layout.dart` |
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
  step up (`surfaceContainerLow` for a card, `surfaceContainerHigh` for a
  menu). `elevation` is 0 everywhere; shadows do not exist in this system.
- On a white ground a **1dp hairline** (`outlineVariant`) bounds the things
  that need an edge to exist: chips at rest, outlined badges, form fields,
  the secondary button. It is not an emphasis mechanism and it is never a
  divider between rows.
- `Divider` **draws nothing** (the theme zeroes it). Separate rows with the
  padding inside a `GroupedSection`; separate sections with space.
- Exactly **one primary action per screen**, a solid green
  `FloatingActionButton` or `FilledButton`, separated from every bar group.
- Bar actions sit in a `BarItemGroup`: two to four symbol-only items on one
  capsule. A text button never joins a symbol group. Overflow goes to a menu.

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
green made a kept place look like a selected control. Home's
category strip colours each glyph by category (`categoryColor`): nature
green, churches and museums ink, heritage earth `#A4620D`, food red,
landmarks blue. That is identity, not state; selection is still solid green.

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
sits two steps above a desktop ramp and Regular is not in it. Hero steps are
Black 900, headings Bold, body 600, with tracking that tightens as size grows. A same-family
hierarchy is the quietest system there is, and it leaves **Barabara** as the
one loud voice: the landing greetings and the LAKBAYAN wordmark only (a
Philippine tourism trademark face, uppercase only, never a ramp step).

The ramp (`AppTypography`): `display` 38/900, `hero` 28/800 (a place name
over its photo), `titleLarge` 24/800, `titleMedium` 19/800, `groupHeading`
17/800 (over a grouped section), `titleSmall` 17/700; `bodyLarge` 17/600,
`bodyMedium` 15/600; `labelLarge` 15/700, `labelMedium` 13/700, `secondLine`
13/600 (a row's second line), `glyphLabel` 12/700, `labelSmall` 12/600,
`tabLabel` 11/700 (11/800 selected); `caps` 11/800 with wide tracking for
badges and the swipe stamp only. Headings are sentence case; there are no
all-caps eyebrows. Each step is distinguishable from its neighbour at arm's
length; that is the whole point of a ramp.

**Rule.** No `TextStyle` literals at call sites. Titles and body are left
aligned. Colour comes from the scheme (`onSurface` by default,
`onSurfaceVariant` for secondary text), not from the style.

Every style sets the `wght` axis through `FontVariation` because on a variable
font `fontWeight` alone selects the file's default instance. If a weight looks
wrong, that is why.

## Icons

**`CupertinoIcons` is the one icon family**, mapped in `AppIcons`. This is a
deliberate exception to the reference guidance of "Material icons for a
Material app": the glyph set is the team's choice for its lighter stroke,
and it carries no Cupertino *widgets* with it. Material widgets throughout.

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
- **A pinned control over a scroll view gets a `ScrollEdge`**, once per edge,
  one style per surface. The treatment is a progressive Gaussian blur and
  nothing else: blur strength ramps from nothing at the end of the falloff
  to full at the screen edge (three stacked `BackdropFilter`s of rising
  sigma, each masked shorter), so content hazes out rather than meets a
  band. No wash, no tint. The same band sits under the floating tab bar
  (`ScrollEdge.bottom`). The bar does not tint itself (the theme sets
  `scrolledUnderElevation: 0`).
- **The tab bar is a floating white capsule with a hairline**, inset 14 from
  the edges, content flowing under it. It **collapses on a deliberate
  scroll.** `HomeChrome` holds the state: after ~48dp of downward travel,
  well past the header, the bar drops
  its labels and hugs its four glyphs at one touch target tall. A short
  scroll up, reaching the top, a tab switch, or a tap on the collapsed bar
  brings it back. A nudge never flips it. The bar's real width and height
  are tweened, so it is a capsule at every size along the way; the indicator
  is a capsule inset one uniform step, so it stays concentric with the bar.
  Reduced motion gets a cross-fade instead of the morph.
- **Presented surfaces come from their source.** Menus via `MenuAnchor` or
  `PopupMenuButton`; sheets via `showModalBottomSheet` (with scrim, for an
  interrupting task) or `showBottomSheet` (no scrim, parallel task).
- **Predictive back is on** (`PredictiveBackPageTransitionsBuilder`,
  `enableOnBackInvokedCallback` in the manifest). Use `PopScope`, never
  `WillPopScope`. A screen the system back gesture cannot dismiss is a defect.
- **Compact first.** `FloatingTabBar` is the shipped navigation; the rail and
  drawer forms for medium and expanded widths are a later pass (the
  `AdaptiveNavigation` shell was removed unused in D-14). `WidthClass` still
  drives the Browse grid's column count; no widget contains a raw width
  number.
- **Spacing is the 2.1 compact rhythm:** screen gutter 14, 16 between
  sections, 4 inside a grouped section, 8 of row padding
  (`AppSpace.gutter / section / groupInset / rowPad`). Grouped sections are
  radius 16 with an 11 thumbnail derived inside; media tiles 14; heroes and
  the Profile block 24; sheets 28.

## Motion

The `animations` package supplies the Material motion patterns: shared axis
for parent/child navigation, fade-through for tab changes, container transform
for card to detail. Motion explains a change; if an animation does not say
where something came from, remove it. Honour `MediaQuery.disableAnimationsOf`
with a cross-fade, not a zero duration.

## Shared primitives

Each one's class comment carries its contract (purpose, anatomy, shape,
states, behaviour, adaptation).

| Widget | File | What it is |
|---|---|---|
| `AppCard` | `app_card.dart` | a tonal surface with a concentric-or-fallback radius, whole surface tappable |
| `GroupedSection`, `GroupedRow` | `grouped_section.dart` | comparable rows on one surface, no dividers; a row leads with media or an action glyph, its second line may carry a role colour |
| `BarItemGroup` | `bar_item_group.dart` | two to four symbol-only actions on one capsule |
| `ScrollEdge` | `scroll_edge.dart` | the progressive blur under a pinned top control, soft or hard |
| `MediaTile`, `MediaScrim` | `media_tile.dart` | a photograph with a caption below, or a title on a tested scrim; a trailing slot for the save heart |
| `SectionHeading` | `section_heading.dart` | a sentence-case heading with an optional blue "See all" |
| `SymbolButton` | `symbol_button.dart` | a symbol-only control on its own white circle over photography |
| `SaveHeart` | `features/destinations/presentation/save_heart.dart` | the save control in its three sizes |
| `SelectionCircle`, `StopPicker` | `features/itineraries/presentation/stop_picker.dart` | the green check circle and selectable place rows |
| `FloatingTabBar` | `floating_tab_bar.dart` | the hairlined white capsule bar; collapses on scroll |
| `LakbayanBadge` | `lakbayan_badge.dart` | read-only annotation |

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
- **Home's primary action is "Add to a tour" on the featured hero** (redesign
  2a); building a trip from scratch is the Itineraries tab's FAB. The
  wireframe's "create your own tour" entry survives as that FAB; structure is
  preserved, the form and the screen it lives on changed.
- **The Map tab lands on the map** (2c); the Browse photo grid is one symbol
  away. Wireframe 1c drew the grid first with a map toggle; the redesign
  inverts the default because a map is the tab's name and its job.
