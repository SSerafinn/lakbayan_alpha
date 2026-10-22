# Design system

**Version 3.0.0** (D-19, on D-13 to D-16). Values live in `design/tokens.json`
under `app.*` (with `shape.*` and `size.*`); the Dart under `lib/core/theme/`
transcribes them. If the two disagree, `tokens.json` wins and the Dart is
corrected. The CMS stays on 2.3.0 (D-17), from the file's other groups.

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
| Brand tokens outside `ColorScheme` (pastels, glass, save, spatial) | `lib/core/theme/lakbayan_colors.dart` |
| `ThemeData` and every component theme | `lib/core/theme/app_theme.dart` |
| Shared primitives | `lib/core/widgets/` |

Reach for the theme, not the raw constants:

```dart
final scheme = Theme.of(context).colorScheme;   // roles: primary, surfaceContainerLowest…
final brand  = context.lakbayan;                // pastels, glass, save
Text("Callao Cave", style: AppTypography.titleSmall);
Icon(AppIcons.search)                           // never CupertinoIcons.x or Icons.x directly
```

`AppColors.*` is for building the theme. Using it in a widget bypasses dark
mode, the same as a hex literal.

## The rules that carry accessibility

These are requirements, not preferences.

- **A pastel is never a button** or a selection. Gold is gone with the
  FEATURED badge (D-19); featured is the deck's position, not a colour.
- **Green words on a light ground are the darker emerald.** Use
  `context.lakbayan.textOnLightGreen` (`#005C45`, 6.9:1 on paper), never the
  primary fill as text.
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

- The ground is **paper** (`surface`). A card is white on it
  (`surfaceContainerLowest`), and what sits inside a card takes paper again
  (`surfaceContainerLow`): never grey on grey. A menu's groups float on
  `surfaceContainerHigh`, which reads over paper and card alike. A control
  over a photo or a map sits on glass (`context.lakbayan.glass`, white at
  90%), opaque, never a blur. `elevation` is 0 everywhere; shadows do not
  exist in this system.
- A **1dp hairline** (`outlineVariant`) bounds the things
  that need an edge to exist: chips at rest, outlined badges, form fields,
  the secondary button. It is not an emphasis mechanism and it is never a
  divider between rows.
- `Divider` **draws nothing** (the theme zeroes it). Separate rows with the
  padding inside a `GroupedSection`; separate sections with space.
- **Rows sit on one white card (D-19).** `GroupedSection` is the card,
  compact, with a 48 photo and one second line; its heading is small and
  quiet above it. A card never holds a card.
- **No coloured tiles** (retired 2026-09-26, D-16 amendment). Shortcuts and
  small actions are rows on a card. A fact is words where it is needed,
  folded away until asked for (Place detail's Details).
- Exactly **one primary action per screen**, a solid green
  `FloatingActionButton` or `FilledButton`, separated from every bar group.
- Bar actions sit in a `BarItemGroup`: two to four symbol-only items on one
  capsule. A text button never joins a symbol group. Overflow goes to a menu,
  which the group's last item can open (`BarItem(menu:)`). Over a photo or a
  map the group is `BarItemGroup.overMedia`, a glass capsule the height of a
  `SymbolButton`; on the page it is a white one.

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

**Emerald, ink, paper and pastels (D-19).** Photos carry most of the colour;
each brand colour has one job (`app.light` and `app.dark` in `tokens.json`,
the `ColorScheme` and `context.lakbayan` in Dart):

| Role | Light | Dark | Used on |
|---|---|---|---|
| `primary` emerald | `#00755A` | `#3ECF9E` | the one primary action per screen; selection (chip, segment, tab pill); focus |
| emerald words | `#005C45` | `#3ECF9E` | links and green text (`textOnLightGreen`) |
| `spatial` blue | `#1F6FD1` | `#7FB2F0` | the route and your own position. Never a button fill |
| `save` red | `#D93A30` | `#F2837A` | the saved heart, filled |
| `closed` red | `#C8352C` | `#F2837A` | destructive words (Sign Out, Delete), CLOSED, the SKIP stamp |
| error | `#C42B1B` | `#F0A5A5` | field error border and warning glyph |
| pastels | mint, sky, butter, blush | their dark tones | a kind's surface (`kindWash`: nature mint, museum and landmark sky, church and heritage butter, food blush) and the brand's quiet moments: landing, sign-in, empty states |

Ink sits on a pastel, and a pastel is never a button or a selection.
Explore's hanging towns add two quiet tones of their own, `river` and
`cord`.

The neutrals: `onSurface` ink (`#1B1B19`) for text, `onSurfaceVariant`
(`#6B6A64`) for second lines, `outlineVariant` (`#E5E3DC`) for the hairline.
The surface roles:

| Role | Light | Dark | Used on |
|---|---|---|---|
| `surface` | `#F3F2EE` paper | `#262624` | the page, sheets, the status bar ground |
| `surfaceContainerLowest` | `#FFFFFF` | `#30302E` | cards, grouped sections, the tab bar, controls on the page, pin rings |
| `surfaceContainerLow` | paper | `#262624` | what sits inside a card |
| `surfaceContainerHigh` | `#E5E3DC` | `#44433F` | a menu's groups, media placeholders |
| `surfaceContainerHighest` | `#DEDCD4` | `#4E4D48` | image placeholders, disabled fills |
| `glass` | white at 90% | charcoal at 88% | controls over a photo or a map |

- **No muted tints.** `primaryContainer` exists for Material's sake and for
  pressed states; a badge, a chip, a card or a section is never filled with
  a pale version of emerald.

Dark mode is **live**: `themeMode` follows the phone by default, and Settings
offers System, Light or Dark (`AppThemeMode`, kept in `AppPreferences`). It
is warm charcoal, not black, with the same card-on-page step as light.

## Type

Two voices, both bundled as variable fonts (offline-first; no
`google_fonts`). **Cabinet Grotesk** sets the headings at 700 and 800: one
loud, compact voice for names and titles (Fontshare FFL, app embedding
allowed). **Satoshi** sets every other word at 550 to read and 650 for
labels, never below 550 (D-15), since it draws light at phone sizes. Both
are variable, so the in-between weights are real instances, not rounding.
Tracking tightens as a heading grows. **Barabara** stays on the landing page
only: the LAKBAYAN wordmark and the greetings (a Philippine tourism
trademark face, uppercase only, never a ramp step).

The ramp (`AppTypography`, D-19), compact so a screen holds more than one
idea:

| Step | Face | Size / weight | Used on |
|---|---|---|---|
| `display` | Cabinet | 28 / 800 | a screen's large title |
| `hero` | Cabinet | 26 / 800 | a place's, a town's or a person's name on their own page |
| `titleLarge` | Cabinet | 20 / 700 | a bar or sheet title |
| `titleMedium` | Cabinet | 17 / 700 | a section heading, a name on a photo tile |
| `groupHeading` | Satoshi | 13 / 650 | the small heading over a settings group |
| `titleSmall` | Satoshi | 15 / 650 | a row's or a card's name |
| `bodyLarge` | Satoshi | 15 / 550 | reading text |
| `bodyMedium` | Satoshi | 14 / 550 | the default body |
| `labelLarge` | Satoshi | 15 / 650 | buttons and controls |
| `labelMedium` | Satoshi | 13 / 650 | chips, pills, the tab label |
| `secondLine` | Satoshi | 13 / 550 | a row's second line |
| `labelSmall` | Satoshi | 12 / 550 | captions |

`caps` (11/750, wide tracking) stays for badges and the swipe stamp until
the last badge goes. **Headings, labels, buttons and chips are Title Case**
(Day Tours, See All, Sign Out; D-19); reading text, tooltips and messages
are sentence case. There are no all-caps eyebrows. Each step is
distinguishable from its neighbour at arm's length; that is the whole point
of a ramp.

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

**On a photo, a status is a glyph or a fact** (`PhotoPill`, D-19): the scan
glyph alone on a glass circle where a museum's exhibits can be scanned, a
distance or a date on a glass capsule. Featured is position (the deck), not
a word. A **badge** (`LakbayanBadge`), a read-only 24dp capsule in caps,
remains only off the photo while its screens move: neutral ("On this
phone"), white with a hairline and green text; factual (`₱100 ENTRY`), ink
text; CLOSED, solid red. There is no OPEN NOW: `openHours` is free text and
cannot be computed against (`docs/DATA_MODEL.md`).

A **chip** is interactive and 38dp: white with the hairline and an ink label
at rest, a round photo leading where the kind is a place (Explore's kinds).
The chosen chip's emerald pill travels from chip to chip on the chrome
spring, painted behind the row (`FilterChipRow`), and the label turns
white. Selection travels the same way in the tab bar.

The **save heart** (`SaveHeart`) is the save control: filled red (`save`)
when saved and it pops a beat larger on the tap, outlined when not; a 48 glass circle over a hero, a 32 circle on a
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
  Every screen keeps an opaque ground there in the page's paper
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
- **The tab bar (D-16, revised by D-19)** is one hairlined white capsule,
  60 tall, holding Explore, Map, Trips and Profile, then search as its last
  cell, all drawn in one stroke and box. The chosen section's name grows out
  of its emerald pill; the others are glyphs, their names in semantics and
  the long-press tooltip. The pill slides to the chosen section and only
  the two cells it moves between change width, as a layout pass and a
  repaint, never a rebuild. The glyphs are drawn (`TabGlyph`) and animate
  their selection once. It **shrinks on a deliberate scroll.** `HomeChrome` holds the
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
  the keyboard while the capsule slides away, close on its own circle beside
  it. Above it, before a word is typed: the places opened last as chips,
  the towns as photos, then every place as a grid of photos; typing narrows
  the grid. Close, back and a picked result retrace the same `t`. No screen
  has a search field of its own.
- **Explore (D-19)** opens on its title, the kinds as photo pills, then the
  featured places as a deck (`FeaturedDeck`): the front card full size,
  the next two waiting behind, their edges showing; a swipe deals one. Its
  towns hang from a river on cords at a fixed tilt, a still picture with
  nothing swinging. A town opens its own page (`TownScreen`), the photo
  zooming: its kinds as chips, the first place wide, the rest as a grid,
  and taking it offline on glass beside back.
- **Place detail (D-19)** keeps its photo stage, a third of the screen with
  the dots on the photo, then the name and the place one part at a time:
  Overview (the description and history cut at three lines with Read
  More, the facts folded under Details, the audio guide card, Location
  with a small still map, Known For), a museum's Exhibits, Photos and
  Nearby. The parts' pill travels and their content slides in on the
  `animations` shared axis, inside the page. CMS free text is tidied for
  reading, never rewritten: times as "8 AM", PHP as ₱, the part after the
  first comma on a quieter line. A photo opens the viewer, a dark stage
  whose blur is the photo decoded tiny; a pull down closes it.
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
- **Spacing is compact (D-19):** tight inside a group, a clear but short
  step between groups. Screen gutter 12, 16 between sections and between
  cards, 6 between things that belong together (a heading and its content,
  chips, grid photos, a row's padding), 4 from a grouped card's edge to its
  rows (`AppSpace.gutter / section / near / groupInset`). Grouped cards are
  radius 16 with their rows and photos derived inside; media tiles 14;
  heroes 24; sheets 28.

## Loading, empty and error states

Set in the Phase 5 integration pass. **Rule** for every section that reads
data.

- **Three states, never folded into one.** A list derived from another
  provider stays an `AsyncValue` (`deriveKeepingValue` over its source, as
  `savedPlaces` does), never `.value ?? []`. Otherwise "still loading" and
  "couldn't load" both read as "nothing here". Empty copy ("Nothing
  matches", "Every place is already on this trip") is for loaded and empty
  only.
- **What is on the phone outranks an error.** A section reads its provider
  with `whenLocalFirst`, and a derived list is made with
  `deriveKeepingValue` (`lib/core/errors/local_first.dart`), never with
  Riverpod's `when(skipError: true)` or `whenData`. Riverpod retries a
  provider that fails after loading for about 38 seconds and reads as
  loading meanwhile: `when` then swaps what is on screen for its spinner,
  `skipError` or not, and `whenData` drops the value outright. Decided by
  what there is instead: a value stays through the failure and the
  retries; with no value, the error shows at once; loading while there is
  neither, or while a value is replaced for changed inputs (another
  category, another account). A test of this keeps Riverpod's default
  retry.
- **Loading** is the section's own placeholder where its shape is known
  (the featured card, Popular's bento, the audio guide's capsule), a
  spinner otherwise; search says "Looking…". Which of the two a section
  uses is not yet unified.
- **Error copy** comes from `errorCopy` (`lib/core/errors/error_copy.dart`):
  what did not load, then what to do. Offline (a dead socket, a timeout,
  Storage or Auth giving up on the network) gets the offline sentence,
  anything else the generic one; a screen that knows better what still
  works offline may say so instead (Downloads, the audio guide). Firestore's
  lists seldom get it: offline, a listener answers from the cache rather
  than failing, so a first launch with nothing cached reads as empty, not
  offline. **Never the exception's text**: it goes to `debugPrint`, once
  per failure.
- **Try again** is `QuietNote(onRetry:)` or `MessageScreen(onRetry:)`: the
  theme's text button, never filled, never gold. It invalidates the
  provider that failed, which for a derived list is its source; invalidating
  the derived one would only derive the same failure again. While it runs,
  the section shows its loading state, so the tap is seen to land; not yet
  while Riverpod's own retries are still going, when the tap restarts one
  and the error stays until it settles.
- **Optional rails hide** while loading, when empty and on an error. Each
  rail's build says why in one comment, and whether another section says
  the error instead: the search surface's towns do for Recent, while
  Explore's town and food rails read every place, a listener of their own,
  and go without a word if only that read fails. The audio guide is not
  optional: it holds its place while loading and says when it cannot be
  read.
- **A link to nowhere** gets `MessageScreen` (the router's `errorBuilder`),
  whose back goes Home when there is nothing to go back to.

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
| `AppMotionBuilder`, `Pressable`, `SymbolSwap`, `Fold`, `FadeSwap`, `PopIn`, `Entrance`, `SpringCurve`, `TravellingPill`, `showAppDialog` | `motion/motion.dart` | every shared motion, each settling on identity values in the same tree; `TravellingPill` paints the selection pill of the chips and a place's parts |
| `PushPageTransitionsBuilder`, `ZoomPage`, `PhotoHero` | `motion/page_transitions.dart` | every route's push, in from the trailing edge with the page beneath drifting back; a place opened from its photo zooms instead, the photo (`PhotoHero`) scaled, never re-decoded. Both follow Android's back gesture |
| `FloatingTabBar`, `TabBarLayout`, `TabGlyph` | `chrome/floating_tab_bar.dart` | one capsule, the four sections then search, all drawn glyphs, the chosen one's name growing out of its pill; shrinks on scroll as one transform, slides away for search |
| `SystemBars`, `StatusBarGround` | `chrome/system_bars.dart` | the bars' icon style for a region; the opaque ground under the status bar (`.below` closes in under a resting header) |
| `_PinnedAction`, `_PinnedActionScope` | private in `destination_detail_screen.dart`, its one user | the floating primary action; folds into a circle while reading |
| `AppMenu`, `AppMenuItem` | `chrome/app_menu.dart` | the anchored menu: label then trailing glyph, grouped surfaces, grows from its source |
| `showAppSheet` | `chrome/app_sheet.dart` | the modal sheet, riding the keyboard |
| `SymbolButton` | `controls/symbol_button.dart` | a symbol-only control on its own glass circle over photography, or a white one on the page (`onGround`) |
| `BarItemGroup` | `controls/bar_item_group.dart` | two to four symbol-only actions on one capsule; `.overMedia` over a photo or map; an item may open a menu, or be a control of its own (`BarItem.control`, the save heart) |
| `FilterChipRow` | `controls/filter_chip_row.dart` | the single-select chips, a photo leading where given, the emerald pill travelling between them (the inline date picker is private in `trip_dates.dart`) |
| `MediaTile`, `MediaScrim`, `PhotoPill` | `content/media_tile.dart` | a photograph with a caption below, or a title on a tested scrim; a glass pill top leading (the scan glyph, a distance, a date); a trailing slot for the save heart |
| `StorageImage`, `CoverImage` | `content/storage_image.dart` | every photo, decoded at its box's size (or a fixed tiny width for a blur) |
| `GroupedSection`, `GroupedRow` | `content/grouped_section.dart` | comparable rows on one white card, no dividers; a 48 photo and one second line; a row may carry a mark (a stop's numeral) |
| `AppCard` | `content/app_card.dart` | a white card on the page, its radius provided downward, whole surface tappable |
| `LakbayanBadge` | `content/lakbayan_badge.dart` | read-only annotation off the photo, until its last screens move |
| `StopNumeral` | `content/stop_numeral.dart` | a stop's number on a blue circle, the same on its pin and its row |
| `PageDots` | `content/page_dots.dart` | where you are in a swipeable row; a sliding window of dots past seven pages |
| `SectionHeading` | `content/section_heading.dart` | a one or two word Title Case heading with an optional emerald "See All" |
| `FeaturedDeck` | `features/destinations/presentation/featured_deck.dart` | Explore's featured places as a deck: one transform per card on the chrome spring |
| `TownPhoto` | `features/destinations/presentation/explore_sections.dart` | a town's photo with its name, opening its page; Explore's hanging towns and search's |
| `AudioGuideSection` | `features/audio/presentation/audio_guide_section.dart` | one white card on the page, the place's photo with play on it, that opens the player sheet: the stop playing, progress, transport and every stop |
| `PhotoViewer` | `features/destinations/presentation/photo_viewer.dart` | a place's photos full screen on a dark stage, zoomed from their tile; a pull down closes it |
| `SaveHeart` | `features/destinations/presentation/save_heart.dart` | the save control in its four sizes, `bar` inside a `BarItemGroup` |
| `SelectionCircle`, `StopPicker` | `features/itineraries/presentation/stop_picker.dart` | the green check circle and selectable place rows |
| `CameraFlight`, `Basemap`, `StillMapCredit` | `features/maps/presentation/map_view.dart` | a map camera's flight (pull back, cross, settle in), the tiles every map draws, appearing without a fade, and the ODbL credit on a map that does not move |
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

- **Bottom navigation** is *Explore · Map · Itineraries · Profile*
  (wireframes); since D-19 Itineraries is labelled Trips.
- **Auth providers** are email/password + Google only (D-06); provider choice
  is scope, not structure.
- **Explore has no primary button** (D-19, reversing D-16's "Add to a
  tour" on the featured card): the deck opens a place, and a place's page
  carries Add to Trip. Building a trip from scratch is the Trips tab's
  New Itinerary, a tinted `+` beside its title. The wireframe's "create
  your own tour" entry survives there.
- **A town has its own page** (D-19), a structure change against the
  wireframes, for the team to confirm: before, a town was the Map tab
  filtered to it.
- **The Map tab lands on the map** (2c); the Browse photo grid is one symbol
  away. Wireframe 1c drew the grid first with a map toggle; the redesign
  inverts the default because a map is the tab's name and its job.
