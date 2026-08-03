# Firebase Emulator Suite: Auth, Firestore, Storage, Functions.
#
# This image exists mainly to pin the JDK. firebase-tools >= 14 refuses to run
# the Firestore/Storage emulators on anything below Java 21, while Gradle 8.14
# fails on Java 26 — so no single JDK on the Windows hosts satisfies both. In a
# container the emulator gets its own Java 21 and the conflict disappears.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg openjdk-21-jre-headless \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g firebase-tools@15.19.0 \
 && apt-get purge -y gnupg \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Bake the emulator jars into the image. Without this every dev downloads them
# on first `up`, and a flaky download leaves a half-started suite.
RUN firebase setup:emulators:firestore \
 && firebase setup:emulators:storage \
 && firebase setup:emulators:ui

WORKDIR /app

# UI 4000 · hub 4400 · logging 4500 · functions 5001
# firestore 8080 (+9150 websocket) · auth 9099 · storage 9199
EXPOSE 4000 4400 4500 5001 8080 9099 9150 9199
