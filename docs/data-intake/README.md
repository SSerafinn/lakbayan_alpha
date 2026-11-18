# Lakbayan — content intake pack

Templates for gathering content from the **Provincial Tourism Office / DOT
Region II**. Five CSVs, one per kind of thing the app holds.

Every column here maps to a field in `docs/DATA_MODEL.md`, which is the
front-end↔back-end contract. Columns that do **not** map to a stored field are
marked *(intake only)* below — we keep them in the spreadsheet for provenance
and follow-up, and they never reach the app.

## How to fill these in

- **One row per thing.** One destination per row in `01`, one audio stop per row
  in `02`, and so on.
- **`ref` is the join key.** Give every destination a short code you invent —
  `PEN-001`, `TUG-004`. The other files refer to destinations by that code. It
  is not the app's internal id; it exists so the sheets can point at each other
  before anything is imported. It only has to be unique and stable.
- **Leave a cell blank if unknown.** Blank means "not known yet". Do not write
  `N/A`, `none`, or `TBA` — those get imported as literal text and show up in
  the app.
- **Multiple values go in one cell separated by semicolons**: `caves;river;hiking`.
  Not commas — commas break the CSV.
- **Yes/no columns** take `yes` or `no`. Blank uses the default noted per column.
- **Save as CSV UTF-8.** In Excel: *Save As → CSV UTF-8 (Comma delimited)*. This
  matters — plain CSV mangles the ñ in Peñablanca and Santo Niño.
- **Each file has one EXAMPLE row. Delete it before sending back.**

## The files

| File | What it holds | Who usually has it |
|---|---|---|
| `01-destinations.csv` | Places — the core of the app | Tourism office records |
| `02-audio-guide-segments.csv` | Narration, stop by stop | Tour guides, heritage officers |
| `03-tours.csv` | Curated multi-stop itineraries | Tourism officers |
| `04-local-guides.csv` | Accredited guide directory | Accreditation / licensing unit |
| `05-photos.csv` | Photo manifest — the files come separately | Media / promotions unit |

`01` is the one that matters most. Nothing else in the app works without
destinations, and everything else points at them.

## Three things to raise in the meeting

**1. Photos need permission, not just files.** `05` has a `licence_or_permission`
column and it is not paperwork for its own sake — the app is a public release, so
every image needs someone able to say it may be published. Photos we cannot clear
cannot ship. Ask who signs off on this.

**2. Guides are personal data.** `04` collects the names and phone numbers of
real people. The app already requires a signed-in account to read that directory
for this reason. The `consent_to_publish` column must be `yes` per person before
we list them. Ask whether the accreditation process already captures this consent,
or whether it needs to be collected separately.

**3. Ask what languages the narration exists in.** The v1 schema stores **one**
narration per stop. If the province has scripts in Ilocano, Filipino *and*
English, that is a schema change and a UI change, and it is much cheaper to know
now than after the audio player is built. `02` has a `language` column
*(intake only)* purely to surface this — record what exists, and we will decide
how to handle it.

## Column reference

Required columns are the ones without which the row cannot be imported at all.

### 01-destinations.csv

| Column | Rules |
|---|---|
| `ref` | **Required, unique.** Your own code, e.g. `PEN-001`. |
| `name` | **Required.** As it should appear in the app. |
| `town` | **Required.** Must be one of the 29 municipalities listed below, spelled exactly. |
| `category` | **Required.** Exactly one of: `church`, `nature`, `heritage`, `museum`, `food`, `landmark`. |
| `short_description_max_140_chars` | **Required, hard limit 140 characters** including spaces. It is the text on the card and the layout depends on it — longer text is not truncated, it is rejected. |
| `history_long_form` | Optional, any length. Shown on the detail screen only. |
| `latitude` / `longitude` | Decimal degrees, e.g. `17.7089` / `121.8226`. **Not** degrees-minutes-seconds. Blank if unknown. |
| `location_notes` | How to find it, if the coordinates are unknown or approximate. We can geocode from this. |
| `entry_fee`, `open_hours`, `best_season`, `accessibility` | Free text, shown exactly as written. Blank if unknown. |
| `tags_semicolon_separated` | Lowercase keywords, e.g. `caves;river;hiking`. |
| `is_museum_yes_no` | Default `no`. Marks it as a museum site. |
| `show_in_popular_yes_no` | Default `no`. Puts it in the Popular Places row. |
| `featured_yes_no` | Default `no`. Gives it the FEATURED badge. |
| `eligible_for_nearby_yes_no` | Default **yes**. Whether it may appear in other places' "nearby". |
| `include_in_offline_yes_no` | Default **yes**. Whether it goes in downloadable town packs. |
| `information_source` | *(intake only)* Where the text came from — brochure, staff, website. |
| `contact_person_and_number` | *(intake only)* Who to ask when something needs checking. |

Valid `town` values: Abulug, Alcala, Allacapan, Amulung, Aparri, Baggao,
Ballesteros, Buguey, Calayan, Camalaniugan, Claveria, Enrile, Gattaran, Gonzaga,
Iguig, Lal-lo, Lasam, Pamplona, Peñablanca, Piat, Rizal, Sanchez-Mira,
Santa Ana, Santa Praxedes, Santa Teresita, Santo Niño, Solana, Tuao,
Tuguegarao City.

### 02-audio-guide-segments.csv

| Column | Rules |
|---|---|
| `destination_ref` | **Required.** Must match a `ref` in `01`. |
| `stop_number` | **Required.** 1, 2, 3… in playing order, per destination. |
| `stop_title` | **Required.** Short — it is a list item, e.g. "The chapel chamber". |
| `stop_caption` | Optional one-liner shown beside the stop. |
| `narration_script` | The words spoken at this stop. **Give this even when a recording exists** — it is what a deaf or hard-of-hearing visitor reads, and it is what the device reads aloud if the recording fails to download. |
| `recording_filename` | If audio exists. `mp3`, `m4a`, `aac`, `wav` or `ogg`. Send the files alongside the sheet. |
| `language` | *(intake only)* See point 3 above — the schema stores one narration per stop today. |
| `notes` | *(intake only)* Anything we should know. |

A stop needs **either** a script or a recording. One with neither is silent in
the player, and the CMS will refuse to publish the destination until it is fixed.

### 03-tours.csv

| Column | Rules |
|---|---|
| `ref`, `title` | **Required.** |
| `description` | What the tour is and who it suits. |
| `stop_refs_in_order_semicolon_separated` | **Required.** Destination `ref`s in visiting order: `PEN-001;PEN-004;TUG-002`. Order matters. |
| `cover_photo_filename` | Listed in `05` too. |
| `featured_yes_no` | Default `no`. |
| `route_file_gpx_or_kml` | The actual road route between stops, if it exists. Worth asking for: the app draws the line the province specifies rather than computing one, so without this a tour is a set of pins with no route drawn between them. A GPX or KML export from any mapping tool works. |
| `typical_duration`, `starting_point`, `transport_notes` | *(intake only for now)* — not in the schema yet. Collect them anyway; they are the questions every visitor asks and they will inform the Tours screen. |

### 04-local-guides.csv

| Column | Rules |
|---|---|
| `ref`, `name`, `town` | **Required.** |
| `specialties_semicolon_separated` | e.g. `caving;birdwatching;heritage walks`. |
| `contact_phone`, `contact_email` | At least one. Combined into a single contact field on import. |
| `languages_spoken_semicolon_separated` | *(intake only for now)* — not in the schema yet, but obviously useful to a visitor. |
| `accredited_yes_no` | Whether the province vouches for them. Shown as a verified marker. |
| `accreditation_number` | *(intake only)* For our records and for checking later. |
| `featured_yes_no` | Default `no`. |
| `consent_to_publish_yes_no` | **Required, must be `yes` to import.** See point 2 above. |
| `consent_recorded_by` | *(intake only)* Who obtained it and when. |

### 05-photos.csv

| Column | Rules |
|---|---|
| `destination_ref` | **Required.** Must match a `ref` in `01`. |
| `filename` | **Required.** Must match the actual file sent. |
| `use_as_cover_yes_no` | Exactly one `yes` per destination — that is the card photo. |
| `caption` | Optional. |
| `photographer_or_credit` | Who took it. |
| `licence_or_permission` | **Required.** See point 1 above. Without it we cannot ship the photo. |
| `year_taken`, `notes` | *(intake only)* |

Landscape orientation is much better than portrait — cards crop to 16:9. Send
the largest version available; we resize, and we cannot un-resize.

## What we are deliberately not asking for

- **Offline map bundles** — generated by us from the destination list, not
  collected.
- **AR marker images** — a stretch goal for one pilot museum exhibit. Worth
  asking *whether* a museum is interested; not worth collecting assets yet.
- **Slugs, ids, publication status** — generated on import.

## Importing a filled-in workbook (for us, not for DOT)

`scripts/import-content.mjs` reads the workbook back and writes it to Firestore.

```bash
cd scripts && npm install && node import-content.mjs ../docs/data-intake/Lakbayan-content-intake.xlsx
```

That is a **dry run** — it validates everything, prints what it would do, and
writes nothing. Add `--commit` to write, and `--media <dir>` pointing at the
folder of photos and recordings to upload those too. It talks to the emulator
unless given `--live`.

Three properties worth knowing:

- **Everything imports as a draft.** An import is never a live mistake.
- **Validation is all-or-nothing.** One bad row and nothing is written. A
  half-imported province is worse than an unimported one, because you cannot
  tell by looking which half arrived.
- **Silence keeps what is there.** A place with no rows on sheet 2 keeps its
  audio guide, and one with no rows on sheet 5 keeps its photos, as they are
  — they may have been made in the CMS since. For a place the sheet *does*
  list, it is the whole set: stops or photos it no longer names are removed.
- **It is idempotent.** Re-running updates rather than duplicates, matching on
  the slug derived from the name, and overwrites the same Storage objects
  instead of stranding the previous ones. Send a corrected sheet back through
  it as many times as you like.

It refuses to import a guide without consent, a photo without a licence, a
description over 140 characters, a category outside the six, a stop with
neither script nor recording, and coordinates outside Cagayan.

## Where the first wave stands (2026-10-21)

`Lakbayan-content-intake.xlsx` holds the first researched wave: **31
destinations in 16 towns** — 16 nature, 10 churches, 3 landmarks, a heritage
site and the Cagayan Museum. Every row has its name, town, category, short
description, long form, location and access notes, tags and source. It does
**not** import yet, by design: the photos are what stop it.

- **Photos (sheet 5) are research, not files.** Each row is a link to an image
  found online, with no licence or permission recorded, and the importer
  refuses every one. Fifteen come from the province's own sites
  (visit.cagayan.gov.ph, endlessfuncagayan.com) — ask the tourism office for
  the originals and written permission. Seven are on Wikimedia Commons, free
  with credit once each file page is checked. The rest are other sites'
  photos: replace them, or ask their owners.
- **Coordinates are approximate, for testing.** None came with the research;
  each was looked up on 2026-10-21 from OpenStreetMap, GCatholic plus codes or
  Wikipedia, and its row's *information source* says which, and how close it
  is. 21 are the place itself, 7 the centre of its barangay, and 3 —
  Laglagto, the Sierra Madre View Deck and Pozorobo — are only their town's
  centre. Confirm each pin in the CMS before publishing.
- **Not yet gathered:** entry fees, opening hours, best season, contact
  people, and anything on sheets 2–4 (audio guide stops, tours, local guides),
  which still hold only the template's examples.

To try the places without the photos, import a copy with sheet 5's rows
emptied; the rest validates.

**Imported live on 2026-11-18:** all 31 destinations, 19 of them published,
with 20 cleared photos. [first-wave-photos.md](first-wave-photos.md) records
what is live, each photo's source, credit and licence, and why the rest are
still drafts.

## What happens to it afterwards

Everything imports as **draft**. Nothing becomes visible in the app until an
administrator reviews it in the CMS and presses Publish, so a half-finished or
mistaken row is not a live mistake.

A destination cannot be published until it has a name, a town, a short
description, coordinates and at least one photo. Those five are the ones worth
chasing in the room; the rest can follow by email.
