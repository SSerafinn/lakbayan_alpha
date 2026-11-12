import { CAGAYAN_CENTRE, pinUnset } from "./destination";

/**
 * The editor's map pin: how close the map looks, where it centres, and what a
 * dragged or clicked position is written as.
 */

export type Coords = { lat: number; lng: number };

/**
 * Six decimal places: about 11 cm, finer than any phone's GPS and still a
 * number a person can read back. A drag yields fifteen, which would show in
 * the fields as noise and make a re-typed coordinate look like a change.
 */
export function roundCoords({ lat, lng }: Coords): Coords {
  const six = (n: number) => Math.round(n * 1e6) / 1e6;
  return { lat: six(lat), lng: six(lng) };
}

/** The whole province while the pin is unset; close enough to see a building once it is. */
export function zoomFor(coords: Coords): number {
  return pinUnset(coords) ? 8 : 16;
}

/** Where the map looks: the pin, or the province's centre while there is no usable one. */
export function centreFor(coords: Coords): Coords {
  return Number.isFinite(coords.lat) &&
    Number.isFinite(coords.lng) &&
    !(coords.lat === 0 && coords.lng === 0)
    ? coords
    : CAGAYAN_CENTRE;
}
