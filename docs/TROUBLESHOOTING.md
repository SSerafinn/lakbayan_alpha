# Troubleshooting (host environment)

Problems with the machine you run `flutter run` on. For container issues see
`docs/DOCKER.md`.

## Gradle fails with `* What went wrong: 26.0.1`

```
FAILURE: Build failed with an exception.
* What went wrong:
26.0.1
BUILD FAILED in 965ms
```

**Cause.** Gradle 8.14 cannot run on JDK 26. The bare version number *is* the error
message — Gradle chokes before it can produce a readable one. A very short build
time (under ~2s) is the tell.

This bites even when `flutter config --jdk-dir` is already set to a good JDK,
because that setting only covers builds the **Flutter CLI** launches. Anything else
that starts a Gradle daemon — VS Code's Java extension, Android Studio, a direct
`gradlew` call — can start one under `JAVA_HOME`, and Gradle will happily **reuse
that daemon** for your next `flutter run`. So the same command fails or succeeds
depending on which daemon happens to be alive. 

**Fix.** Pin the JVM Gradle itself runs on, at the machine level. Create
`~/.gradle/gradle.properties` (i.e. `C:\Users\<you>\.gradle\gradle.properties`):

```
org.gradle.java.home=C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot
```

Use **forward slashes** — backslashes are escape characters in a properties file.
Point it at whatever JDK 17 or 21 you have; adjust the path to match your machine.

Then kill any daemon already running on the wrong JDK, or it will be reused:

```bash
taskkill /F /IM java.exe
```

Verify — a healthy build takes tens of seconds, not milliseconds:

```bash
flutter build apk --debug
```

**Why not just change `JAVA_HOME`?** You can, but it affects every Java tool on the
machine. `~/.gradle/gradle.properties` scopes the change to Gradle only, and is not
committed, so it does not force a path on teammates or CI.

**Why JDK 17 and not 26?** The project needs *two* incompatible JVMs: Gradle 8.14
rejects JDK 26, and `firebase-tools` requires JDK 21+. No single host JDK satisfies
both — which is exactly why the Firebase emulators run in Docker with their own
Java 21. Keep JDK 17 for Gradle on the host and let the container handle the rest.

## Emulator connections time out with no error

The Firebase emulators speak plain HTTP, and Android blocks cleartext by default
from API 28. `android/app/src/debug/AndroidManifest.xml` sets
`android:usesCleartextTraffic="true"` for the debug build type only. If you see
silent timeouts against the emulators, check that file first.

Also check the host: an Android emulator reaches your machine at `10.0.2.2`, not
`localhost`. A physical device needs your PC's LAN IP. See `docs/DOCKER.md`.

## `flutter run` picks the wrong device

```bash
flutter devices
```

```bash
flutter run -d emulator-5554
```

Note that `flutter run` must be run on the **host**, never in the toolchain
container — a container cannot reach the Android emulator or a USB device.
