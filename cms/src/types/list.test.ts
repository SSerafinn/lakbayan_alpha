import { describe, expect, it } from "vitest";
import { emptyDestination, type Destination } from "./destination";
import {
  NO_FILTERS,
  applyFilters,
  bulkStatusMessage,
  planBulkStatus,
  readFilters,
  selectionState,
  toggleAll,
  writeFilters,
} from "./list";

/** A place with everything the readiness list asks for. */
function place(id: string, over: Partial<Destination> = {}): Destination {
  return {
    ...emptyDestination(),
    id,
    name: id,
    slug: id,
    town: "Peñablanca",
    description: "A place.",
    coords: { lat: 17.7, lng: 121.8 },
    images: [`destinations/${id}/images/1.jpg`],
    ...over,
  };
}

describe("the list's filters in its address", () => {
  it("reads a plain address as no filter at all", () => {
    expect(readFilters(new URLSearchParams(""))).toEqual(NO_FILTERS);
  });

  it("round-trips every filter", () => {
    const filters = {
      view: "no-photo" as const,
      search: "cave",
      town: "Peñablanca",
      category: "nature" as const,
    };
    expect(readFilters(writeFilters(filters))).toEqual(filters);
  });

  it("writes only what is set, so a plain list keeps a plain URL", () => {
    expect(writeFilters(NO_FILTERS).toString()).toBe("");
    expect(writeFilters({ ...NO_FILTERS, view: "draft" }).toString()).toBe(
      "view=draft",
    );
  });

  it("shows everything for a view or category it does not know", () => {
    // An old or mistyped link is a full table, never an empty one.
    const got = readFilters(new URLSearchParams("view=archived&category=beach"));
    expect(got.view).toBe("all");
    expect(got.category).toBe("all");
  });
});

describe("applyFilters", () => {
  const rows = [
    place("callao-cave", { name: "Callao Cave", status: "published" }),
    place("palaui", { name: "Palaui Island", town: "Santa Ana", images: [] }),
    place("basilica", { name: "Basilica", town: "Piat", category: "church" }),
  ];
  const names = (f: Parameters<typeof applyFilters>[1]) =>
    applyFilters(rows, f).map((r) => r.name);

  it("searches the name and the town, whatever the case", () => {
    expect(names({ ...NO_FILTERS, search: "  CAVE " })).toEqual(["Callao Cave"]);
    expect(names({ ...NO_FILTERS, search: "santa" })).toEqual(["Palaui Island"]);
  });

  it("narrows by view, town and category together", () => {
    expect(names({ ...NO_FILTERS, view: "no-photo" })).toEqual(["Palaui Island"]);
    expect(names({ ...NO_FILTERS, view: "published" })).toEqual(["Callao Cave"]);
    expect(names({ ...NO_FILTERS, category: "church", town: "Piat" })).toEqual([
      "Basilica",
    ]);
    expect(names({ ...NO_FILTERS, category: "church", town: "Santa Ana" })).toEqual(
      [],
    );
  });
});

describe("the header checkbox", () => {
  it("says none, some or all of what is on screen", () => {
    expect(selectionState(["a", "b"], new Set())).toBe("none");
    expect(selectionState(["a", "b"], new Set(["a"]))).toBe("some");
    expect(selectionState(["a", "b"], new Set(["a", "b", "hidden"]))).toBe("all");
    expect(selectionState([], new Set(["hidden"]))).toBe("none");
  });

  it("ticks every row on screen, then clears them", () => {
    const all = toggleAll(["a", "b"], new Set(["a"]));
    expect([...all].sort()).toEqual(["a", "b"]);
    expect([...toggleAll(["a", "b"], all)]).toEqual([]);
  });

  it("leaves rows a filter is hiding as they were", () => {
    expect([...toggleAll(["a"], new Set(["a", "hidden"]))]).toEqual(["hidden"]);
  });
});

describe("planBulkStatus", () => {
  it("changes only the ticked places that are not already there", () => {
    const rows = [
      place("a", { status: "draft" }),
      place("b", { status: "published" }),
      place("c", { status: "draft" }),
    ];
    expect(planBulkStatus(rows, new Set(["a", "b"]), "published")).toEqual({
      change: [{ id: "a", from: "draft" }],
      blocked: [],
    });
  });

  it("will not publish a place the editor would refuse to", () => {
    // The list used to write the status straight through, so a place with
    // no photo could go live from here and not from its own page.
    const rows = [place("ready"), place("bare", { name: "Bare", images: [] })];
    expect(planBulkStatus(rows, new Set(["ready", "bare"]), "published")).toEqual({
      change: [{ id: "ready", from: "draft" }],
      blocked: [{ id: "bare", name: "Bare", missing: ["At least one photo"] }],
    });
  });

  it("counts an audio guide stop that cannot be played against publishing", () => {
    const rows = [place("guided")];
    const stop = { id: "s1", title: "" };
    const plan = planBulkStatus(
      rows,
      new Set(["guided"]),
      "published",
      new Map([["guided", { segments: [stop], exhibits: [] }]]),
    );
    expect(plan.change).toEqual([]);
    expect(plan.blocked[0].missing).toContain("Every stop is named");
  });

  it("unpublishes without asking whether a place is complete", () => {
    const rows = [place("bare", { images: [], status: "published" })];
    expect(planBulkStatus(rows, new Set(["bare"]), "draft")).toEqual({
      change: [{ id: "bare", from: "published" }],
      blocked: [],
    });
  });
});

describe("bulkStatusMessage", () => {
  it("counts what changed", () => {
    expect(
      bulkStatusMessage(
        { change: [{ id: "a", from: "draft" }, { id: "b", from: "draft" }], blocked: [] },
        "published",
      ),
    ).toEqual({ title: "2 places published" });
    expect(
      bulkStatusMessage({ change: [{ id: "a", from: "published" }], blocked: [] }, "draft"),
    ).toEqual({ title: "1 place unpublished" });
  });

  it("names a place it left alone, and what it is missing", () => {
    expect(
      bulkStatusMessage(
        {
          change: [{ id: "a", from: "draft" }],
          blocked: [
            { id: "b", name: "Palaui Island", missing: ["Location", "At least one photo"] },
            { id: "c", name: "Bare", missing: ["Town"] },
            { id: "d", name: "Barer", missing: ["Town"] },
          ],
        },
        "published",
      ),
    ).toEqual({
      title: "1 place published",
      description:
        "Palaui Island is not ready: location, at least one photo. So are 2 others.",
    });
  });

  it("says so when nothing could be published", () => {
    expect(
      bulkStatusMessage(
        { change: [], blocked: [{ id: "b", name: "Bare", missing: ["Town"] }] },
        "published",
      ).title,
    ).toBe("Nothing was published");
  });

  it("says so when everything ticked was already there", () => {
    expect(bulkStatusMessage({ change: [], blocked: [] }, "draft").title).toBe(
      "Already unpublished",
    );
  });
});
