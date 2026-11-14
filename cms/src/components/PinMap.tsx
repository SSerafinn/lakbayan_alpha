import { useEffect, useRef } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { pinUnset } from "../types/destination";
import { centreFor, roundCoords, zoomFor, type Coords } from "../types/location";

/**
 * The place's pin on a map you can work: click to put it somewhere, drag it
 * to nudge it, after Google Business Profile and Airbnb's listing editors.
 *
 * It replaces an OpenStreetMap embed that could only show the pin. Moving it
 * meant reading coordinates off another site and typing two decimals by
 * hand, which is how a pin ends up in the river. The latitude and longitude
 * fields stay, and stay the source of truth: the map writes to them, and
 * follows them when they are typed or a search result is picked.
 *
 * Tiles are OpenStreetMap's own. Fine for a handful of staff (the tile
 * policy is about apps that ship to the public, which the phone app's map
 * does not use this server for); credited in the corner, as it requires.
 */
export function PinMap({
  coords,
  onMove,
}: {
  coords: Coords;
  onMove: (coords: Coords) => void;
}) {
  const box = useRef<HTMLDivElement>(null);
  const map = useRef<L.Map | null>(null);
  const pin = useRef<L.Marker | null>(null);
  // The latest callback, for listeners registered once.
  const move = useRef(onMove);
  useEffect(() => {
    move.current = onMove;
  });

  // The map, once. Leaflet owns this element from here on.
  useEffect(() => {
    if (!box.current) return;
    const m = L.map(box.current, {
      center: centreFor(coords),
      zoom: zoomFor(coords),
      // The map sits in a long form. A wheel over it should scroll the page
      // until someone has chosen to work the map by clicking into it.
      scrollWheelZoom: false,
    });
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">OpenStreetMap</a> contributors',
    }).addTo(m);
    const marker = L.marker(centreFor(coords), {
      icon: PIN,
      draggable: true,
      autoPan: true,
      title: "Drag to move the pin",
    }).addTo(m);

    marker.on("dragend", () => {
      const at = marker.getLatLng();
      move.current(roundCoords({ lat: at.lat, lng: at.lng }));
    });
    m.on("click", (e: L.LeafletMouseEvent) =>
      move.current(roundCoords({ lat: e.latlng.lat, lng: e.latlng.lng })),
    );
    m.on("focus", () => m.scrollWheelZoom.enable());
    m.on("blur", () => m.scrollWheelZoom.disable());

    map.current = m;
    pin.current = marker;
    return () => {
      m.remove();
      map.current = null;
      pin.current = null;
    };
    // Created once; the effect below follows `coords` after that.
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Follow the fields: a typed coordinate, a picked search result, Discard.
  useEffect(() => {
    const m = map.current;
    const marker = pin.current;
    if (!m || !marker) return;
    const unset = pinUnset(coords);
    marker.getElement()?.classList.toggle("is-unset", unset);
    const at = centreFor(coords);
    const now = marker.getLatLng();
    if (now.lat === at.lat && now.lng === at.lng) return;
    marker.setLatLng(at);
    // A pin placed from the whole-province view comes closer, so the next
    // nudge is a street's width and not a town's.
    if (!m.getBounds().contains(at) || (!unset && m.getZoom() < 12)) {
      m.setView(at, unset ? zoomFor(coords) : Math.max(m.getZoom(), zoomFor(coords)));
    }
  }, [coords]);

  return (
    <div
      ref={box}
      className="pin-map"
      role="application"
      aria-label="Map. Click to place the pin, or drag it. The latitude and longitude fields follow."
    />
  );
}

/** The app's emerald pin, drawn in CSS rather than Leaflet's image, which a bundler loses. */
const PIN = L.divIcon({
  className: "pin-icon",
  html: '<span class="pin-head"></span>',
  iconSize: [30, 40],
  iconAnchor: [15, 38],
});
