# Decisions (current defaults for the scaffold)

These were open; the scaffold defaults to the left. Confirm with the team before large commitments.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D-01 | State management | **Riverpod 3** | Bloc |
| D-02 | Maps SDK | **flutter_map** — tile source superseded by D-11 | Mapbox (paid, easy offline) |
| D-03 | Local cache DB | **hive_ce** | Isar (complex queries) |
| D-04 | Admin app stack | **React** — *in `cms/`, not a separate repo; see D-10* | Flutter Web |
| D-05 | AR implementation | **native channel to ARCore** | ar_flutter_plugin |
| D-06 | Social auth (v1) | **Google + email** — *confirmed, see below* | add Facebook/Twitter later |

Accepted: province-first scope · Android-first · Firebase backend · companion positioning.

## D-06 · Auth providers — CONFIRMED (2026-08-03)

**Firebase Auth with email/password and Google Sign-In only for v1.**

This closes the conflict with the mobile wireframes, which draw Facebook and
Twitter buttons on the auth screen. Those two are **not** in v1 scope: each carries
a real external cost (Meta app review, X API pricing) that a provider toggle in the
Firebase console does not.

Note this is the one place the wireframes are *not* followed — D-07 gives wireframes
authority over app structure, but provider choice is scope, not structure. Build the
auth screen's layout from the wireframes; render two providers, not four.

## D-07 · Design system vs wireframes precedence

**Accepted.** The Claude Design *design system* governs visual design (colour, type,
spacing, component styling). The *wireframes* govern app structure (screens, layout,
navigation). Wireframes win on structure; the design system wins on styling.

First application: bottom navigation is *Explore · Map · Itineraries · Profile* per
the wireframes, not the specimen's *Trips · Saved*. See `docs/DESIGN_SYSTEM.md`.

## D-08 · Commit the dev Firebase config (2026-08-04)

**Accepted.** `android/app/google-services.json` and `lib/firebase_options.dart`
for the **dev** project (`project-lakbayan`) are committed.

They are not secrets. Firebase Android and Web API keys are public identifiers —
every shipped APK contains them and anyone can extract them in minutes. Access is
controlled by `firestore.rules`, `storage.rules` and App Check, not by hiding the
key.

Committing them is also load-bearing: the `com.google.gms.google-services` Gradle
plugin reads `google-services.json` at **build** time, so with it gitignored, CI
and every teammate fail with `File google-services.json is missing`.

A **production** project is different — keep its config out of the repo and inject
it in CI from a secret.

## D-13 · Design language 2.0: white first, Satoshi, three shape types, Cupertino glyphs (2026-09-12)

**Decision.** The 1.0.0 design system (green-washed surfaces; bordered,
shadowed cards; 16dp buttons; Plus Jakarta Sans + Inter; dividers; pale-tint
badges) is replaced by a white-first system whose hierarchy comes from
position, grouping, size, weight, a single tint and surface tone. Concretely:

- **Colour.** White ground, near-black text, grey chrome. Green is the
  signature and does four jobs at full strength: the one primary action,
  selection (solid green capsule, white text), links, the focus ring. No muted
  tints anywhere. Gold is the FEATURED badge only; red is CLOSED and errors.
- **Type.** One family, Satoshi (variable), set heavy: 900 for hero steps,
  800/700 for headings and labels, 600 for body. Regular is too light at
  phone sizes and is not in the ramp. Barabara stays for the landing greetings and the LAKBAYAN
  wordmark only (a Philippine tourism trademark face). Plus Jakarta Sans and
  Inter are removed. Khand and Switzer were tried on the branch and rejected:
  Khand is a condensed display face and read cramped in UI.
- **Shape.** Every rounded element is fixed, capsule or concentric
  (`lib/core/theme/app_shape.dart`). Buttons are capsules again; this reverses
  the 2026-08 note that reserved the pill for chips.
- **Surfaces.** White, with a grey ladder for the rare tonal step. No
  shadows. A 1dp hairline bounds chips, outlined badges and fields; it is
  never a divider. `Divider` draws nothing.
- **Badges and chips.** Solid, all caps, high contrast. Chips are quiet grey
  at rest and solid green when selected.
- **Icons.** `CupertinoIcons`, mapped once in `AppIcons`. A deliberate
  exception to "Material icons for a Material app"; Material widgets remain.
  *(Superseded by D-20: Phosphor, still mapped once in `AppIcons`.)*
- **Structure.** Predictive back on, edge-to-edge content, one primary action
  per screen as a FAB, bar actions grouped on a capsule, a scroll edge under
  pinned controls, one destination list rendered as bar / rail / drawer by
  width class.

**Why.** The 1.0.0 system expressed emphasis with decoration and washed every
surface in a pale green, which does not scale: every new screen added another
border, shadow or tint to compete with the last, and the brand colour meant
nothing because it was everywhere. Photography is the hero of this app; a white
chrome gets out of its way, and a green that appears only on the thing you can
act on is a green that means something.

**Where.** `docs/DESIGN_SYSTEM.md` is the committed statement;
`design/tokens.json` 2.0.0 records the values (1.0.0 groups kept so the CMS
generator still runs). The reasoning is the frontend lead's local design
reference. The 1.0.0 token names are deprecated forwarders; Explore and
Browse are on the new system, the remaining screens migrate as they are
touched.

## D-14 · Redesign 2.1: colour roles, compact rhythm, map-first Map tab, Offers out of scope (2026-09-13)

**Decision.** The 2a–2k redesign (frontend lead's reference,
`LAKBAYAN-REDESIGN.md`) is implemented across every screen. Four structural
changes on top of D-13:

- **Each screen states one job and gives it the largest element.** Home is
  a 412dp featured hero with the screen's only primary action, "Add to a
  tour"; the greeting, eyebrow labels and middots are gone everywhere.
- **Search is a circle pinned top-right over Explore's hero** that grows
  leftward into a field, matches dropping down under it; not a row that
  pushes the hero down, and not a slot in the tab bar.
- **Colour has assignments.** Green is the primary action and selection;
  blue is anything spatial (pins, distances, getting there, download); red
  is CLOSED, Sign out, Delete, the SKIP stamp and, since the first device
  pass, the saved heart (`save`); the AR badge is ink; gold (/700, white
  text) is FEATURED only. `tokens.json` 2.1.0 adopts the
  redesign's hexes as written and names the roles (`role.*`).
- **Spacing tightened by a third**: 14 gutter, 16 between sections, 4 inside
  a grouped section, 8 row padding; chips 38, primary buttons 50.

Three product calls were made alongside:

- **Save is red after all.** It was green (saved as a selection state)
  until the first device pass, where a green heart read as a selected
  control rather than a kept place. Red is now `role.save`, a role of its
  own beside `closed`; the selection idiom stays green everywhere else.
- **Offers (Home section 6, screen 2k) is out of scope.** No collection,
  no CMS screen, and no mention in `docs/`, `PLAN.md` or the intake pack.
  The Local Guides directory is a contact list of accredited people, not a
  marketplace. The request that would have to precede it is written up in
  the frontend lead's backend requests.
- **The Map tab lands on the map**; the Browse grid is one symbol away.
  Itineraries gained optional `startDate` and `endDate` (owner-only rules
  accept them today; the contract change is requested).

**Deleted.** `DestinationCard`, `LakbayanListRow`, `AdaptiveNavigation`,
`FeaturedDeck` (now `SwipeScreen`), the home-page proposals, and every 1.0.0
forwarder. Auth, landing and splash were migrated to 2.0 names without a
layout change; their redesign is a separate pass, as are the dark palette,
medium and expanded widths, and the tests that still assert 1.0 layouts.

**Why.** The previous screens ranked nothing, so the eye had nowhere to
land, and green alone could not distinguish a primary action from a saved
place at a distance. Naming the roles and tightening the rhythm made both
legible on a 393dp phone.

## D-16 · Glyph-only bar with search in the middle; a tighter rhythm (2026-09-23) · ACCEPTED (2026-10-01)

**Status.** Accepted 2026-10-01. It was proposed on `feat/home-screen` for the
team to confirm before merge, and #77 merged first; the acceptance came after,
once the merged build had been run on a phone. Said plainly because the order
matters to anyone reading the history: for two days the app ran on a decision
this log still called proposed.

Accepted with it are the four deviations #77 raised for review: the dark theme
on Keep or skip, where every other screen stays white first; the trip page
having no filled primary action, an exception to DESIGN_SYSTEM's one per screen
because there the map is the action; the icon-only directions arrow on stop
cards; and the kind colours (`color.kind.*`).

Two things in the text below do not match the repository, and are noted here
rather than rewritten, since the wording is its author's:

- The audio-guide paragraph says the stop pill and the tab bar's indicator
  "both call `indexedRect` (`core/widgets/motion.dart`)". No `indexedRect`
  exists in `lib/`; a later commit in #77 removed or renamed it.
- Several passages cite documents that are not in this repository — "design
  doc 04", `CLAUDE.local.md`, and elsewhere in the code `my-docs/…`,
  "STANDARDS" and "PREFERENCES". A reader cannot follow those references.

**Decision.**

- **The bar.** The four sections sit in one hairlined capsule, and search
  has its own white circle at the trailing end, the same height. Search is a
  destination, so it gets its own place (design doc 04). It is not green,
  because green stays the primary action and selection.
- **No tab labels.** A tab's name is its semantics label and its long-press
  tooltip. Selection is still carried twice, by the green capsule and by the
  glyph filling in. This departs from doc 06's central test: compass and
  briefcase are not universal shorthand. It is accepted because the bar is
  four stable sections that are learned once.
- **Drawn tab glyphs.** `TabGlyph` draws the four section glyphs with a
  painter, so each can animate its selection once and then settle (the
  compass needle, the map unfolding, the case lid, the person filling).
  `AppIcons` (D-13, now Phosphor per D-20) stays the set for everything
  else. `CrossGlyph` is
  gone with the category glyph strip. *(Retired 2026-10-23, D-20
  amendment: the bar takes `AppIcons` glyphs too.)*
- **Search.** The circle grows into a field docked above the keyboard, with
  the kinds, Recently viewed and the towns above it. Close, back and
  picking a result retrace the same spring. Explore's corner circle, the
  Map's field and the Browse grid's field are removed. A town picked
  elsewhere now arrives as a removable chip.
- **Explore, compact.** No wordmark or header row: the featured cards open
  the screen. Photos carry their captions on their own scrim (`MediaTile`
  `dense`), with Popular as a bento and tours as posters, so no line of white
  sits under a picture. The kinds are text chips, food among them. The towns
  are a row of round photos, and food has its own rail.
- **No grey plate, more colour.** (The coloured tiles are retired; see the
  2026-09-26 amendment.) The plate that stacked facts and settings
  as rows is gone. Facts, shortcuts and small actions are solid coloured
  tiles in one row (`ColorTileRow`), using the role colours at full
  strength. This loosens "no colour beyond the roles' jobs" on purpose: the
  app read grey. Place detail puts the map, directions and the CMS facts on
  one row of tiles; Profile's saved, downloads and settings are three tiles.
- **Audio guide.** One bar that opens on a tap into the player, the stops
  listed inside it with their full titles, in place of a stacked list with a
  player folding in. White like every other card, not a colour block
  (revised 2026-09-24, twice: first to ink, which still wasn't right —
  green belongs on the primary action and the selection, nowhere else, per
  Colour in `CLAUDE.local.md`). The play button is filled green; the running
  stop is a single green pill that slides between rows as it changes, not
  four rows each fading their own highlight, and not a second copy of the
  floating tab bar's indicator math — both call `indexedRect`
  (`core/widgets/motion.dart`). No stop count sits under the heading — the
  bar's second line names the current stop instead, or invites a first tap.
- **Place detail.** At most three badges on one line (FEATURED, AR, the
  kind); On the map and Directions as two buttons side by side; the CMS
  facts ranked, not shown as four equal boxes — hours and entry, the
  go-or-not facts, as a row of colour tiles; best time and getting around,
  the plan-ahead facts, as plain label/value lines under them, no fill
  (revised 2026-09-24: the two-column tile grid read as too much colour and
  variation for four facts of unequal weight).
- **The primary action floats.** `PinnedAction` is a green capsule at the
  trailing corner that folds into a circle while the person scrolls down,
  opens again on the way up or at the very top, and stays folded at the
  bottom so it never reopens over the screen's own trailing content
  (`PinnedActionScope`; revised 2026-09-24, it previously opened at either
  end — on Place detail that meant popping back open right over the Around
  Here rail).
- **New itinerary isn't a floating pill.** The Itineraries tab's primary
  action moved off `PinnedAction` entirely: a tinted `+` beside the
  "Itineraries" title, since the tab's content is often short, and a pill
  left floating over mostly empty space read as chrome with nothing to
  anchor to (revised 2026-09-24).
- **Trips.** A trip's stops are a timeline, a blue line through their
  numerals.
- **Local guides.** The `guides` collection (already in
  `docs/DATA_MODEL.md` and readable by a signed-in user under the current
  rules) appears on Explore for the first time: name, town, specialties,
  VERIFIED, and a tap that calls or emails. No rule, index or schema change.
- **Map sheet.** One scroll, as before, with the grip and the area's name
  pinned at its top. A row of place cards, one per page with page dots, is
  one selection with the pins, and the camera glides between them.
- **Settings.** A Settings screen holds Appearance and a Reduce motion
  switch. The switch adds to the phone's own setting through
  `disableAnimations`, so every motion widget honours it unchanged.
- **Rhythm.** The gutter and the section gap both go to 12 (from 14 and
  16). Body leading tightens: `bodyLarge` 1.4, `bodyMedium` 1.35,
  `secondLine` 1.25. `tokens.json` goes to 2.3.0.

**Why.** On a device the tabs read as a static list and the spacing read
loose. Search was hidden in one tab's corner, and the Map repeated it in its
own field. A travel companion should feel alive, which means motion that
explains, and one search reachable from everywhere.

### Amended 2026-09-26: performance, and a new Place detail

- **No scroll edge treatment.** The progressive blur under pinned controls
  (D-13's "a scroll edge under pinned controls") is removed everywhere, with
  no replacement. Once a page was scrolled it redrew two full-screen
  `BackdropFilter`s and two masks on every frame, the largest cost on every
  scrolling screen, for an effect nobody had noticed. A pinned control
  carries its own surface.
- **Tabs are built once and kept.** The home shell no longer rebuilds a tab
  on every switch; a tab is built when first chosen and kept offstage, its
  tickers muted, while another is shown. Map and Explore no longer rebuild
  from nothing on each visit, and they keep their state (doc 07).
- **Place detail, editorial and few words.** Supersedes the Place detail
  bullet above. The photo stage takes just over half the screen, clean: no
  words and no badges on it. The page rises over its foot on a rounded
  edge. Back, and share with the heart on one white capsule, stay pinned.
  On the page, with air between each part: the name large, then "Nature
  in Peñablanca" (the kind and the town) as one quiet line; the
  description as the lede, a new type step (`type.lede`, 20/550) and the
  page's one emphasised line; the audio guide as one capsule; the hours on
  one line, then two quiet buttons, Plan your visit (a sheet with entry,
  best time and access in full, and the CMS tags as capsules) and Getting
  there (a menu: On the map, Directions); the story growing open in place;
  Around here. FEATURED and AR leave the page; they are the feed's. No
  schema change: the CMS already holds these fields as they are shown.
- **No coloured tiles.** The pattern is retired app-wide. Profile's three
  and a trip's Take this trip offline become rows on the white ground, a
  glyph in its meaning's colour leading. `ColorTileRow` is gone.
- **Audio guide: a capsule and a player sheet.** Supersedes the audio
  guide bullet above. On the page, one white capsule (play, "Audio guide",
  the stop count on the control); while a stop plays it names the stop and
  its place in the guide. A tap opens the player, a sheet over a scrim
  owned by the section, so it is always this place's: the stop playing,
  progress, previous, play and next, then every stop. The running stop is a
  solid green numeral that eases out and in where it lands, replacing the
  sliding pill, which rushed when it jumped several stops.
- **A trip's header.** The route map is clean, with no title on a scrim.
  The page rises over its foot on the same rounded edge as Place detail,
  carrying the trip's name large and its dates. "Expand map" on a white
  capsule says the map opens.
- **Why.** On a phone, Explore and Map jittered while scrolling and on
  every tab switch, and Place detail read as a stack of words at one
  weight, with colour blocks competing for attention. The rules that keep
  the performance causes out: no `BackdropFilter`; tabs are kept, never
  rebuilt on a switch; a feed is slivers, one per section; an animation
  drives paint or layout, never build; a list item mounts with no animation
  controllers; performance is judged in a profile build.

### Amended 2026-09-26, later: the status bar, the bar, and transitions

- **A ground under the status bar.** Removing the scroll edge also removed
  the only thing between scrolled content and the status bar: cards, text
  and map pins ran under the clock and the battery. Every screen now keeps
  an opaque ground there in the page's white (`StatusBarGround`); the home
  shell carries one for every tab. A header photo or map at rest still
  reaches the top edge, and the ground closes in as the page reaches it.
  This narrows "content is edge to edge" above.
- **The bar is one capsule that shrinks.** Supersedes "search has its own
  white circle" and the fold into one circle. Search is the capsule's last
  cell. On a deliberate scroll the whole bar scales down to one touch
  target tall, every cell still one tap, instead of folding into a circle
  that hid three sections behind a tap.
- **Transitions, the iOS way.** Every pushed screen slides in from the
  trailing edge over the one it came from, which drifts back and dims a
  touch; Android's back gesture drives the same path under the finger. A
  tab switch is a short cross-fade with no white between tabs. The
  fade-through and shared-axis transitions between screens are gone, and a
  pushed screen no longer fades its sections in over the slide.
- **Why.** On a phone, content under the status bar read as broken; the
  folded bar hid sections; and both transitions blinked through white over
  full-screen opacity layers. Tracing the jitter found motion widgets that
  rebuilt their content from nothing the moment they settled (every
  screen's sections, about half a second after it opened); they now settle
  in the same tree.

### Amended 2026-09-26, last: photos that open, Keep or skip, trips, the map

- **A place's photo opens into its page.** Opened from a photo, a place
  zooms (`ZoomPage`): the photo grows into the page's own while the page
  fades in, the screen beneath still, and back shrinks it home. The featured
  card now opens from anywhere on it; its caption had covered the tap.
- **Keep or skip on a dark stage.** The front card's photo fills the
  screen, blurred by decoding it tiny, and changes with the drag. Keep and
  Skip are buttons too, in the card's colour, a new deep tone per kind
  (`role.kind`, `tokens.json`) until photos carry their own. "More details"
  goes; the card opens the place.
- **A trip's page: the map is the button.** The Expand map pill and the
  floating "Open on the map" go; the full-screen map carries Open in Map
  and each stop's directions, and each stop after the first gives its
  distance from the one before.
- **The map flies.** Choosing a place pulls the camera back, crosses and
  settles in, on a motion of its own with no bounce; tiles appear without
  a fade.
- **Why.** The featured cards did not answer most taps; Keep or skip read
  as empty and gesture-only; the trip page had three ways into one map;
  and the map dragged street-level tiles across every move. Tracing it
  found every photo flight re-decoding its photo each frame, which real
  photos would have shown as flicker.

## D-15 · Type half a step lighter; iOS-styled menus and groups on Material (2026-09-23) · ACCEPTED (2026-10-01)

**Status.** Accepted 2026-10-01, together with D-16 and on the same footing:
proposed on `feat/home-screen`, merged in #77 before the team had confirmed
it, and accepted once the merged build had been run on a phone.

**Decision.**

- **Type.** The Satoshi ramp moves half a step lighter: display 900 to 800,
  headings 800 to 750, labels 700 to 650, body 600 to 550, and nothing below
  550. Satoshi is variable, so 750, 650 and 550 are real instances set on the
  `wght` axis. `tokens.json` goes to 2.2.0.
- **Menus.** One menu, `AppMenu`, on `RawMenuAnchor`. The label comes
  first and the glyph trails it, the reference platform's order. Every item
  has a glyph, and groups are separate surfaces with a gap between them. It
  grows out of its source and folds back into it on `AppMotion.chrome`.
  Profile's Appearance and the itinerary's more menu both use it.
- **Groups over media.** `BarItemGroup.overMedia` is a white capsule over a
  photo or a map, and an item in it can open a menu.
- **Motion.** Modal sheets ride the chrome spring, through `SpringCurve`.
  Dialogs settle in from 1.08 scale and leave by fading. The itinerary
  route becomes a platform page, so a trip's row can grow into its map as a
  `Hero`.
- **Still Material widgets, and still D-13.** No Cupertino widget is used.

**Why.** On a device, 2.0's weights read heavy across a whole screen. The
Material dropdown opened from nowhere, and its rows sat on uneven slots. The
aim was an iOS feel on Android. Cupertino widgets would have to be themed
twice, since they read `CupertinoTheme`. Their edge swipe fights Android's
back gesture. Their sheets and alerts also rise from a fixed edge instead of
from their source. So the feel is built from our own tokens.

## D-19 · Design system 3.0: paper and white cards, emerald, Cabinet Grotesk, fewer words (2026-10-23) · PROPOSED

**Status.** Proposed. Built on `refactor/ui-less-wordy` in small child
branches (`ui-less-wordy/NN-name`), each reviewed into it, and merged to
`staging` only once the team confirms this entry.

**Why.** People using the app found it wordy (everything had a word
describing it), its type too large, its lists of places walls of text, and
the brand weak past the landing page. There was no room for galleries, and
Profile and Settings did not read as finished screens.

**Decision.**

- **Surfaces.** The page is paper (`#F3F2EE`); a card is white on it
  (`surfaceContainerLowest`); what sits inside a card takes paper again. Dark
  is warm charcoal (`#262624`, cards `#30302E`), not black. Still no shadows,
  and the hairline keeps its four uses. A control over a photo or a map sits
  on glass: white at 90%, opaque, no blur.
- **Colour.** Jade emerald `#00755A` (white on it 5.7:1; emerald words
  `#005C45`) for the primary action, selection, links and focus. The landing
  page's pastels (mint, sky, butter, blush) become each kind's surface and
  the brand's quiet moments; ink sits on them and they are never a button.
  Red stays the saved heart and destructive words. Blue narrows to the route
  and your own position. Gold is gone, with the FEATURED badge.
- **Type.** Cabinet Grotesk at 700 and 800 for headings, Satoshi at 550 and
  650 for every other word (D-15's floor holds). A compact ramp: display 28,
  hero 26, titles 20, 17 and 15, body 15 and 14, labels 15, 13 and 12.
  Barabara stays on the landing page only, the wordmark and the greetings.
- **Rhythm.** Tight inside a group, 16 between groups; the gutter stays 12.
- **Words become signals.** Headings are one or two words, and headings,
  labels, buttons and chips are Title Case. Cards carry no description; a
  second line appears only when it is a decision fact. A status is a glyph
  or position, not a badge word: the scan glyph on a photo, a verified
  guide's seal, featured as the deck. No count stands alone.
- **Structure.** Explore opens on its title, the kinds as photo pills and
  the featured places as a deck; its towns hang from a river. A town opens
  its own page. Search shows the places opened last, the towns and every
  place as photos. Place detail gains segments (Overview, Photos, Nearby,
  and Exhibits for a museum) with its facts in a collapsible Details.
  Settings is the standard categorized list with no row glyphs. The tab
  bar's chosen section shows its name, and the Itineraries tab is Trips.
- **Motion.** Continuity first, on the existing springs (`AppMotion`) and the
  `animations` package. No new dependency.
- **Tokens.** The app's values live under `app.*` in `tokens.json`, which the
  CMS generator does not read, so the CMS keeps D-17's look until it moves on
  purpose.

**What it reverses.** D-13's white ground and Satoshi-only hierarchy; from
D-16, the glyph-only bar, gold FEATURED and the kinds as text chips.

**For the team.** The Cabinet Grotesk font file is a new asset (Fontshare
FFL, app embedding allowed). The Town page is a structure change against the
wireframes. Barabara's licence is still unverified.

## D-20 · Phosphor glyphs in place of CupertinoIcons (2026-10-23) · PROPOSED

**Status.** Proposed, with D-19. Built on `ui-less-wordy/10-fixes`.

- **Decision.** `AppIcons` maps to Phosphor (MIT) instead of
  `CupertinoIcons`. It is still the one family and still reached only through
  `AppIcons`; call sites do not change. A filled glyph is the selected state
  of its outline, as before.
- **Bundled fonts, not the package.** `phosphor_flutter` 2.1.0 does not
  compile on this Flutter: its icon class extends `IconData`, now a final
  class. So the regular and fill fonts are app assets
  (`assets/fonts/Phosphor/`, licence beside them) and `AppIcons` declares the
  constant `IconData`s itself, which keeps icon tree shaking working. Adding a
  glyph means its codepoint from Phosphor's regular and fill sets.
- **Kinds get pictures.** `AppIcons.kind` maps Nature, Food, Churches,
  Heritage, Museums and Landmarks to mountains, fork and knife, church,
  castle turret, bank and flag, outline at rest and filled when chosen.
  CupertinoIcons has no fork, church or museum, so the kinds had only words
  or photos.
- **Still D-13 and D-15 otherwise.** No Cupertino widget is used.

**Amendment (2026-10-23, `ui-less-wordy/11-polish`).** Nothing in the app
names Cupertino any more. `cupertino_icons` is out of `pubspec.yaml` (no
code drew a `CupertinoIcons` glyph; go_router still brings `cupertino_ui`
in transitively, which is its own business). iOS takes our
`PushPageTransitionsBuilder` instead of `CupertinoPageTransitionsBuilder`.
The `AppMotion` springs are written as motor's neutral factories
(`Motion.snappySpring`, `Motion.bouncySpring`, and `Motion.smoothSpring` for
the map camera), the same springs with the same numbers. A release build
should be watched once for an "Expected to find fonts for CupertinoIcons"
warning from go_router's Cupertino pages, which the app never shows.

The tab bar now takes its glyphs from `AppIcons` as well (Phosphor compass,
map trifold, suitcase, user, magnifying glass; filled while chosen), so
`TabGlyph` and its painter are gone and the app has one glyph family with
no exception. The chosen section's name no longer grows out of the pill
(D-19's add): the bar is glyphs only, five equal cells, the names in
semantics and the tooltip.

**What it reverses.** D-13's "Cupertino glyphs".

**For the team.** Two font assets (about 0.9 MB before icon tree shaking) and
no new package. Since the amendment the tab bar uses them too.

## D-18 · AR pilot: a native scan screen, image markers, a card and narration (2026-10-21) · ACCEPTED

Phase 4 goes ahead as a pilot: one museum, recognised exhibits, tested in a
controlled setting before anything is deployed. It refines D-05 (native
channel to ARCore) into these choices:

- **ARCore Augmented Images.** The camera recognises a flat reference image —
  a photo of the exhibit or its placard — which is what museum exhibits offer
  without any extra hardware. No 3D models: what appears is a card naming the
  exhibit, and tapping it opens the story and narration, played by the same
  player as the audio guide. Models would need modelled assets nobody has.
- **A separate, full-screen native scan screen** (`ExhibitScanActivity`,
  Kotlin), started over a method channel and returning the recognised
  exhibit's id. Not a camera view embedded in a Flutter screen: hybrid
  composition with a camera surface is the fragile part of every AR plugin, and
  a separate activity keeps AR isolated — if it fails, nothing else does.
  `MainActivity` stays the `AudioServiceActivity` it must be.
- **AR is optional at install** (`com.google.ar.core` = `optional`, the AR
  camera feature not required), so the app still installs and runs fully on
  phones without ARCore. Those, a refused camera, or markers that are not on
  the phone get the same exhibits as a plain list, without the camera.
- **Content is a subcollection,** `destinations/{id}/exhibits`, with the
  segments' visibility rule. `hasAR` is set by the CMS from whether a museum
  has exhibits. Markers and narration travel in the town's offline bundle.
- **The pilot uses a stand-in marker** (a sample photo, printed or shown on a
  screen) for the Cagayan Museum until the province supplies photos of real
  exhibits and their placard text.

Rejected: `ar_flutter_plugin` (D-05's alternative; unmaintained, and its
Sceneform base is archived) and a WebXR or web-based route (Android-first app,
offline-first content).

## D-17 · The CMS: design system 2.3 for its look, an admin's layout for its structure (2026-10-07) · ACCEPTED

**Status.** Accepted 2026-10-07. Three directions were mocked on the
destination editor with the real tokens, Satoshi and the sample photos, and
this one chosen: a Polaris-style workspace (A), over a dense Linear-style
layout (B, fast for power users but explains little to new staff) and a
GOV.UK-style one-section-at-a-time flow (C, the clearest for a first visit
and the slowest for daily edits).

**Why it was needed.** The CMS had drifted to the design system's 1.0.0. It
used the 1.0 token groups only, because `cms/scripts/gen-tokens.mjs` never
emitted the 2.x ones (surface ladder, colour roles, the Satoshi ramp, shapes),
so it kept the shadows, pale green plates and all-caps eyebrows the app
dropped in D-13 and D-14. It also asked for Satoshi without loading it, so
every screen rendered in the operating system's font. On top of that: page
titles centred by a CSS collision on six of eight screens, three link styles,
action cells that came loose from their rows, and dates printed as
`07/10/2026`, which a Filipino reader takes for 10 July.

**Decision.**

- **Look: design system 2.3, unchanged.** White ground; cards are
  `surfaceContainerLow` with no border and no shadow; the hairline bounds
  fields and the secondary button; one solid green action per view; blue is
  spatial and never a button; gold is FEATURED and nothing else; Satoshi at
  800/750/650/550, sentence case, no eyebrows. `gen-tokens.mjs` now emits the
  2.x groups and the stylesheet reads those.
- **Structure: an admin's, after Shopify Polaris.** Polaris is built for
  people who are not developers editing a catalogue every day, which is the
  province's staff exactly — and its product editor maps nearly one to one
  onto a destination. So: a page header with the title and status on the
  left and the page's actions on the right; a top bar naming where you are
  and which backend you are on; an editor with the content in a main column
  and status, organisation and placement in a right-hand rail; index tables
  with thumbnails and saved views.
- **Rolled out in three PRs.** The foundation (shell, type, header, cards,
  tables, badges, the shared bugs); then the destination editor's two-column
  layout; then tours, guides, bundles and users.

**Where the CMS departs from the phone-sized rules, and why.**

- **Table rows keep a hairline between them.** DESIGN_SYSTEM says the
  hairline is never a divider between rows. A phone's rows are one column;
  an index table is six or seven, and the eye needs a line to read across.
- **Badges are sentence case with a status dot**, not 11/800 capitals. They
  appear a dozen to a screen at desk distance, where capitals slow a scan, and
  the dot plus the word keeps a status off colour alone.
- **Toasts are ink**, not white. A toast floats over the page; with no
  shadows in the system, a white one has nothing to separate it from a white
  page.
- **The page title uses the hero step (28)**, not titleLarge (24): on a wide
  screen at desk distance, 24 reads as a section heading.
- **Warnings use the error colour** (`role.error`), as the app's field
  warning glyph does, where the CMS used gold. Pending, stale and "cannot be
  published" are problems, and gold is FEATURED's.

## D-11 · Offline tiles — source decided, renderer pending a spike (2026-08-07)

**Partially accepted.** Full analysis in `docs/research/map-tiles.md`.

**Source: Protomaps PMTiles.** D-02's default — raster tiles from
`tile.openstreetmap.org` — **cannot** be used for Phase 3, and the reason is
legal rather than technical: the [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
prohibits bulk downloading and names "download city for offline use" as an
example. Protomaps is free, permissively licensed, permits self-hosting, and
`pmtiles extract` slices a region from the daily planet build into a single file
— which is already the shape `/tiles/{townId}/` assumes.

**Renderer: vector** (`vector_map_tiles` + `vector_map_tiles_pmtiles`), chosen
for download size. It also keeps the whole chain free: Protomaps publishes
vector, so raster would have meant paying for a raster source or adding a
rasterisation step.

One thing this trades, stated plainly so nobody is surprised: **vector is
lighter to download and heavier to draw.** Files shrink (Protomaps reports 70%+
from de-duplication), but glyphs and geometry are rasterised on-device every
frame instead of being decoded as images. The saving is in bandwidth and
storage, not CPU.

So the Phase 3 spike still runs — but as **validation, not a decision**. Pin
`vector_map_tiles` to a stable release (8.x; v10 uses `flutter_gpu` and is
beta), render a Peñablanca pack on the lowest-end phone available, and measure
pan/zoom frame times. If it stutters there, the fallback is raster and the cost
is a paid tile source, so it is worth knowing early rather than after
`features/maps` is built on top.

### Renderer settled as RASTER (2026-09-09) — this supersedes the paragraph above

**Source unchanged: Protomaps PMTiles. Renderer: raster, via
`flutter_map_pmtiles`.** Routes remain authored polylines.

The spike never ran, because resolving the packages first showed the recommended
stack **cannot be installed**. `vector_map_tiles` 8.x requires `flutter_map
^7.0.2`, and every PMTiles or MBTiles adapter pins `latlong2 ^0.9.0` against our
`^0.10.1`. Nine resolutions are tabulated in `docs/research/map-tiles.md`.

The decisive finding is that **every one of those failures is the same
`latlong2` conflict, and the pin causing it is ours** — `flutter_map` 8.3.2
accepts `>=0.9.1 <0.11.0` either way, and nothing in `lib/` imports `latlong2`.
Relax it and both raster packages resolve with **one downgrade and nothing
else**: no beta, no adapter of our own, no second package moved.

Vector, by contrast, costs two downgrades, an adapter we maintain, and a beta
renderer we would be **pinned to** — the later betas moved to a `latlong2` the
required `pmtiles` forbids, so there is no upgrade path from it.

Why raster is also the better fit on merit, not merely the cheaper one:

- **The map draws a basemap, pins and one authored polyline.** No dynamic
  restyling, no feature filtering. Vector's advantages are ones this app never
  uses.
- **The target is low-end Android.** Vector rasterises geometry and glyphs every
  frame; raster decodes an image. That gap is precisely what the spike existed
  to measure, and it falls on the hardware we care about.
- **The size argument that chose vector has weakened.** Vector was picked for
  download size; the buffer-union pack design has already cut a town to
  single-digit MB.

**The cost we are accepting: a rasterisation step**, since Protomaps publishes
vector. Build-time, per town, a few hundred tiles — `@maplibre/maplibre-gl-native`
renders a style headlessly and `pmtiles convert` bridges the formats. It belongs
in Docker, where this project's tooling already lives.

Open, and worth answering before that pipeline is built: how a rasterised
Protomaps basemap actually looks. That is a taste call for a tourism map.

Routes are **authored polylines**, not computed. `CONVENTIONS.md` already
specifies "map with pins + static route", so no routing engine is needed:
`PolylineLayer` draws a tour's path over the basemap, fully offline. For "take
me there", hand off to the device's map app via a `geo:` URI — driving
directions need live traffic, which no offline pack can provide.

**Do not use FMTC without checking the licence.** It is GPL-3.0, which would
oblige us to release the app's source. A free alternative licence exists for
open-source projects, so this hinges on whether Lakbayan is open-source. FMTC
also does not solve the source problem — it is a downloader, not permission.

**Design consequence:** bundle the union of ~2 km buffers around each town's
destinations at high zoom, plus the whole municipality at low zoom — not the
whole municipality at high zoom. Measured: a municipality at maxzoom 16 is
~25–60 MB of raster, at maxzoom 15 ~6–16 MB. Retrofitting this after shipping
whole-municipality packs means re-downloading everything.

## D-12 · Cloud Functions: `functions/`, Singapore, callables for what a browser must not do (2026-09-04)

**Accepted.** The first Cloud Functions land with the CMS Users screen, and they
set the shape for the ones Phase 3 adds (`generateOfflineBundle`):

- **One codebase, `functions/`**, TypeScript compiled to `lib/`, ESM, Node 22.
  Linted and unit-tested in the `cms` CI job alongside `scripts/` — the
  required-check list is fixed by name (see `docs/REPO_SETTINGS.md`), so a new
  job would not gate merges.
- **Region `asia-southeast1`** (Singapore), the nearest that offers 2nd-gen
  functions. Firestore's own location is separate and unaffected. The CMS
  names the region explicitly; a mismatch 404s rather than errors, which is
  why both sides carry a comment pointing here.
- **Callables, not Firestore triggers, for admin actions.** `setAdminRole` and
  `listAdmins` exist because custom claims can only be set by the Admin SDK,
  and the Admin SDK must never run in a browser. The alternative — an
  `admins/` collection the rules read — would cost a document read on every
  write check and give the claim two sources of truth. Rejected; the claim
  stays the only authority, as D-09 established.
- **The function refuses a self-revoke.** The last admin revoking their own
  claim would lock content editing until someone found a service account key.
  Two admins can still revoke each other, so this is a guard against the
  likely mistake, not a guarantee.
- **`scripts/grant-admin.mjs` stays** — as the bootstrap for the first admin
  on a fresh project, which by definition cannot be done from a screen that
  requires an admin. It is no longer the way to add a colleague.

Consequences: the emulators container now builds `functions/` on every start
(`docs/DOCKER.md`), and deploying will need the Blaze plan.

## D-10 · Monorepo — the CMS lives in `cms/`, not a separate repo (2026-08-04)

**Accepted. This reverses D-04's "separate repo"**; the React choice stands.

D-04 was made before the schema tooling existed. Three things now cross the app
boundary and would be split by a repo boundary:

- **The schema.** A change to `destinations` touches `docs/DATA_MODEL.md`,
  `firestore.rules`, `firestore.indexes.json`, the Dart model *and* the CMS
  editor form. That is one logical change. Two repos make it two PRs that must
  land in order — and the `/add-collection` skill exists precisely to keep those
  files moving together.
- **Design tokens.** `design/tokens.json` is consumed by both. Two copies drift,
  and `docs/DESIGN_SYSTEM.md` already states that if they diverge one is wrong.
- **Local infrastructure.** The emulator suite, the rules tests and
  `scripts/grant-admin.mjs` are shared. Duplicating Docker and ports across two
  repos is friction for three developers with no upside.

Layout: Flutter stays at the root (no disruptive move), CMS in `cms/`, shared
infrastructure at the root. Deployment stays independent — the CMS ships to
Firebase Hosting, the app to Play.

`design/tokens.json` is now committed here and is the single source of truth.
`cms/scripts/gen-tokens.mjs` generates CSS custom properties from it, so the
CMS palette is derived rather than retyped. The Flutter theme still transcribes
it by hand — that remains a drift risk worth automating later.

## D-09 · Admin CMS is in scope; timeline extends to 15 weeks (2026-08-04)

**Accepted.** Build the Admin CMS as wireframed — all 11 screens — and extend the
plan from 12 to 15 weeks rather than cutting scope.

The CMS was missing from `PLAN.md` entirely, despite being required by three
existing documents: `ARCHITECTURE.md` describes it, D-04 fixes its stack, and the
MVP Definition of Done in `CONVENTIONS.md` says *"admin can publish a destination"*.
The admin wireframes specify Login, Dashboard, Destinations list, Destination
Editor, Audio Guide segments, AR Content, Offline Bundles, Tours, Local Guides,
Users + roles, and Settings.

It is also a hard dependency, not a parallel nicety: every content write in
`firestore.rules` requires the `admin` claim, so mobile Phase 2's DoD — "browse
real destinations end-to-end" — cannot be met until the CMS can publish.

Cut order if the schedule slips: AR, then CMS Settings, then itineraries. Never
CMS-1.

### Bootstrapping the admin claim

`isAdmin()` reads `request.auth.token.admin`, and until now **nothing set it** —
no account could write content, including the project owner. `scripts/grant-admin.mjs`
fills that gap: emulator by default, `--live` with a service account for a real
project. CMS-3 replaces it with a callable Cloud Function once the Users screen
exists, so promoting a teammate no longer needs a service account key.

## Forced during scaffold setup (2026-08-03)

- **D-01 is now Riverpod 3, not 2.** On Dart 3.11.4 no `riverpod_lint` release
  co-resolves with `flutter_riverpod` 2.x. Taken while zero Riverpod code existed.
  Note the v3 API differences before writing providers.
- **D-03 is now `hive_ce`,** the maintained community fork. Plain `hive` 2.x and
  `hive_generator` no longer resolve.
- **D-02 wording corrected.** `flutter_map` renders *raster* tiles; it is not
  MapLibre (that would be `maplibre_gl`). Offline tiles still need an extra
  package — see D-11.
