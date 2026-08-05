/**
 * Place search via Nominatim, OpenStreetMap's geocoder.
 *
 * Chosen because it needs no API key, no account and no billing — which for a
 * provincial tourism office matters more than result quality. Results in rural
 * Cagayan are patchy; the manual latitude/longitude fields stay as the fallback
 * and are still the source of truth.
 *
 * **Usage policy** (https://operations.osmfoundation.org/policies/nominatim/):
 * at most one request per second, and requests must identify the application.
 * A browser cannot set `User-Agent` — it is a forbidden header — so we rely on
 * the `Referer` the browser sends automatically, which the policy accepts. The
 * rate limit is honoured by debouncing at the call site; this module never
 * fires on its own.
 *
 * This is CMS-scale traffic: a few staff, a handful of searches per
 * destination. Nowhere near the limits. If it ever became bulk usage, the
 * policy requires a self-hosted instance instead.
 */

export type GeocodeResult = {
  label: string;
  lat: number;
  lng: number;
};

/** Bias toward the Philippines — "Aparri" should not return Italy. */
const COUNTRY = "ph";

/**
 * Searches for [query]. Returns an empty list rather than throwing: a failed
 * lookup should never block an editor who can still type coordinates by hand.
 *
 * Pass an [AbortSignal] so a superseded keystroke cancels its request.
 */
export async function searchPlaces(
  query: string,
  signal?: AbortSignal,
): Promise<GeocodeResult[]> {
  const q = query.trim();
  if (q.length < 3) return [];

  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", q);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("countrycodes", COUNTRY);
  url.searchParams.set("limit", "6");
  url.searchParams.set("addressdetails", "1");

  try {
    const res = await fetch(url, {
      signal,
      headers: { Accept: "application/json" },
    });
    if (!res.ok) return [];

    const raw: unknown = await res.json();
    if (!Array.isArray(raw)) return [];

    return raw
      .map((r): GeocodeResult | null => {
        const item = r as { display_name?: string; lat?: string; lon?: string };
        const lat = Number(item.lat);
        const lng = Number(item.lon);
        if (
          !item.display_name ||
          !Number.isFinite(lat) ||
          !Number.isFinite(lng)
        ) {
          return null;
        }
        return { label: item.display_name, lat, lng };
      })
      .filter((r): r is GeocodeResult => r !== null);
  } catch {
    // Aborted, offline, or rate-limited. All the same to the caller.
    return [];
  }
}

/** Six decimal places is ~0.1 m — well past what a map pin needs. */
export function formatCoord(n: number): string {
  return n.toFixed(6);
}
