# Toolchain image: analyze, test, codegen, build APK.
#
# Pinned to the same Flutter version the team runs locally. When you bump this,
# bump flutter-version in .github/workflows/ci.yml and the note in docs/DOCKER.md
# in the same commit — three places, one version.
#
# Built from a plain JDK base rather than a prebuilt Flutter image. Both public
# images this project could lean on stopped tracking stable —
# ghcr.io/cirruslabs/flutter ends at 3.44.0 (last commit 2026-05-20) and
# instrumentisto/flutter at 3.41.6 — so a Flutter bump was gated on a third
# party's release cadence. Installing the SDK ourselves costs ~40 lines and
# removes that dependency for good. Paths (/sdks/flutter, /opt/android-sdk-linux)
# are kept identical to the old base image so nothing in docs or scripts moved.
FROM eclipse-temurin:17-jdk-noble

# JDK 17 deliberately, matching CI (.github/workflows/ci.yml). Gradle 8.14 / AGP
# do not support JDK 26, which is what the Windows hosts have — see README.
ARG FLUTTER_VERSION=3.47.2

# Flutter's Gradle plugin pins compileSdk / NDK (android/app/build.gradle.kts ->
# `flutter.compileSdkVersion`, `flutter.ndkVersion`). Gradle cannot install
# these mid-build, so `flutter build apk` dies with "Failed to install the
# following SDK components" unless they are already present.
#
# Keep in sync with what the pinned Flutter version wants — the values live in
# packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt at that tag.
# CMake is bundled for a different reason: AGP pulls it in on demand, and since
# containers run with --rm that download would repeat on every APK build.
ARG ANDROID_PLATFORM=36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK_VERSION=28.2.13676358
ARG ANDROID_CMAKE_VERSION=3.22.1
# Google versions the cmdline-tools zip by build number; there is no stable
# "latest" URL. Current number is on https://developer.android.com/studio.
ARG ANDROID_CMDLINE_TOOLS=15859902

ENV FLUTTER_ROOT=/sdks/flutter \
    ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux \
    PUB_CACHE=/root/.pub-cache \
    GRADLE_USER_HOME=/root/.gradle
ENV PATH=${FLUTTER_ROOT}/bin:${FLUTTER_ROOT}/bin/cache/dart-sdk/bin:${PUB_CACHE}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}

# libglu1-mesa: the Flutter tool dlopens it on Linux for the test runner's
# software renderer; without it `flutter test` prints a warning per suite.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip libglu1-mesa \
 && rm -rf /var/lib/apt/lists/*

# Android SDK. cmdline-tools must live at <sdk>/cmdline-tools/latest/ or
# sdkmanager refuses to find its own root.
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
 && curl -fsSL -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" \
 && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
 && mv /tmp/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
 && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip \
 && yes | sdkmanager --licenses > /dev/null \
 && sdkmanager --install \
      "platform-tools" \
      "platforms;android-${ANDROID_PLATFORM}" \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "ndk;${ANDROID_NDK_VERSION}" \
      "cmake;${ANDROID_CMAKE_VERSION}" > /dev/null

# Flutter, at the exact tag. A shallow clone is enough — `flutter upgrade` is
# never run inside the image; bumping means rebuilding with a new ARG.
# safe.directory: the SDK checkout is root-owned and the mounted repo is not,
# and git refuses to read a repository owned by a different user otherwise.
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
      https://github.com/flutter/flutter.git ${FLUTTER_ROOT} \
 && git config --global --add safe.directory ${FLUTTER_ROOT} \
 && flutter config --no-analytics --no-cli-animations \
 && flutter precache --android \
 && flutter doctor

WORKDIR /app

# Warm the pub cache at build time so the first `docker compose run` is not a
# cold download for each dev. Tolerate failure — the real resolve happens at
# run time against the mounted source.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get || true

CMD ["bash"]
