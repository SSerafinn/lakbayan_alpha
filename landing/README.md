# Landing page

Lakbayan's public promotion page: one static page, no build step, no
dependencies. HTML, CSS and a little JavaScript for the motion; the page is
complete without the script.

## Preview

```bash
cd landing && python -m http.server 5180
```

Then open <http://localhost:5180>. Any static server works.

## What it is made of

- **Design system 3.0** (`docs/DESIGN_SYSTEM.md`, `design/tokens.json`):
  paper, white cards, emerald for the one action, emerald words in the darker
  `#005C45`, pastels as washes and never as a button. The page adds one thing
  the app does not have: a darker edge under each button that presses down
  on a tap.
- **Fonts** in `fonts/` are WOFF2 conversions of the app's own bundled files
  in `assets/fonts/`: Cabinet Grotesk and Satoshi (Fontshare FFL, which
  allows self-hosting on our own site) and Barabara for the wordmark and the
  greetings, as on the app's landing.
- **Icons** in `images/icons.svg` are Phosphor (MIT), the app's icon family
  (D-20). The first block of the sprite matches `AppIcons`' glyphs.
- **Photos** are the app's sample photos from Wikimedia Commons, unmodified.
  Their licences require the credit in the footer's Photo Credits; keep the
  two lists in step with `assets/images/samples/CREDITS.md`. Replace them with
  the province's own photographs when those are cleared for the web.
- **The shoreline** is the app's `assets/images/footer.webp`, and the
  Endless Fun, Cagayan logo is the one the exhibit labels carry.

The app screens on the page are drawn in HTML from the app's real patterns
(the featured deck, the kind rail, the audio guide, offline towns, a trip,
the scan screen), not screenshots. The guides card shows towns, not names:
guides are real people (`docs/DATA_MODEL.md`).

## Before it goes public

- **The download button.** The app is not on Google Play yet, so the page
  says "Coming Soon on Google Play" and every Get the App button scrolls to
  that. Once the listing exists, replace the `store-soon` paragraph in
  `index.html` with a link to it.
- **Address.** Hosted on its own Firebase Hosting site,
  <https://lakbayan.web.app> (target `landing` in `firebase.json`; the CMS
  keeps `project-lakbayan.web.app`). The share image and canonical URL point
  there; change both if a custom domain is attached. There is no build step,
  so deploys are manual:

  ```bash
  firebase deploy --only hosting:landing --project project-lakbayan
  ```

  The headers enforce a strict CSP: everything from this site, no inline
  `style=` attributes or scripts. Keep new code to the stylesheet and
  `main.js`, or the browser will refuse it.
