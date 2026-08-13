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

// Fixtures share the emulator with the CMS and the app, so they are namespaced
// and deleted afterwards. An earlier version left `published-one` behind â€” a
// published document with no category or coords â€” which the app could not
// decode, and one bad row was enough to blank the whole Explore tab.
//
// `env.clearFirestore()` would be simpler and is wrong: it would wipe the
// content you just created in the CMS.
const FIXTURES = [
  "destinations/rulestest-published",
  "destinations/rulestest-draft",
  "users/rulestest-ana",
  // Deleted by the admin-delete case below; listed here so an early failure
  // does not leave a stray person in the CMS directory.
  "guides/rulestest-guide",
];

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-lakbayan",
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
    await setDoc(doc(db, "destinations/rulestest-published"), {
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
    await setDoc(doc(db, "destinations/rulestest-draft"), {
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
    await setDoc(doc(db, "destinations/rulestest-draft/segments/s1"), {
      title: "Unreleased narration",
      order: 1,
    });
    await setDoc(doc(db, "destinations/rulestest-published/segments/s1"), {
      title: "History",
      order: 1,
    });
    await setDoc(doc(db, "guides/rulestest-guide"), {
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
  // Remove the fixtures before tearing down, so a dev running `npm test`
  // does not find test rows in the CMS afterwards.
  await env?.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await deleteDoc(doc(db, "destinations/rulestest-draft/segments/s1"));
    // Written by the admin-write test rather than seeded, and just as much a
    // stray row in the CMS if it is left behind.
    await deleteDoc(doc(db, "destinations/rulestest-draft/segments/s2"));
    await deleteDoc(doc(db, "destinations/rulestest-published/segments/s1"));
    for (const path of FIXTURES) {
      await deleteDoc(doc(db, path));
    }
  });
  await env?.cleanup();
});

describe("destinations", () => {
  it("lets anyone read a published destination", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "destinations/rulestest-published")));
  });

  it("hides a draft destination from the public", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "destinations/rulestest-draft")));
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
      setDoc(doc(db, "destinations/rulestest-published"), { name: "Vandalised" })
    );
  });

  it("allows writes from an admin custom claim", async () => {
    const db = env
      .authenticatedContext("boss", { admin: true })
      .firestore();
    await assertSucceeds(
      setDoc(doc(db, "destinations/rulestest-published"), {
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
      getDoc(doc(db, "destinations/rulestest-published/segments/s1"))
    );
  });

  it("hides segments of a draft destination", async () => {
    // This was a real leak: the scaffold allowed `read: if true` here, so
    // unreleased narration scripts were world-readable.
    const db = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(db, "destinations/rulestest-draft/segments/s1"))
    );
  });

  it("refuses a segment write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "destinations/rulestest-published/segments/s1"), {
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
      setDoc(doc(db, "destinations/rulestest-draft/segments/s2"), {
        title: "The approach path",
        order: 2,
        ttsText: "Follow the boardwalk to your left.",
      })
    );
  });
});

describe("users", () => {
  it("lets a user read their own document", async () => {
    const db = env.authenticatedContext("rulestest-ana").firestore();
    await assertSucceeds(getDoc(doc(db, "users/rulestest-ana")));
  });

  it("stops a user reading someone else's document", async () => {
    const db = env.authenticatedContext("rulestest-ana").firestore();
    await assertFails(getDoc(doc(db, "users/rulestest-ben")));
  });

  it("refuses a client-written role field", async () => {
    // Admin is a custom claim. A client that can grant itself `role: admin`
    // would defeat every isAdmin() check in the file.
    const db = env.authenticatedContext("rulestest-ana").firestore();
    await assertFails(
      setDoc(doc(db, "users/rulestest-ana"), { uid: "rulestest-ana", role: "admin" })
    );
  });

  it("allows a normal profile create", async () => {
    const db = env.authenticatedContext("rulestest-ana").firestore();
    await assertSucceeds(
      setDoc(doc(db, "users/rulestest-ana"), {
        uid: "rulestest-ana",
        email: "ana@example.com",
        savedTourIds: [],
        downloadedTownIds: [],
      })
    );
  });
});

describe("guides", () => {
  it("requires sign-in, since rows carry personal contact details", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "guides/g1")));
  });

  it("lets any signed-in user read the directory", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertSucceeds(getDoc(doc(db, "guides/rulestest-guide")));
  });

  // The CMS directory is admin-only for writes. Worth its own case because
  // guides are the one collection an ordinary signed-in user *can* read, which
  // makes it the easiest place to assume they can write too.
  it("refuses a write from a signed-in non-admin", async () => {
    const db = env.authenticatedContext("traveller").firestore();
    await assertFails(
      setDoc(doc(db, "guides/rulestest-guide"), {
        name: "Impersonated Guide",
        town: "Piat",
        contact: "0917-000-0000",
      })
    );
  });

  it("allows an admin to write and to delete", async () => {
    const db = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertSucceeds(
      setDoc(doc(db, "guides/rulestest-guide"), {
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
    await assertSucceeds(deleteDoc(doc(db, "guides/rulestest-guide")));
  });
});

