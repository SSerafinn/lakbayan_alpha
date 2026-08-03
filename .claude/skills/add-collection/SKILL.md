---
name: add-collection
description: Add or modify a Firestore collection — define the schema, generate the Dart model, and update security rules and indexes together, keeping the FE-BE contract in sync. Use whenever the data model changes.
argument-hint: [collection-name]
allowed-tools: Read Grep Bash(dart run build_runner *)
---

# Add / change a Firestore collection

The schema is the **FE↔BE contract**. Change these together, in one PR.

## Steps
1. Update `docs/DATA_MODEL.md` with the collection shape (fields, types, enums,
   required/optional). Bump the `schemaVersion` note.
2. Add/update the Dart model in `lib/core/models/` using `freezed` +
   `json_serializable` (mirror field names exactly). Run `/gen`.
3. Update `firestore.rules`:
   - public content: `allow read` when `status == 'published'` (or admin); `allow write: if isAdmin()`.
     Remember client queries must then filter on `status`, or the query is denied.
   - subcollections must inherit the parent's visibility — don't leave them `if true`.
   - user-owned docs: owner-only. Admin is the `admin` custom claim, never a document field.
4. Add any needed composite indexes to `firestore.indexes.json`.
5. Note the storage path convention if the collection has assets
   (e.g. `/$ARGUMENTS/{id}/images/{n}.jpg`).
6. Test rules against the emulator before committing.

Current collections: destinations (+segments), offlineBundles, tours, guides, users.
See `docs/DATA_MODEL.md`.
