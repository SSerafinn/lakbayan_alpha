#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: installs the pinned Flutter
# SDK, resolves Dart/npm dependencies and runs codegen, so `dart analyze`,
# `flutter test` and the cms/functions npm scripts work from the first turn.
#
# Cloud-only: on a desktop the team's own SDK is used. Keep FLUTTER_VERSION in
# step with docker/flutter/Dockerfile and .github/workflows/ci.yml.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION=3.47.2
FLUTTER_ROOT="$HOME/sdks/flutter"
cd "$CLAUDE_PROJECT_DIR"

# Flutter SDK (cached in the container image after the first run).
if [ ! -x "$FLUTTER_ROOT/bin/flutter" ] \
   || ! grep -q "^${FLUTTER_VERSION}\b" "$FLUTTER_ROOT/version" 2>/dev/null; then
  rm -rf "$FLUTTER_ROOT"
  mkdir -p "$(dirname "$FLUTTER_ROOT")"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$(dirname "$FLUTTER_ROOT")"
  git config --global --add safe.directory "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$HOME/.pub-cache/bin:$PATH"
echo "export PATH=\"$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:\$HOME/.pub-cache/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

flutter config --no-analytics --no-cli-animations >/dev/null
dart --disable-analytics >/dev/null 2>&1 || true

# Dart deps + codegen (*.g.dart / *.freezed.dart are gitignored).
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Node packages: admin CMS, Cloud Functions, security-rules tests.
for dir in cms functions test_rules; do
  if [ -f "$dir/package.json" ]; then
    (cd "$dir" && npm install --no-audit --no-fund)
  fi
done
