// Security rules tests.
//
// firestore.rules is code, and these are the cases that are easy to get wrong
// and expensive to get wrong. Run against the emulator:
//
//   docker compose up -d emulators
//   cd test_rules && npm install && npm test
//
// Rules are evaluated by the emulator, not by Dart, which is why this lives
// outside the Flutter test suite.

import { after, before, describe, it } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import {
  doc,
  deleteDoc,
  getDoc,
  setDoc,
  collection,
  getDocs,
  query,
  where,
} from "firebase/firestore";

let env;

// A project of its own, separate from the `demo-lakbayan` the CMS and app use.
//
// The emulator serves any number of project ids at once, and this one costs
// nothing — but it is what makes the suite safe to run at any moment. Sharing
// a project meant fixtures had to be prefixed to avoid colliding with real
// content, deleted one path at a time afterwards, and `clearFirestore()` was
// off limits because it would have wiped whatever you had just entered in the
// CMS. An earlier version left a malformed `published-one` document behind,
// and one bad row was enough to blank the whole Explore tab.
//
// None of that applies to a database nothing else writes to.
const PROJECT_ID = "demo-lakbayan-rules";

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });

  // Seed through a context that bypasses rules, so the fixtures themselves
  // are not a test of the rules.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    // Complete documents, matching docs/DATA_MODEL.md. Partial fixtures used to
    // be enough for rules, but they are read by the app too â€” and the app is
    // entitled to assume a published document is well-formed.
    await setDoc(doc(db, "destinations/published"), {
      name: "Rules Test â€” Published",
      slug: "rules-test-published",
      town: "PeÃ±ablanca",
      category: "nature",
      description: "Fixture for the security rules tests.",
      coords: { lat: 17.7, lng: 121.8 },
      images: [],
      status: "published",
      schemaVersion: 2,
    });
    await setDoc(doc(db, "destinations/draft"), {
      name: "Rules Test â€” Draft",
      slug: "rules-test-draft",
      town: "Gattaran",
      category: "heritage",
      description: "Fixture for the security rules tests.",
      coords: { lat: 18.1, lng: 121.6 },
      images: [],
      status: "draft",
      schemaVersion: 2,
    });
    await setDoc(doc(db, "destinations/draft/segments/s1"), {
      title: "Unreleased narration",
      order: 1,
    });
    await setDoc(doc(db, "destinations/published/segments/s1"), {
      title: "History",
      order: 1,
    });
    await setDoc(doc(db, "tours/tour"), {
      title: "Rules Test — Tour",
      description: "Fixture for the security rules tests.",
      stops: ["published"],
      featured: false,
    });
    await setDoc(doc(db, "guides/guide"), {
      name: "Rules Test — Guide",
      town: "Peñablanca",
      specialties: ["caving"],
      contact: "0917-000-0000",
      verified: true,
      featured: false,
    });
  });
});

after(async () => {
  // One call instead of a hand-maintained list of paths. Every previous
  // addition to this suite had to remember to add its documents here, and the
  // guides case wrote one the seed never created — exactly the kind of thing
  // that gets forgotten.
  await env?.clearFirestore();
  await env?.cleanup();
});

describe("destinations", () => {
  it("lets anyone read a published destination", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "destinations/published")));
  });

  it("hides a draft destination from the public", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "destinations/draft")));
  });

  it("allows a query constrained to published documents", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(
      getDocs(
        query(collection(db, "destinations"), where("status", "==", "published"))
      )
    );
  });

  it("denies an unfiltered collection query", async () => {
    // The failure mode worth pinning down: rules gate reads on status, so an
    // unfiltered query is denied wholesale rather than returning a subset.
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDocs(collection(db, "destinations")));
  });

  it("refuses writes from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "destinations/published"), { name: "Vandalised" })
    );
  });

  it("allows writes from an admin custom claim", async () => {
    const db = env
      .authenticatedContext("boss", { admin: true })
      .firestore();
    await assertSucceeds(
      setDoc(doc(db, "destinations/published"), {
        name: "Callao Cave",
        status: "published",
      })
    );
  });
});

describe("segments inherit the parent's visibility", () => {
  it("exposes segments of a published destination", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(
      getDoc(doc(db, "destinations/published/segments/s1"))
    );
  });

  it("hides segments of a draft destination", async () => {
    // This was a real leak: the scaffold allowed `read: if true` here, so
    // unreleased narration scripts were world-readable.
    const db = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(db, "destinations/draft/segments/s1"))
    );
  });

  it("refuses a segment write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "destinations/published/segments/s1"), {
        title: "Vandalised narration",
        order: 1,
      })
    );
  });

  // The path the CMS audio guide editor actually takes: a guide is written
  // while its destination is still a draft, long before either goes live.
  it("allows an admin to write a segment under a draft destination", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "destinations/draft/segments/s2"), {
        title: "The approach path",
        order: 2,
        ttsText: "Follow the boardwalk to your left.",
      })
    );
  });
});

describe("users", () => {
  it("lets a user read their own document", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertSucceeds(getDoc(doc(db, "users/ana")));
  });

  it("stops a user reading someone else's document", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertFails(getDoc(doc(db, "users/ben")));
  });

  it("stops a non-admin listing the collection", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertFails(getDocs(collection(db, "users")));
  });

  // The CMS Users screen. Read-only: the next test pins that an admin still
  // cannot write someone else's profile.
  it("lets an admin read and list other users", async () => {
    const db = env
      .authenticatedContext("staff", { admin: true })
      .firestore();
    await assertSucceeds(getDoc(doc(db, "users/ben")));
    await assertSucceeds(getDocs(collection(db, "users")));
  });

  it("stops an admin writing someone else's profile", async () => {
    const db = env
      .authenticatedContext("staff", { admin: true })
      .firestore();
    await assertFails(
      setDoc(doc(db, "users/ben"), { uid: "ben", savedTourIds: [] })
    );
  });

  it("refuses a client-written role field", async () => {
    // Admin is a custom claim. A client that can grant itself `role: admin`
    // would defeat every isAdmin() check in the file.
    const db = env.authenticatedContext("ana").firestore();
    await assertFails(
      setDoc(doc(db, "users/ana"), { uid: "ana", role: "admin" })
    );
  });

  it("allows a normal profile create", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertSucceeds(
      setDoc(doc(db, "users/ana"), {
        uid: "ana",
        email: "ana@example.com",
        savedTourIds: [],
        downloadedTownIds: [],
      })
    );
  });
});

describe("tours", () => {
  // Unlike destinations, a tour has no status: it is catalog data and is
  // public from the moment it exists. Pinned here because that is a surprising
  // asymmetry, and anyone adding a draft state has to change this test first.
  it("is readable by anyone, signed in or not", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "tours/tour")));
  });

  it("refuses a write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "tours/tour"), { title: "Vandalised", stops: [] })
    );
  });

  it("allows an admin to write and to delete", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "tours/tour"), {
        title: "Peñablanca in a day",
        description: "Cave in the morning, river in the afternoon.",
        stops: ["published"],
        featured: true,
      })
    );
    await assertSucceeds(deleteDoc(doc(db, "tours/tour")));
  });
});

describe("settings", () => {
  it("is readable by anyone, signed in or not", async () => {
    // The privacy policy has to be reachable before sign-in.
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "settings/policies")));
  });

  it("refuses a write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "settings/app"), {
        hotlines: [{ label: "Fake", number: "0900 000 0000" }],
      })
    );
  });

  it("allows an admin to write each of the three documents", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "settings/taxonomy"), { towns: ["Peñablanca"] })
    );
    await assertSucceeds(setDoc(doc(db, "settings/app"), { hotlines: [] }));
    await assertSucceeds(
      setDoc(doc(db, "settings/policies"), { privacy: "", terms: "" })
    );
  });

  it("refuses an admin write to any other id", async () => {
    // A typo in a path must fail rather than quietly create a settings
    // document that nothing reads.
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertFails(setDoc(doc(db, "settings/polices"), { privacy: "" }));
  });
});

describe("itineraries", () => {
  // A subcollection does NOT inherit its parent's rules. Without an explicit
  // match these would be denied outright — safe, but not what we want — and
  // with a careless one they would be readable by anybody. Both directions are
  // worth pinning.
  const mine = "users/ana/itineraries/weekend";
  const theirs = "users/ben/itineraries/weekend";

  it("lets the owner create, read and delete their own", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertSucceeds(
      setDoc(doc(db, mine), {
        name: "Two days in Peñablanca",
        destinationIds: ["published"],
      })
    );
    await assertSucceeds(getDoc(doc(db, mine)));
    await assertSucceeds(getDocs(collection(db, "users/ana/itineraries")));
    await assertSucceeds(deleteDoc(doc(db, mine)));
  });

  it("hides one person's plans from another", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertFails(getDoc(doc(db, theirs)));
    await assertFails(setDoc(doc(db, theirs), { name: "Vandalised" }));
    await assertFails(getDocs(collection(db, "users/ben/itineraries")));
  });

  it("hides them from an admin too", async () => {
    // Deliberately unlike `users/{uid}` itself, which admins can read for the
    // CMS Users screen. An itinerary is a private plan; the province has no
    // business knowing what somebody is doing on Saturday.
    const db = env.authenticatedContext("staff", { admin: true }).firestore();
    await assertFails(getDoc(doc(db, mine)));
    await assertFails(getDocs(collection(db, "users/ana/itineraries")));
  });

  it("refuses an anonymous reader", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, mine)));
  });
});

describe("offlineBundles", () => {
  // A phone reads the manifest before it has an account — wireframe 1b keeps
  // discovery open to guests, and downloading a town is discovery.
  it("is readable by anyone, signed in or not", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "offlineBundles/penablanca")));
  });

  it("refuses a write from a signed-in non-admin", async () => {
    // The document says how big a download is and whether it is ready. A
    // client that could write it could point every phone at anything.
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "offlineBundles/penablanca"), {
        name: "Peñablanca",
        status: "ready",
      })
    );
  });

  it("allows an admin to write", async () => {
    // In practice only the generateOfflineBundle function writes these, and it
    // uses the Admin SDK, which bypasses rules entirely. The rule still has to
    // be right: it is what stops anyone else.
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "offlineBundles/penablanca"), {
        name: "Peñablanca",
        destinationIds: ["published"],
        tilePackRef: "tiles/penablanca/pack.pmtiles",
        size: 1574547,
        version: "7daa20e51fe1",
        status: "ready",
      })
    );
  });
});

describe("guides", () => {
  it("requires sign-in, since rows carry personal contact details", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "guides/guide")));
  });

  it("lets any signed-in user read the directory", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertSucceeds(getDoc(doc(db, "guides/guide")));
  });

  // The CMS directory is admin-only for writes. Worth its own case because
  // guides are the one collection an ordinary signed-in user *can* read, which
  // makes it the easiest place to assume they can write too.
  it("refuses a write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "guides/guide"), {
        name: "Impersonated Guide",
        town: "Piat",
        contact: "0917-000-0000",
      })
    );
  });

  it("allows an admin to write and to delete", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "guides/guide"), {
        name: "Maria Santos",
        town: "Peñablanca",
        specialties: ["caving"],
        contact: "0917-000-0000",
        verified: true,
        featured: false,
      })
    );
    // Removal is how a withdrawn consent is honoured — there is no unpublish
    // for this collection, so an admin must be able to delete outright.
    await assertSucceeds(deleteDoc(doc(db, "guides/guide")));
  });
});

