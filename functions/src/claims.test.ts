import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  assertNotSelfRevoke,
  parseSetAdminRequest,
  withAdmin,
} from "./claims.js";

describe("withAdmin", () => {
  it("grants on an account with no claims", () => {
    assert.deepEqual(withAdmin(undefined, true), { admin: true });
  });

  it("keeps unrelated claims when granting", () => {
    assert.deepEqual(withAdmin({ beta: true }, true), {
      beta: true,
      admin: true,
    });
  });

  it("removes only the admin claim when revoking", () => {
    assert.deepEqual(withAdmin({ beta: true, admin: true }, false), {
      beta: true,
    });
  });

  it("does not mutate the input", () => {
    const existing = { admin: true };
    withAdmin(existing, false);
    assert.deepEqual(existing, { admin: true });
  });
});

describe("parseSetAdminRequest", () => {
  it("normalises the email", () => {
    assert.deepEqual(
      parseSetAdminRequest({ email: "  Ana@Example.COM ", admin: true }),
      { email: "ana@example.com", admin: true },
    );
  });

  it("rejects a missing email", () => {
    assert.throws(() => parseSetAdminRequest({ admin: true }), /email/);
    assert.throws(
      () => parseSetAdminRequest({ email: "   ", admin: true }),
      /email/,
    );
  });

  it("rejects a non-boolean admin flag, including the string 'false'", () => {
    assert.throws(
      () => parseSetAdminRequest({ email: "a@b.c", admin: "false" }),
      /true or false/,
    );
    assert.throws(() => parseSetAdminRequest({ email: "a@b.c" }), /true or false/);
  });

  it("rejects a non-object payload", () => {
    assert.throws(() => parseSetAdminRequest(null), /Expected/);
    assert.throws(() => parseSetAdminRequest("a@b.c"), /Expected/);
  });
});

describe("assertNotSelfRevoke", () => {
  it("refuses to revoke the caller's own claim", () => {
    assert.throws(() => assertNotSelfRevoke("me", "me", false), /your own/);
  });

  it("allows the caller to re-grant themselves", () => {
    assert.doesNotThrow(() => assertNotSelfRevoke("me", "me", true));
  });

  it("allows revoking someone else", () => {
    assert.doesNotThrow(() => assertNotSelfRevoke("me", "them", false));
  });
});
