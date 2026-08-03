# Toolchain image: analyze, test, codegen, build APK.
#
# Pinned to the same Flutter version the team runs locally. When you bump this,
# bump flutter-version in .github/workflows/ci.yml and the note in docs/DOCKER.md
# in the same commit — three places, one version.
FROM ghcr.io/cirruslabs/flutter:3.41.6

# This image ships a JDK that Gradle accepts. Do NOT set JAVA_HOME to a host
# path: the JDK 26 on the Windows hosts is what breaks Gradle 8.14 natively.
ENV PUB_CACHE=/root/.pub-cache \
    GRADLE_USER_HOME=/root/.gradle

WORKDIR /app

# Warm the pub cache at build time so the first `docker compose run` is not a
# cold download for each dev. Tolerate failure — the real resolve happens at
# run time against the mounted source.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get || true

CMD ["bash"]
