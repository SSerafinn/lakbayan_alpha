import { describe, expect, it } from "vitest";
import {
  CAGAYAN_CENTRE,
  emptyDestination,
  pinUnset,
  readiness,
} from "./destination";
import { centreFor, roundCoords, zoomFor } from "./location";

const CALLAO = { lat: 17.7089, lng: 121.8226 };

describe("pinUnset", () => {
  it("is unset at the province's centre, where a new place starts", () => {
    expect(pinUnset(CAGAYAN_CENTRE)).toBe(true);
    expect(pinUnset(emptyDestination().coords)).toBe(true);
  });

  it("is unset at 0,0 or with no number", () => {
    expect(pinUnset({ lat: 0, lng: 0 })).toBe(true);
    expect(pinUnset({ lat: Number.NaN, lng: 121.8 })).toBe(true);
  });

  it("is set anywhere else, even a step from the centre", () => {
    expect(pinUnset(CALLAO)).toBe(false);
    expect(pinUnset({ lat: 17.613201, lng: 121.727 })).toBe(false);
  });
});

describe("the Location item on the checklist", () => {
  const location = (coords: { lat: number; lng: number }) =>
    readiness({ ...emptyDestination(), coords }).find(
      (i) => i.label === "Location",
    )!;

  it("is not met by a new place until its pin is placed", () => {
    expect(location(emptyDestination().coords)).toMatchObject({
      ok: false,
      tab: "location",
    });
    expect(location(CALLAO).ok).toBe(true);
  });
});

describe("the map", () => {
  it("writes a dragged position to six decimals", () => {
    expect(roundCoords({ lat: 17.708912345678, lng: 121.82264999999 })).toEqual({
      lat: 17.708912,
      lng: 121.82265,
    });
  });

  it("shows the whole province until the pin is placed, then a street", () => {
    expect(zoomFor(CAGAYAN_CENTRE)).toBeLessThan(zoomFor(CALLAO));
  });

  it("looks at the pin, or at the province's centre when there is no usable one", () => {
    expect(centreFor(CALLAO)).toEqual(CALLAO);
    expect(centreFor({ lat: 0, lng: 0 })).toEqual(CAGAYAN_CENTRE);
    expect(centreFor({ lat: Number.NaN, lng: 121 })).toEqual(CAGAYAN_CENTRE);
  });
});
