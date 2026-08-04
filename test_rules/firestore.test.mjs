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
  getDoc,
  setDoc,
  collection,
  getDocs,
  query,
  where,
} from "firebase/firestore";

let env;

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
    await setDoc(doc(db, "destinations/published-one"), {
      name: "Callao Cave",
      town: "Peñablanca",
      status: "published",
    });
    await setDoc(doc(db, "destinations/draft-one"), {
      name: "Unannounced Site",
      town: "Gattaran",
      status: "draft",
    });
    await setDoc(doc(db, "destinations/draft-one/segments/s1"), {
      title: "Unreleased narration",
      order: 1,
    });
    await setDoc(doc(db, "destinations/published-one/segments/s1"), {
      title: "History",
      order: 1,
    });
  });
});

after(async () => env?.cleanup());

describe("destinations", () => {
  it("lets anyone read a published destination", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "destinations/published-one")));
  });

  it("hides a draft destination from the public", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "destinations/draft-one")));
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
      setDoc(doc(db, "destinations/published-one"), { name: "Vandalised" })
    );
  });

  it("allows writes from an admin custom claim", async () => {
    const db = env
      .authenticatedContext("boss", { admin: true })
      .firestore();
    await assertSucceeds(
      setDoc(doc(db, "destinations/published-one"), {
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
      getDoc(doc(db, "destinations/published-one/segments/s1"))
    );
  });

  it("hides segments of a draft destination", async () => {
    // This was a real leak: the scaffold allowed `read: if true` here, so
    // unreleased narration scripts were world-readable.
    const db = env.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(db, "destinations/draft-one/segments/s1"))
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

describe("guides", () => {
  it("requires sign-in, since rows carry personal contact details", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "guides/g1")));
  });
});
