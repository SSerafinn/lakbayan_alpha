#!/bin/sh
# Entrypoint for the emulators container.
#
# The functions emulator runs functions/lib/*.js, which tsc produces from
# functions/src. Building here, inside the container, is what keeps
# `docker compose up emulators` a one-command environment: nobody has to
# remember a host-side build step, and a stale lib/ cannot silently serve last
# week's function.
#
# node_modules is a named volume (docker-compose.yml), not the bind mount, so
# a Linux install never collides with a Windows one on the host — the same
# separation the toolchain image keeps for .dart_tool.
set -eu

cd /app/functions
# install, not ci: `npm ci` deletes node_modules first, which would turn a
# no-op into a full reinstall on every start.
npm install --no-audit --no-fund --loglevel=error
npm run build --silent
cd /app

# exec, so SIGTERM from `docker compose down` reaches firebase-tools directly
# and --export-on-exit actually fires. Through a shell it would not.
#
# --only: firebase.json also declares Hosting, for the CMS. Its files are not
# mounted here, and nothing needs the container to serve them; preview a CMS
# build with the Hosting emulator on the host instead (cms/README.md).
exec firebase emulators:start \
  --only auth,firestore,functions,storage \
  --project demo-lakbayan \
  --import=/app/.emulator-data \
  --export-on-exit=/app/.emulator-data
