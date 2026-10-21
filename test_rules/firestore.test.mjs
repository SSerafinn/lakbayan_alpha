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
  updateDoc,
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
    // be enough for rules, but they are read by the app too — and the app is
    // entitled to assume a published document is well-formed.
    await setDoc(doc(db, "destinations/published"), {
      name: "Rules Test — Published",
      slug: "rules-test-published",
      town: "Peñablanca",
      category: "nature",
      description: "Fixture for the security rules tests.",
      coords: { lat: 17.7, lng: 121.8 },
      images: [],
      status: "published",
      schemaVersion: 2,
    });
    await setDoc(doc(db, "destinations/draft"), {
      name: "Rules Test — Draft",
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
    await setDoc(doc(db, "destinations/published/exhibits/e1"), {
      title: "The church bell",
      markerPath: "ar/published/markers/e1.jpg",
      markerWidthM: 0.3,
      order: 1,
    });
    await setDoc(doc(db, "destinations/draft/exhibits/e1"), {
      title: "Unreleased exhibit",
      markerPath: "ar/draft/markers/e1.jpg",
      markerWidthM: 0.3,
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

  // The CMS lists every destination and checks a new slug against all of
  // them, drafts included (cms/src/lib/destinations.ts), so the status filter
  // the public needs must not bind an admin.
  it("lets an admin read a draft, and query without the status filter", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(getDoc(doc(db, "destinations/draft")));
    await assertSucceeds(getDocs(collection(db, "destinations")));
    await assertSucceeds(
      getDocs(
        query(
          collection(db, "destinations"),
          where("slug", "==", "rules-test-draft")
        )
      )
    );
  });

  it("refuses writes from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "destinations/published"), { name: "Vandalised" })
    );
  });

  // Overwriting an existing document is an update; a new id is a create.
  // `allow write` covers both, but a rule split later into create and update
  // could leave one of them open, so each gets its own case.
  it("refuses a new destination from anyone but an admin", async () => {
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    const fake = {
      name: "Not a real place",
      town: "Aparri",
      category: "landmark",
      status: "published",
    };
    await assertFails(setDoc(doc(user, "destinations/fake"), fake));
    await assertFails(setDoc(doc(guest, "destinations/fake"), fake));
  });

  it("refuses a delete from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(deleteDoc(doc(db, "destinations/published")));
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

  it("allows an admin to create a destination and to delete it", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "destinations/retired"), {
        name: "Rules Test — Retired",
        town: "Tuguegarao",
        category: "landmark",
        status: "draft",
      })
    );
    await assertSucceeds(deleteDoc(doc(db, "destinations/retired")));
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

  // How the app actually loads an audio guide: the whole subcollection at
  // once. The rule reads the parent rather than each segment, so a list is
  // allowed or denied as a unit.
  it("lists a published destination's segments, not a draft's", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(
      getDocs(collection(db, "destinations/published/segments"))
    );
    await assertFails(getDocs(collection(db, "destinations/draft/segments")));
  });

  // The CMS audio guide editor reads back what it wrote while the destination
  // is still a draft.
  it("lets an admin read and list a draft's segments", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(getDoc(doc(db, "destinations/draft/segments/s1")));
    await assertSucceeds(getDocs(collection(db, "destinations/draft/segments")));
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

  // The editor deletes a segment taken out of the list, and deleting a
  // destination deletes its segments first, since Firestore does not cascade
  // (cms/src/lib/segments.ts).
  it("lets an admin delete a segment, and nobody else", async () => {
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    const admin = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertFails(deleteDoc(doc(user, "destinations/published/segments/s1")));
    await assertFails(deleteDoc(doc(guest, "destinations/published/segments/s1")));
    await assertSucceeds(deleteDoc(doc(admin, "destinations/draft/segments/s2")));
  });
});

describe("AR exhibits inherit the parent's visibility", () => {
  // The same contract as segments (D-18): what the app's scanner downloads
  // for a published museum is public, an unpublished one's is not.
  it("exposes a published destination's exhibits, alone and as a list", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "destinations/published/exhibits/e1")));
    await assertSucceeds(
      getDocs(collection(db, "destinations/published/exhibits"))
    );
  });

  it("hides a draft destination's exhibits", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "destinations/draft/exhibits/e1")));
    await assertFails(getDocs(collection(db, "destinations/draft/exhibits")));
  });

  it("lets an admin read a draft's exhibits and write one", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(getDocs(collection(db, "destinations/draft/exhibits")));
    await assertSucceeds(
      setDoc(doc(db, "destinations/draft/exhibits/e2"), {
        title: "The founding stone",
        markerPath: "ar/draft/markers/e2.jpg",
        markerWidthM: 0.4,
        order: 2,
      })
    );
  });

  it("refuses an exhibit write or delete from anyone but an admin", async () => {
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(user, "destinations/published/exhibits/e1"), {
        title: "Vandalised",
        markerPath: "ar/published/markers/e1.jpg",
        markerWidthM: 0.3,
        order: 1,
      })
    );
    await assertFails(deleteDoc(doc(user, "destinations/published/exhibits/e1")));
    await assertFails(deleteDoc(doc(guest, "destinations/published/exhibits/e1")));
  });

  it("lets an admin delete an exhibit", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(deleteDoc(doc(db, "destinations/draft/exhibits/e2")));
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

  it("refuses an anonymous reader", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users/ana")));
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

  it("refuses a client-written role field when creating a profile", async () => {
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

  // The same check on the update path, now that users/ana exists. Create and
  // update are separate rules, so the case above says nothing about this one
  // — and an update is how a signed-in client would try it, since its
  // profile is written on first sign-in.
  it("refuses a role field added to an existing profile", async () => {
    const db = env.authenticatedContext("ana").firestore();
    // An ordinary edit goes through, so the refusals below are about `role`.
    await assertSucceeds(
      updateDoc(doc(db, "users/ana"), { displayName: "Ana" })
    );
    await assertFails(updateDoc(doc(db, "users/ana"), { role: "admin" }));
    // Any value: the rule forbids the field, not the word "admin".
    await assertFails(
      setDoc(doc(db, "users/ana"), { role: "tourist" }, { merge: true })
    );
  });

  it("stops anyone else editing or deleting an existing profile", async () => {
    const ben = env.authenticatedContext("ben").firestore();
    const guest = env.unauthenticatedContext().firestore();
    const staff = env.authenticatedContext("staff", { admin: true }).firestore();

    await assertFails(updateDoc(doc(ben, "users/ana"), { savedTourIds: [] }));
    await assertFails(deleteDoc(doc(ben, "users/ana")));
    await assertFails(updateDoc(doc(guest, "users/ana"), { savedTourIds: [] }));
    // Writes stay owner-only for admins too, deletes included.
    await assertFails(updateDoc(doc(staff, "users/ana"), { savedTourIds: [] }));
    await assertFails(deleteDoc(doc(staff, "users/ana")));
  });

  it("stops a user creating a profile under someone else's uid", async () => {
    const db = env.authenticatedContext("ben").firestore();
    await assertFails(
      setDoc(doc(db, "users/carla"), { uid: "carla", savedTourIds: [] })
    );
  });

  it("lets the owner delete their own profile", async () => {
    const db = env.authenticatedContext("ana").firestore();
    await assertSucceeds(deleteDoc(doc(db, "users/ana")));
  });
});

describe("tours", () => {
  // Unlike destinations, a tour has no status: it is catalog data and is
  // public from the moment it exists. Pinned here because that is a surprising
  // asymmetry, and anyone adding a draft state has to change this test first.
  it("is readable by anyone, signed in or not", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "tours/tour")));
    // And listable without a filter, for the same reason.
    await assertSucceeds(getDocs(collection(db, "tours")));
  });

  it("refuses a write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "tours/tour"), { title: "Vandalised", stops: [] })
    );
  });

  it("refuses an anonymous write, and a delete from anyone but an admin", async () => {
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(guest, "tours/tour"), { title: "Vandalised", stops: [] })
    );
    await assertFails(deleteDoc(doc(user, "tours/tour")));
    await assertFails(deleteDoc(doc(guest, "tours/tour")));
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

  it("refuses a write from an anonymous visitor", async () => {
    // Readable before sign-in is not writable before sign-in.
    const db = env.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, "settings/policies"), { privacy: "", terms: "" })
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

  // Only the refusals are pinned. `allow write` covers delete, so today an
  // admin can delete one of the three as well — settings/policies included,
  // and the app has to be able to read that before sign-in.
  // TODO(phase-5): decide this in the "Harden firestore.rules" pass (PLAN.md)
  // and pin the answer here; until then it is a gap, not the contract.
  it("refuses a delete from a non-admin", async () => {
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    await assertFails(deleteDoc(doc(user, "settings/app")));
    await assertFails(deleteDoc(doc(guest, "settings/policies")));
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

  it("refuses a write from an anonymous visitor", async () => {
    const db = env.unauthenticatedContext().firestore();
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

  it("lets an admin delete a manifest, and nobody else", async () => {
    // Deleting one takes a town out of every phone's download list, which is
    // as much a write as pointing it at the wrong pack.
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    const admin = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertFails(deleteDoc(doc(user, "offlineBundles/penablanca")));
    await assertFails(deleteDoc(doc(guest, "offlineBundles/penablanca")));
    await assertSucceeds(deleteDoc(doc(admin, "offlineBundles/penablanca")));
  });
});

describe("guides", () => {
  it("requires sign-in, since rows carry personal contact details", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "guides/guide")));
    // The list is what a scraper would ask for, so it matters more than the
    // single document.
    await assertFails(getDocs(collection(db, "guides")));
  });

  it("lets any signed-in user read the directory", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertSucceeds(getDoc(doc(db, "guides/guide")));
    await assertSucceeds(getDocs(collection(db, "guides")));
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

  it("refuses an anonymous write, and a delete from anyone but an admin", async () => {
    const user = env.authenticatedContext("traveller").firestore();
    const guest = env.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(guest, "guides/guide"), {
        name: "Impersonated Guide",
        town: "Piat",
        contact: "0917-000-0000",
      })
    );
    await assertFails(deleteDoc(doc(user, "guides/guide")));
    await assertFails(deleteDoc(doc(guest, "guides/guide")));
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

describe("the admin claim", () => {
  // isAdmin() compares the claim with `== true`, and the rules language does
  // not coerce: a claim stored as the string "true" or the number 1 — say by
  // a hand-run script instead of setAdminRole — grants nothing. Pinned so
  // that loosening the comparison is a decision, not a refactor.
  it("must be the boolean true, not a value that looks like it", async () => {
    for (const admin of ["true", 1]) {
      const db = env.authenticatedContext("pretender", { admin }).firestore();
      await assertFails(getDoc(doc(db, "destinations/draft")));
      await assertFails(
        setDoc(doc(db, "destinations/published"), { name: "Vandalised" })
      );
      await assertFails(getDocs(collection(db, "users")));
    }
  });
});

describe("everything else", () => {
  // No catch-all match, so a collection nobody wrote a rule for is closed
  // rather than open — including to admins, whose rights are granted path by
  // path.
  it("is closed, to admins too", async () => {
    const admin = env.authenticatedContext("boss", { admin: true }).firestore();
    const user = env.authenticatedContext("traveller").firestore();
    await assertFails(getDoc(doc(admin, "reports/weekly")));
    await assertFails(setDoc(doc(admin, "reports/weekly"), { visits: 0 }));
    await assertFails(getDocs(collection(user, "reports")));
  });

  it("closes an unmatched subcollection, even to the document's owner", async () => {
    // The flip side of the itineraries comment in firestore.rules: owning
    // users/ana grants nothing beneath it except what is matched explicitly.
    const db = env.authenticatedContext("ana").firestore();
    await assertFails(setDoc(doc(db, "users/ana/notes/n1"), { text: "" }));
    await assertFails(getDoc(doc(db, "users/ana/notes/n1")));
  });
});
