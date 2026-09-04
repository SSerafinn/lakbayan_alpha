/**
 * Where every function in this codebase runs.
 *
 * Singapore is the closest region to Cagayan that offers 2nd-gen functions.
 * The CMS must call the same region — `FUNCTIONS_REGION` in
 * `cms/src/lib/firebase.ts` mirrors this value, and a mismatch does not error,
 * it 404s. Change both or neither. See docs/DECISIONS.md D-12.
 */
export const REGION = "asia-southeast1";
