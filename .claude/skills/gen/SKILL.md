---
name: gen
description: Run build_runner code generation for freezed, json_serializable, riverpod, and hive. Use after changing any model, provider, or Hive type adapter.
allowed-tools: Bash(dart run build_runner *)
---

# Codegen

Run:

```!
dart run build_runner build --delete-conflicting-outputs
```

If generation fails, read the first error, fix the annotated source, and re-run.
Never hand-edit `*.g.dart` or `*.freezed.dart` files.
