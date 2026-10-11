import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase/firestore";
import type { OfflineBundle } from "./bundle";
import {
  bundlesNeedingWork,
  draftsNeedingWork,
  recentActivity,
  relativeTime,
  toursNeedingWork,
} from "./dashboard";
import { emptyDestination, type Destination } from "./destination";
import type { Guide } from "./guide";
import type { Tour } from "./tour";

const at = (millis: number) => Timestamp.fromMillis(millis);

/** A destination that passes every document-level publishing check. */
function place(id: string, over: Partial<Destination> = {}): Destination {
  return {
    ...emptyDestination(),
    id,
    name: `Place ${id}`,
    slug: `place-${id}`,
    town: "Peñablanca",
    description: "A short description.",
    images: [`destinations/${id}/images/1.jpg`],
    status: "published",
    createdAt: at(1_000),
    updatedAt: at(1_000),
    ...over,
  };
}

function tour(id: string, stops: string[], over: Partial<Tour> = {}): Tour {
  return {
    id,
    title: `Tour ${id}`,
    stops,
    featured: false,
    createdAt: at(1_000),
    updatedAt: at(1_000),
    ...over,
  };
}

function guide(id: string, over: Partial<Guide> = {}): Guide {
  return {
    id,
    name: `Guide ${id}`,
    town: "Peñablanca",
    specialties: [],
    contact: "0900 000 0000",
    verified: false,
    featured: false,
    createdAt: at(1_000),
    updatedAt: at(1_000),
    ...over,
  };
}

function bundle(name: string, over: Partial<OfflineBundle> = {}): OfflineBundle {
  return {
    townId: name.toLowerCase(),
    name,
    destinationIds: [],
    tilePackRef: `tiles/${name.toLowerCase()}/pack.pmtiles`,
    size: 0,
    version: "abc",
    status: "ready",
    generatedAt: at(5_000),
    ...over,
  };
}

const bundles = (...list: OfflineBundle[]) =>
  new Map(list.map((b) => [b.townId, b]));

describe("recentActivity", () => {
  it("merges the three collections, newest first", () => {
    const list = recentActivity({
      destinations: [place("a", { updatedAt: at(3_000) })],
      tours: [tour("t", [], { updatedAt: at(4_000) })],
      guides: [guide("g", { updatedAt: at(2_000) })],
    });
    expect(list.map((a) => a.kind)).toEqual(["tour", "destination", "guide"]);
  });

  it("calls an untouched document added and a rewritten one edited", () => {
    const [edited, added] = recentActivity({
      destinations: [
        place("new"),
        place("old", { createdAt: at(1_000), updatedAt: at(9_000) }),
      ],
      tours: [],
      guides: [],
    });
    expect(edited.verb).toBe("Edited");
    expect(added.verb).toBe("Added");
  });

  it("links each row to the item's editor, not just its section", () => {
    const list = recentActivity({
      destinations: [place("d", { updatedAt: at(3_000) })],
      tours: [tour("callao & caves", [], { updatedAt: at(2_000) })],
      guides: [guide("g1")],
    });
    expect(list.map((a) => a.href)).toEqual([
      "/destinations/d",
      "/tours?edit=callao%20%26%20caves",
      "/guides?edit=g1",
    ]);
  });

  it("carries the editor and status for destinations only", () => {
    const [d, t] = recentActivity({
      destinations: [
        place("d", { updatedAt: at(3_000), updatedBy: "uid-1", status: "draft" }),
      ],
      tours: [tour("t", [])],
      guides: [],
    });
    expect(d).toMatchObject({ by: "uid-1", status: "draft" });
    expect(t.by).toBeUndefined();
    expect(t.status).toBeUndefined();
  });

  it("leaves out rows it cannot date, and stops at the limit", () => {
    const list = recentActivity(
      {
        destinations: [
          place("undated", { updatedAt: undefined }),
          ...["a", "b", "c"].map((id, i) => place(id, { updatedAt: at(i + 2) })),
        ],
        tours: [],
        guides: [],
      },
      2,
    );
    expect(list.map((a) => a.id)).toEqual(["c", "b"]);
  });

  it("names an untitled draft rather than showing a blank row", () => {
    const [a] = recentActivity({
      destinations: [place("x", { name: "  " })],
      tours: [],
      guides: [],
    });
    expect(a.name).toBe("Untitled destination");
  });
});

describe("draftsNeedingWork", () => {
  it("ignores published destinations", () => {
    expect(draftsNeedingWork([place("p")])).toEqual([]);
  });

  it("says what a draft is missing, in the checklist's words", () => {
    const [item] = draftsNeedingWork([
      place("d", { status: "draft", images: [], description: "" }),
    ]);
    expect(item.ready).toBe(false);
    expect(item.detail).toBe(
      "Before it can go live: description, at least one photo.",
    );
  });

  it("puts drafts with nothing missing first, then the most recent", () => {
    const list = draftsNeedingWork([
      place("gap-new", { status: "draft", images: [], updatedAt: at(9_000) }),
      place("ready-old", { status: "draft", updatedAt: at(2_000) }),
      place("gap-old", { status: "draft", images: [], updatedAt: at(3_000) }),
      place("ready-new", { status: "draft", updatedAt: at(8_000) }),
    ]);
    expect(list.map((i) => i.key)).toEqual([
      "draft:ready-new",
      "draft:ready-old",
      "draft:gap-new",
      "draft:gap-old",
    ]);
    expect(list[0].detail).toBe("Ready to review and publish.");
  });
});

describe("bundlesNeedingWork", () => {
  it("flags a town with publishable places and no bundle", () => {
    const [item] = bundlesNeedingWork([place("a"), place("b")], new Map());
    expect(item.title).toBe("Peñablanca");
    expect(item.detail).toContain("2 places");
  });

  it("is quiet when the bundle matches the content and is ready", () => {
    expect(
      bundlesNeedingWork(
        [place("a"), place("b")],
        bundles(bundle("Peñablanca", { destinationIds: ["b", "a"] })),
      ),
    ).toEqual([]);
  });

  it("counts only published, offline-eligible places with a town", () => {
    // None of these belong in a bundle, so the one built from "a" is current.
    const list = bundlesNeedingWork(
      [
        place("a"),
        place("draft", { status: "draft" }),
        place("opted-out", { offlineEligible: false }),
        place("nowhere", { town: " " }),
      ],
      bundles(bundle("Peñablanca", { destinationIds: ["a"] })),
    );
    expect(list).toEqual([]);
  });

  it("flags a bundle when a place was edited after it was built", () => {
    const [item] = bundlesNeedingWork(
      [place("a", { updatedAt: at(6_000) })],
      bundles(bundle("Peñablanca", { destinationIds: ["a"] })),
    );
    expect(item.detail).toMatch(/^Changed since/);
  });

  it("flags a bundle when a place was added or removed", () => {
    const added = bundlesNeedingWork(
      [place("a"), place("b")],
      bundles(bundle("Peñablanca", { destinationIds: ["a"] })),
    );
    const removed = bundlesNeedingWork(
      [place("a")],
      bundles(bundle("Peñablanca", { destinationIds: ["a", "gone"] })),
    );
    expect(added).toHaveLength(1);
    expect(removed).toHaveLength(1);
  });

  it("still lists a bundle whose town has nothing publishable left", () => {
    const [item] = bundlesNeedingWork(
      [place("a", { status: "draft" })],
      bundles(bundle("Peñablanca", { destinationIds: ["a"] })),
    );
    expect(item.detail).toMatch(/^Changed since/);
  });

  it("reports a pending bundle that is otherwise current", () => {
    const [item] = bundlesNeedingWork(
      [place("a")],
      bundles(
        bundle("Peñablanca", { destinationIds: ["a"], status: "pending" }),
      ),
    );
    expect(item.detail).toMatch(/^Bundle incomplete/);
  });

  it("matches a bundle to its town by display name, as the function writes it", () => {
    const list = bundlesNeedingWork(
      [place("a", { town: "Santa Ana" })],
      bundles(bundle("Santa Ana", { townId: "santa-ana", destinationIds: ["a"] })),
    );
    expect(list).toEqual([]);
  });
});

describe("toursNeedingWork", () => {
  it("is quiet when every stop is published", () => {
    expect(toursNeedingWork([tour("t", ["a", "b"])], [place("a"), place("b")]))
      .toEqual([]);
  });

  it("counts unpublished and deleted stops separately", () => {
    const [item] = toursNeedingWork(
      [tour("t", ["a", "b", "gone"])],
      [place("a"), place("b", { status: "draft" })],
    );
    expect(item.detail).toBe(
      "2 of 3 stops hidden from visitors (1 unpublished, 1 deleted).",
    );
    expect(item.href).toBe("/tours?edit=t");
  });
});

describe("relativeTime", () => {
  const now = Date.UTC(2026, 9, 5, 12, 0, 0);

  it("reads recent writes as relative phrases", () => {
    expect(relativeTime(now - 10_000, now)).toBe("just now");
    expect(relativeTime(now - 5 * 60_000, now)).toBe("5 minutes ago");
    expect(relativeTime(now - 3 * 3_600_000, now)).toBe("3 hours ago");
    expect(relativeTime(now - 26 * 3_600_000, now)).toBe("yesterday");
  });

  it("switches to a date after a week, with the year only when it differs", () => {
    expect(relativeTime(Date.UTC(2026, 8, 1, 12), now)).toBe("1 Sep");
    expect(relativeTime(Date.UTC(2025, 8, 1, 12), now)).toBe("1 Sep 2025");
  });
});
