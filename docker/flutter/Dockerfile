# Toolchain image: analyze, test, codegen, build APK.
#
# Pinned to the same Flutter version the team runs locally. When you bump this,
# bump flutter-version in .github/workflows/ci.yml and the note in docs/DOCKER.md
# in the same commit — three places, one version.
FROM ghcr.io/cirruslabs/flutter:3.41.6

# This image ships a JDK that Gradle accepts. Do NOT set JAVA_HOME to a host
# path: the JDK 26 on the Windows hosts is what breaks Gradle 8.14 natively.
ENV PUB_CACHE=/root/.pub-cache \
    GRADLE_USER_HOME=/root/.gradle \
    # The base image sets these only in login shells (/etc/profile.d), so a
    # plain `docker compose run ... bash -c` does not see them. Promote to real
    # env vars so every invocation behaves the same.
    ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux

# Flutter's Gradle plugin pins an NDK version (android/app/build.gradle.kts ->
# `ndkVersion = flutter.ndkVersion`). The base image ships none, and Gradle
# cannot install one mid-build, so `flutter build apk` dies with
# "Failed to install the following SDK components: ndk;...".
#
# Keep in sync with the host SDK. Costs ~2 GB of image; if you ever need that
# space back, the alternative is dropping `ndkVersion` from build.gradle.kts —
# nothing in the current dependency set actually compiles native code, but that
# stops being true the moment a plugin does.
#
# CMake is bundled for a different reason: AGP pulls it in on demand, and since
# containers run with --rm that download repeats on every single APK build.
ARG ANDROID_NDK_VERSION=28.2.13676358
ARG ANDROID_CMAKE_VERSION=3.22.1
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
      --install "ndk;${ANDROID_NDK_VERSION}" "cmake;${ANDROID_CMAKE_VERSION}" > /dev/null \
 && yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null

WORKDIR /app

# Warm the pub cache at build time so the first `docker compose run` is not a
# cold download for each dev. Tolerate failure — the real resolve happens at
# run time against the mounted source.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get || true

CMD ["bash"]
