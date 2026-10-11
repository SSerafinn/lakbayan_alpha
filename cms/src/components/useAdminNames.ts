import { useEffect, useState } from "react";
import { listAdmins } from "../lib/users";

// One request per page load, shared by every screen that names an editor.
// listAdmins is a Cloud Function and may be cold, so it is asked only when a
// name is actually needed — and a failure leaves names out rather than
// breaking the screen that wanted them.
let cache: Promise<Map<string, string>> | null = null;

function load(): Promise<Map<string, string>> {
  cache ??= listAdmins()
    .then(
      (admins) =>
        new Map(admins.map((a) => [a.uid, a.displayName || a.email || ""])),
    )
    .catch(() => {
      cache = null; // try again next time rather than remembering the failure
      return new Map<string, string>();
    });
  return cache;
}

/** uid → a readable name for every admin, fetched only once `wanted` is true. */
export function useAdminNames(wanted: boolean): Map<string, string> {
  const [names, setNames] = useState<Map<string, string>>(new Map());
  useEffect(() => {
    if (!wanted) return;
    let live = true;
    void load().then((m) => live && setNames(m));
    return () => {
      live = false;
    };
  }, [wanted]);
  return names;
}
