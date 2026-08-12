"""Generate Lakbayan-content-intake.xlsx from the CSV templates beside it.

The CSVs are the source of truth for *which* columns exist. This adds the
things a CSV cannot carry — dropdowns, a length guard on the 140-character
description, coordinate bounds, a read-me sheet — and aborts if a sheet's
columns have drifted from its CSV, so the two formats cannot silently diverge.

Committed so the workbook stays reproducible. Without it the .xlsx is an opaque
binary that nobody can regenerate when the schema changes, and it quietly goes
stale. Not part of any build or of CI; run it by hand after editing a CSV:

    pip install openpyxl
    python docs/data-intake/build-workbook.py
"""

import csv
from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

INTAKE = Path(__file__).resolve().parent
OUT = INTAKE / "Lakbayan-content-intake.xlsx"

FONT = "Arial"

# Cagayan's municipalities, from cms/src/types/towns.ts. Keep the two in step —
# `town` is the grouping key for offline bundles, so a spelling that exists in
# one place and not the other silently becomes a second town.
TOWNS = [
    "Abulug", "Alcala", "Allacapan", "Amulung", "Aparri", "Baggao",
    "Ballesteros", "Buguey", "Calayan", "Camalaniugan", "Claveria", "Enrile",
    "Gattaran", "Gonzaga", "Iguig", "Lal-lo", "Lasam", "Pamplona",
    "Peñablanca", "Piat", "Rizal", "Sanchez-Mira", "Santa Ana",
    "Santa Praxedes", "Santa Teresita", "Santo Niño", "Solana", "Tuao",
    "Tuguegarao City",
]
CATEGORIES = ["church", "nature", "heritage", "museum", "food", "landmark"]
YESNO = ["yes", "no"]

MAX_DESCRIPTION = 140
DATA_ROWS = 300  # how far down validation and formatting reach

REQ, OPT, INT = "required", "optional", "intake"

HEADER_FILL = {
    REQ: PatternFill("solid", fgColor="1F4E3D"),
    OPT: PatternFill("solid", fgColor="5B7F71"),
    INT: PatternFill("solid", fgColor="8A8A8A"),
}

EXAMPLE_FILL = PatternFill("solid", fgColor="FFF8E1")
OVERLONG_FILL = PatternFill("solid", fgColor="FFC7CE")
THIN = Side(style="thin", color="D0D0D0")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

# (csv_header, display_header, kind, width, validation)
SHEETS = {
    "1 Destinations": {
        "csv": "01-destinations.csv",
        "note": "One row per place. Nothing else in the app works without this sheet.",
        "cols": [
            ("ref", "ref *", REQ, 16, None),
            ("name", "name *", REQ, 28, None),
            ("town", "town *", REQ, 18, "town"),
            ("category", "category *", REQ, 14, "category"),
            ("short_description_max_140_chars", "short description *  (max 140 chars)", REQ, 52, "desc"),
            ("history_long_form", "history / long form", OPT, 52, None),
            ("latitude", "latitude", OPT, 12, "lat"),
            ("longitude", "longitude", OPT, 12, "lng"),
            ("location_notes", "location notes", OPT, 34, None),
            ("entry_fee", "entry fee", OPT, 16, None),
            ("open_hours", "open hours", OPT, 20, None),
            ("best_season", "best season", OPT, 16, None),
            ("accessibility", "accessibility", OPT, 28, None),
            ("tags_semicolon_separated", "tags  (semicolon separated)", OPT, 26, None),
            ("is_museum_yes_no", "is museum", OPT, 12, "yesno"),
            ("show_in_popular_yes_no", "show in popular", OPT, 14, "yesno"),
            ("featured_yes_no", "featured", OPT, 11, "yesno"),
            ("eligible_for_nearby_yes_no", "eligible for nearby  (default yes)", OPT, 18, "yesno"),
            ("include_in_offline_yes_no", "include in offline  (default yes)", OPT, 18, "yesno"),
            ("information_source", "information source", INT, 26, None),
            ("contact_person_and_number", "contact person and number", INT, 26, None),
        ],
    },
    "2 Audio guide": {
        "csv": "02-audio-guide-segments.csv",
        "note": "One row per stop. A stop needs either a script or a recording — one with neither is silent in the player.",
        "cols": [
            ("destination_ref", "destination ref *", REQ, 18, None),
            ("stop_number", "stop number *", REQ, 13, None),
            ("stop_title", "stop title *", REQ, 28, None),
            ("stop_caption", "stop caption", OPT, 34, None),
            ("narration_script", "narration script", OPT, 60, None),
            ("recording_filename", "recording filename", OPT, 26, None),
            ("language", "language", INT, 16, None),
            ("notes", "notes", INT, 30, None),
        ],
    },
    "3 Tours": {
        "csv": "03-tours.csv",
        "note": "One row per itinerary. Stop order matters — it is the order visitors walk or drive.",
        "cols": [
            ("ref", "ref *", REQ, 14, None),
            ("title", "title *", REQ, 30, None),
            ("description", "description", OPT, 52, None),
            ("stop_refs_in_order_semicolon_separated", "stop refs in order *  (semicolon separated)", REQ, 36, None),
            ("cover_photo_filename", "cover photo filename", OPT, 26, None),
            ("featured_yes_no", "featured", OPT, 11, "yesno"),
            ("route_file_gpx_or_kml", "route file  (GPX or KML)", OPT, 24, None),
            ("typical_duration", "typical duration", INT, 18, None),
            ("starting_point", "starting point", INT, 26, None),
            ("transport_notes", "transport notes", INT, 30, None),
        ],
    },
    "4 Local guides": {
        "csv": "04-local-guides.csv",
        "note": "Personal data. Nobody is listed without consent_to_publish = yes.",
        "cols": [
            ("ref", "ref *", REQ, 14, None),
            ("name", "name *", REQ, 26, None),
            ("town", "town *", REQ, 18, "town"),
            ("specialties_semicolon_separated", "specialties  (semicolon separated)", OPT, 30, None),
            ("contact_phone", "contact phone", OPT, 18, None),
            ("contact_email", "contact email", OPT, 26, None),
            ("languages_spoken_semicolon_separated", "languages spoken", INT, 26, None),
            ("accredited_yes_no", "accredited", OPT, 12, "yesno"),
            ("accreditation_number", "accreditation number", INT, 22, None),
            ("featured_yes_no", "featured", OPT, 11, "yesno"),
            ("consent_to_publish_yes_no", "consent to publish *", REQ, 18, "yesno"),
            ("consent_recorded_by", "consent recorded by", INT, 30, None),
        ],
    },
    "5 Photos": {
        "csv": "05-photos.csv",
        "note": "One row per image file. Send the files themselves alongside this workbook.",
        "cols": [
            ("destination_ref", "destination ref *", REQ, 18, None),
            ("filename", "filename *", REQ, 26, None),
            ("use_as_cover_yes_no", "use as cover  (exactly one per place)", REQ, 20, "yesno"),
            ("caption", "caption", OPT, 34, None),
            ("photographer_or_credit", "photographer or credit", OPT, 24, None),
            ("licence_or_permission", "licence or permission *", REQ, 32, None),
            ("year_taken", "year taken", INT, 12, None),
            ("notes", "notes", INT, 26, None),
        ],
    },
}


def read_csv(name):
    # utf-8-sig: the CSVs carry a BOM so Excel does not mangle the enye.
    with open(INTAKE / name, encoding="utf-8-sig", newline="") as fh:
        return list(csv.reader(fh))


def style_header(cell, kind):
    cell.font = Font(name=FONT, size=10, bold=True, color="FFFFFF")
    cell.fill = HEADER_FILL[kind]
    cell.alignment = Alignment(vertical="center", wrap_text=True)
    cell.border = BORDER


def build():
    wb = Workbook()

    # ---- reference lists, the source for every dropdown ---------------------
    lists = wb.active
    lists.title = "Lists"
    lists["A1"] = "town"
    lists["B1"] = "category"
    lists["C1"] = "yes/no"
    for col in "ABC":
        style_header(lists[f"{col}1"], REQ)
    for i, t in enumerate(TOWNS, start=2):
        lists[f"A{i}"] = t
    for i, c in enumerate(CATEGORIES, start=2):
        lists[f"B{i}"] = c
    for i, y in enumerate(YESNO, start=2):
        lists[f"C{i}"] = y
    for col, width in (("A", 22), ("B", 16), ("C", 10)):
        lists.column_dimensions[col].width = width
    for row in lists.iter_rows(min_row=2, max_row=len(TOWNS) + 1, max_col=3):
        for cell in row:
            cell.font = Font(name=FONT, size=10)
    lists["E1"] = (
        "Reference lists. The dropdowns on the other sheets read from here — "
        "editing a value here changes what those dropdowns offer."
    )
    lists["E1"].font = Font(name=FONT, size=10, italic=True, color="666666")

    town_dv_src = f"=Lists!$A$2:$A${len(TOWNS) + 1}"
    cat_dv_src = f"=Lists!$B$2:$B${len(CATEGORIES) + 1}"
    yesno_dv_src = f"=Lists!$C$2:$C${len(YESNO) + 1}"

    # ---- one sheet per intake file -----------------------------------------
    for title, spec in SHEETS.items():
        rows = read_csv(spec["csv"])
        csv_headers, example_rows = rows[0], rows[1:]
        expected = [c[0] for c in spec["cols"]]
        if csv_headers != expected:
            raise SystemExit(
                f"{spec['csv']} headers drifted from the workbook spec:\n"
                f"  csv:  {csv_headers}\n  spec: {expected}"
            )

        ws = wb.create_sheet(title)

        # Row 1 is the note, row 2 the headers, row 3+ the data. The importer
        # (scripts/import-content.mjs) depends on that layout.
        ws["A1"] = spec["note"]
        ws["A1"].font = Font(name=FONT, size=10, italic=True, color="444444")
        ws.row_dimensions[1].height = 18

        for i, (_, display, kind, width, _v) in enumerate(spec["cols"], start=1):
            cell = ws.cell(row=2, column=i, value=display)
            style_header(cell, kind)
            ws.column_dimensions[get_column_letter(i)].width = width
        ws.row_dimensions[2].height = 32

        for r, example in enumerate(example_rows, start=3):
            for c, value in enumerate(example, start=1):
                cell = ws.cell(row=r, column=c, value=value)
                cell.font = Font(name=FONT, size=10, italic=True, color="7A6A00")
                cell.fill = EXAMPLE_FILL
                cell.alignment = Alignment(vertical="top", wrap_text=True)
                cell.border = BORDER

        first_blank = 3 + len(example_rows)
        last = 2 + DATA_ROWS
        for r in range(first_blank, last + 1):
            for c in range(1, len(spec["cols"]) + 1):
                cell = ws.cell(row=r, column=c)
                cell.font = Font(name=FONT, size=10)
                cell.alignment = Alignment(vertical="top", wrap_text=True)
                cell.border = BORDER

        # ---- validation ----------------------------------------------------
        for i, (csv_name, _d, _k, _w, kind) in enumerate(spec["cols"], start=1):
            if kind is None:
                continue
            letter = get_column_letter(i)
            rng = f"{letter}3:{letter}{last}"

            if kind in ("town", "category", "yesno"):
                src = {"town": town_dv_src, "category": cat_dv_src, "yesno": yesno_dv_src}[kind]
                dv = DataValidation(type="list", formula1=src, allow_blank=True)
                dv.error = "Pick a value from the list."
                dv.errorTitle = "Not on the list"
                dv.prompt = {
                    "town": "One of Cagayan's 29 municipalities.",
                    "category": "One of: church, nature, heritage, museum, food, landmark.",
                    "yesno": "yes or no. Blank uses the default.",
                }[kind]
                dv.promptTitle = "Pick from the list"
            elif kind == "desc":
                dv = DataValidation(
                    type="textLength", operator="lessThanOrEqual",
                    formula1=str(MAX_DESCRIPTION), allow_blank=True,
                )
                dv.error = (
                    f"This is the text on the card and the layout depends on it. "
                    f"Keep it to {MAX_DESCRIPTION} characters or fewer — put the "
                    f"longer version in the history column."
                )
                dv.errorTitle = f"Longer than {MAX_DESCRIPTION} characters"
                dv.prompt = f"Max {MAX_DESCRIPTION} characters including spaces."
                dv.promptTitle = "Short description"
            elif kind in ("lat", "lng"):
                lo, hi = (16.8, 19.2) if kind == "lat" else (120.7, 122.6)
                dv = DataValidation(
                    type="decimal", operator="between",
                    formula1=str(lo), formula2=str(hi), allow_blank=True,
                )
                dv.error = (
                    "Outside Cagayan. Expected decimal degrees such as 17.7089 / "
                    "121.8226 — not degrees-minutes-seconds, and not swapped."
                )
                dv.errorTitle = "Does not look like a Cagayan coordinate"
                dv.prompt = f"Decimal degrees between {lo} and {hi}."
                dv.promptTitle = "Coordinate"
            else:
                continue

            dv.showInputMessage = True
            dv.showErrorMessage = True
            ws.add_data_validation(dv)
            dv.add(rng)

            # Pasting into Excel bypasses validation entirely, and pasting is
            # exactly how existing text gets moved in, so the length limit gets
            # a visual backstop that a paste cannot dodge.
            if kind == "desc":
                ws.conditional_formatting.add(
                    rng,
                    FormulaRule(
                        formula=[f"LEN({letter}3)>{MAX_DESCRIPTION}"],
                        fill=OVERLONG_FILL,
                        stopIfTrue=False,
                    ),
                )

        ws.freeze_panes = "B3"
        ws.auto_filter.ref = f"A2:{get_column_letter(len(spec['cols']))}{last}"

    build_readme(wb)
    wb.move_sheet("Read me first", offset=-(len(wb.sheetnames) - 1))
    wb.move_sheet("Lists", offset=len(wb.sheetnames))
    wb.active = 0
    wb.save(OUT)
    print(f"wrote {OUT.name}")
    print("sheets:", wb.sheetnames)


def build_readme(wb):
    ws = wb.create_sheet("Read me first")
    ws.column_dimensions["A"].width = 3
    ws.column_dimensions["B"].width = 104
    ws.sheet_view.showGridLines = False

    def line(text, *, size=10, bold=False, italic=False, color="222222", space_before=0):
        nonlocal row
        row += space_before
        cell = ws.cell(row=row, column=2, value=text)
        cell.font = Font(name=FONT, size=size, bold=bold, italic=italic, color=color)
        cell.alignment = Alignment(vertical="top", wrap_text=True)
        if size >= 14:
            ws.row_dimensions[row].height = 24
        elif len(text) > 100:
            ws.row_dimensions[row].height = 15 * (len(text) // 100 + 1)
        row += 1

    row = 2
    line("Lakbayan — content intake workbook", size=16, bold=True, color="1F4E3D")
    line(
        "For the Provincial Tourism Office / DOT Region II. One sheet per kind of thing the app holds.",
        italic=True, color="555555",
    )

    line("How to fill this in", size=12, bold=True, color="1F4E3D", space_before=1)
    for t in [
        "Row 1 of each sheet is a note. Row 2 is the headers. Your data starts on row 3.",
        "Each sheet has one shaded EXAMPLE row showing the expected format. Delete it before sending back.",
        "A column marked * is required. Without it the row cannot be imported at all.",
        "Leave a cell blank if you do not know. Blank means “not known yet” — do not write N/A, none or TBA, "
        "because those import as literal text and appear in the app.",
        "Where a cell takes several values, separate them with semicolons: caves;river;hiking",
        "Green and grey dropdowns appear when you click a cell that has a fixed set of values.",
        "Add as many rows as you need. Validation and formatting run to row 302.",
    ]:
        line("•  " + t)

    line("The join key", size=12, bold=True, color="1F4E3D", space_before=1)
    line(
        "Give every destination a short code of your own in the ref column — PEN-001, TUG-004. The Audio guide, "
        "Tours and Photos sheets point at destinations by that code. It is not the app's internal id; it exists so "
        "the sheets can refer to each other before anything is imported. It only has to be unique and stable."
    )

    line("Colour key", size=12, bold=True, color="1F4E3D", space_before=1)
    for kind, label in [
        (REQ, "Required — the row cannot be imported without it"),
        (OPT, "Optional — fill in what you have"),
        (INT, "For our records — kept in this sheet, never shown in the app"),
    ]:
        swatch = ws.cell(row=row, column=1)
        swatch.fill = HEADER_FILL[kind]
        swatch.border = BORDER
        line(label)
    swatch = ws.cell(row=row, column=1)
    swatch.fill = EXAMPLE_FILL
    swatch.border = BORDER
    line("The EXAMPLE row — delete it")
    swatch = ws.cell(row=row, column=1)
    swatch.fill = OVERLONG_FILL
    swatch.border = BORDER
    line("Turns red when a short description runs past 140 characters")

    line("Three things we need to agree on", size=12, bold=True, color="1F4E3D", space_before=1)
    for n, t in enumerate([
        "Photos need permission, not just files. Every image needs someone able to say it may be published — "
        "the app is a public release. The licence or permission column on sheet 5 is required, and photos we "
        "cannot clear cannot ship. Who signs off on this?",
        "The guides sheet is personal data — names and phone numbers of real people. The app already requires a "
        "signed-in account to read that directory for this reason. Consent to publish must be yes per person "
        "before we list them. Does accreditation already capture that consent?",
        "What languages does the narration exist in? The app currently stores one narration per stop. If the "
        "province has Ilocano, Filipino and English scripts, that changes both the data model and the player, "
        "and it is far cheaper to know now than after the audio player is built. Record what exists in the "
        "language column on sheet 2.",
    ], start=1):
        line(f"{n}.  {t}")

    line("What we are not asking for", size=12, bold=True, color="1F4E3D", space_before=1)
    line(
        "Offline map packs are generated from the destination list, not collected. AR marker images are a stretch "
        "goal for one pilot exhibit — worth asking whether a museum is interested, not worth collecting yet. "
        "Slugs, ids and publication status are generated on import."
    )

    line("What happens next", size=12, bold=True, color="1F4E3D", space_before=1)
    line(
        "Everything imports as a draft. Nothing appears in the app until an administrator reviews it and presses "
        "Publish, so a half-finished or mistaken row is not a live mistake. A place cannot be published until it "
        "has a name, a town, a short description, coordinates and at least one photo — those five are the ones "
        "worth chasing first."
    )


if __name__ == "__main__":
    build()
