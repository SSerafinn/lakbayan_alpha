# Design system

**Source of truth:** the Claude Design project *Lakbayan Design System* — specifically
its `tokens.json` (W3C design tokens, v1.0.0). Everything in `lib/core/theme/` is a
transcription of that file. If the two disagree, `tokens.json` wins and the Dart
should be corrected, not the other way round.

Live specimen: run the app in debug and open **`/design-system`** (there's a button
on the placeholder home screen). It renders the real theme with the real widgets, so
it is the fastest way to check a change.

## Where things live

| Concern | File |
|---|---|
| Colour ramps (`green/500`, `ink/900`, …) | `lib/core/theme/app_colors.dart` |
| Spacing, radii, shadows, fixed sizes | `lib/core/theme/app_dimens.dart` |
| Type scale + Material `TextTheme` | `lib/core/theme/app_typography.dart` |
| Brand tokens outside `ColorScheme` | `lib/core/theme/lakbayan_colors.dart` |
| `ThemeData` + component themes | `lib/core/theme/app_theme.dart` |
| Shared components | `lib/core/widgets/` |

## Using it

Reach for the theme, not the raw constants:

```dart
final scheme = Theme.of(context).colorScheme;   // primary, secondary, surface…
final brand  = context.lakbayan;                // gold, tints, badge fills
Text("Callao Cave", style: AppTypography.h3);
```

`AppColors.*` is for building the theme. Using it directly in a widget is the same
mistake as hardcoding a hex value — it bypasses dark mode.

## The rules that are easy to break

These come from the design system's own usage notes. Several are encoded
structurally so the code resists breaking them:

- **Gold is never a button.** It is an accent for AR and Featured badges only.
  Gold is deliberately *not* mapped to any `ColorScheme` action role — it lives in
  `LakbayanColors` so Material can never pick it up as an action colour.
- **Green text on a light background must be `/700` or darker.** `green/500` on
  white is only ~3.6:1 and fails WCAG AA. Use `context.lakbayan.textOnLightGreen`.
- **Never white text on gold.** Use `ink/900`.
- **Primary = green/500 fill. Secondary = blue/500 outline.** Blue never carries
  the primary CTA; it is for links, map surfaces and secondary actions.
- **Corners 12–16dp**, pill only for buttons and chips. No heavy colour bars.
- **48dp minimum touch target** on anything tappable.
- Photography is the hero — keep the chrome calm.

## Fonts

Plus Jakarta Sans (headings) and Inter (body) are **bundled** in `assets/fonts/`,
not fetched via `google_fonts`. Offline-first is a hard guardrail and `google_fonts`
downloads on first run by default.

Both are **variable** fonts. That has a sharp edge: on a variable font `fontWeight`
alone selects the file's default instance, so every style in `app_typography.dart`
also sets the `wght` axis through `FontVariation`. If you add a style and the weight
looks wrong, that is the reason.

Licences ship alongside the fonts (`*-OFL.txt`) — SIL Open Font License requires it.

## Dark mode

Marked **v2 scope** by the design system. The tokens and a full `ThemeData` exist and
`darkTheme` is wired, but `themeMode` is pinned to `ThemeMode.light` in `app.dart`
until the dark palette is signed off. The dark values beyond the four in
`tokens.json` (`bg`, `surface`, `text`, and the `/300` tints) were derived here and
have **not** been reviewed by design.

## Precedence: design system vs wireframes

**The design system governs visual design. The wireframes govern app structure.**
When they disagree about what a screen contains, how it is laid out, or how
navigation works, the wireframes win. When they disagree about colour, type,
spacing, or component styling, this document wins.

Resolved under that rule:

- **Bottom navigation** is *Explore · Map · Itineraries · Profile* (wireframes),
  not *Explore · Map · Trips · Saved* (specimen) — that is structure.

- **Auth providers** are email/password + Google only. The wireframes draw Facebook
  and Twitter buttons; those are out of v1 scope. This is the one deliberate
  exception to "wireframes win on structure" — provider choice is scope, not
  structure. Build the auth screen's *layout* from the wireframes, but render two
  providers. See `docs/DECISIONS.md` D-06.
