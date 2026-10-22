// What a re-import does to an audio guide.
//
//   cd scripts && node --test

import { strict as assert } from "node:assert";
import { describe, it } from "node:test";

import { planGuide, stopId } from "./guide.mjs";

describe("planGuide", () => {
  it("leaves a guide alone when the sheet has no stops for the place", () => {
    // Made in the CMS since the last import: random ids, recordings.
    assert.equal(planGuide(0, ["Xk2v9", "pQ7rt"]), null);
    assert.equal(planGuide(0, []), null);
  });

  it("writes the sheet's stops in order when it has some", () => {
    assert.deepEqual(planGuide(3, []), {
      write: ["stop-01", "stop-02", "stop-03"],
      remove: [],
    });
  });

  it("makes the sheet the whole guide for a place it lists", () => {
    // One fewer stop than last time, and one made in the CMS.
    assert.deepEqual(planGuide(2, ["stop-01", "stop-02", "stop-03", "Xk2v9"]), {
      write: ["stop-01", "stop-02"],
      remove: ["stop-03", "Xk2v9"],
    });
  });
});

describe("stopId", () => {
  it("is zero-padded, so ids sort in visiting order", () => {
    assert.equal(stopId(0), "stop-01");
    assert.equal(stopId(9), "stop-10");
  });
});
